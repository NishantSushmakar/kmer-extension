/*
 * kmer_spgist.c
 *
 * References:
 * Postgres Trie-based SP-GiST Index for Text: https://doxygen.postgresql.org/spgtextproc_8c_source.html
 * SP-GiST Documentation: https://www.postgresql.org/docs/current/spgist.html
 */

#include "kmer_spgist.h"
#include "kmer.h"
#include "fmgr.h"
#include "access/spgist.h"
#include "catalog/pg_type.h"
#include "utils/builtins.h"
#include "utils/datum.h"
#include "utils/memutils.h"
#include "utils/lsyscache.h"
#include "catalog/pg_collation.h"
#include "funcapi.h"

/*****************************************************************************/

// TODO: Make a common function for contains and containing, call from headers

// Containing function
PG_FUNCTION_INFO_V1(kmer_containing);
Datum kmer_containing(PG_FUNCTION_ARGS)
{
	KMER *kmer = (KMER *)PG_GETARG_VARLENA_P(0);
	QKMER *qkmer = (QKMER *)PG_GETARG_VARLENA_P(1);

	int len1 = VARSIZE_ANY_EXHDR(qkmer);
	int len2 = VARSIZE_ANY_EXHDR(kmer);

	// if length of Qkmer and kmer are not equal then is not a match
	if (len1 != len2)
		PG_RETURN_BOOL(false);

	char *qkmer_str = VARDATA_ANY(qkmer);
	char *kmer_str = VARDATA_ANY(kmer);

	// compare every qkmer char to see if is a corresponding match to a kmer
	for (int i = 0; i < len1; i++)
	{
		if (!match(qkmer_str[i], kmer_str[i]))
		{
			PG_RETURN_BOOL(false);
		}
	}

	PG_RETURN_BOOL(true);
}

// Contains function
PG_FUNCTION_INFO_V1(kmer_contains);
Datum kmer_contains(PG_FUNCTION_ARGS)
{
	QKMER *qkmer = (QKMER *)PG_GETARG_VARLENA_P(0);
	KMER *kmer = (KMER *)PG_GETARG_VARLENA_P(1);

	int len1 = VARSIZE_ANY_EXHDR(qkmer);
	int len2 = VARSIZE_ANY_EXHDR(kmer);

	// if length of Qkmer and kmer are not equal then is not a match
	if (len1 != len2)
		PG_RETURN_BOOL(false);

	char *qkmer_str = VARDATA_ANY(qkmer);
	char *kmer_str = VARDATA_ANY(kmer);

	// compare every qkmer char to see if is a corresponding match to a kmer
	for (int i = 0; i < len1; i++)
	{
		if (!match(qkmer_str[i], kmer_str[i]))
		{
			PG_RETURN_BOOL(false);
		}
	}

	PG_RETURN_BOOL(true);
}

// Starts with function
PG_FUNCTION_INFO_V1(kmer_starts_with);
Datum kmer_starts_with(PG_FUNCTION_ARGS)
{
	KMER *prefix = (KMER *)PG_GETARG_VARLENA_P(0);
	KMER *kmer = (KMER *)PG_GETARG_VARLENA_P(1);

	int len1 = VARSIZE_ANY_EXHDR(prefix);
	int len2 = VARSIZE_ANY_EXHDR(kmer);

	// if length of prefix greater than kmer then its always false
	if (len1 > len2)
		PG_RETURN_BOOL(false);

	// compare the kmer with the given prefix
	bool result = memcmp(VARDATA_ANY(prefix), VARDATA_ANY(kmer), len1) == 0;

	PG_RETURN_BOOL(result);
}

/*****************************************************************************/

/*SP-Gist index functions implementation*/
// Static information about the index implementation
PG_FUNCTION_INFO_V1(kmer_config);
Datum kmer_config(PG_FUNCTION_ARGS)
{
	spgConfigIn *in = (spgConfigIn *)PG_GETARG_POINTER(0);
	spgConfigOut *cfg = (spgConfigOut *)PG_GETARG_POINTER(1);

	cfg->prefixType = in->attType;
	cfg->labelType = INT2OID;
	cfg->canReturnData = true;
	cfg->longValuesOK = false;

	PG_RETURN_VOID();
}

// Chooses a method for inserting a new value into an inner tuple 
PG_FUNCTION_INFO_V1(kmer_choose);
Datum kmer_choose(PG_FUNCTION_ARGS)
{
	spgChooseIn *in = (spgChooseIn *)PG_GETARG_POINTER(0);
	spgChooseOut *out = (spgChooseOut *)PG_GETARG_POINTER(1);

	KMER *inKmer = (KMER *)DatumGetPointer(in->datum);
	char *inStr = VARDATA_ANY(inKmer);
	int inSize = VARSIZE_ANY_EXHDR(inKmer);
	char *prefixStr = NULL;
	int prefixSize = 0;
	int commonLen = 0;
	int16 nodeChar = 0;
	int i = 0;

	/* Check for prefix match, set nodeChar to first byte after prefix */
	if (in->hasPrefix)
	{
		KMER *prefixKmer = (KMER *)DatumGetPointer(in->prefixDatum);
		prefixStr = VARDATA_ANY(prefixKmer);
		prefixSize = VARSIZE_ANY_EXHDR(prefixKmer);

		commonLen = commonPrefix(inStr + in->level,
								 prefixStr,
								 inSize - in->level,
								 prefixSize);

		if (commonLen == prefixSize)
		{
			if (inSize - in->level > commonLen)
				nodeChar = *(unsigned char *)(inStr + in->level + commonLen);
			else
				nodeChar = -1;
		}
		else
		{
			/* Must split tuple because incoming value doesn't match prefix */
			out->resultType = spgSplitTuple;

			if (commonLen == 0)
			{
				out->result.splitTuple.prefixHasPrefix = false;
			}
			else
			{
				out->result.splitTuple.prefixHasPrefix = true;
				out->result.splitTuple.prefixPrefixDatum =
					formKmerDatum(prefixStr, commonLen);
			}
			out->result.splitTuple.prefixNNodes = 1;
			out->result.splitTuple.prefixNodeLabels =
				(Datum *)palloc(sizeof(Datum));
			out->result.splitTuple.prefixNodeLabels[0] =
				Int16GetDatum(*(unsigned char *)(prefixStr + commonLen));

			out->result.splitTuple.childNodeN = 0;

			if (prefixSize - commonLen == 1)
			{
				out->result.splitTuple.postfixHasPrefix = false;
			}
			else
			{
				out->result.splitTuple.postfixHasPrefix = true;
				out->result.splitTuple.postfixPrefixDatum =
					formKmerDatum(prefixStr + commonLen + 1,
								  prefixSize - commonLen - 1);
			}

			PG_RETURN_VOID();
		}
	}
	else if (inSize > in->level)
	{
		nodeChar = *(unsigned char *)(inStr + in->level);
	}
	else
	{
		nodeChar = -1;
	}

	/* Look up nodeChar in the node label array */
	if (searchChar(in->nodeLabels, in->nNodes, nodeChar, &i))
	{
		/*
		 * Descend to existing node. If in->allTheSame, the core code will
		 * ignore our nodeN specification here, but that's OK. We still have
		 * to provide the correct levelAdd and restDatum values, and those are
		 * the same regardless of which node gets chosen by core.
		 */
		int levelAdd;

		out->resultType = spgMatchNode;
		out->result.matchNode.nodeN = i;
		levelAdd = commonLen;
		if (nodeChar >= 0)
			levelAdd++;
		out->result.matchNode.levelAdd = levelAdd;
		if (inSize - in->level - levelAdd > 0)
			out->result.matchNode.restDatum =
				formKmerDatum(inStr + in->level + levelAdd,
							  inSize - in->level - levelAdd);
		else
			out->result.matchNode.restDatum =
				formKmerDatum(NULL, 0);
	}
	else if (in->allTheSame)
	{
		/*
		 * Can't use AddNode action, so split the tuple. The upper tuple has
		 * the same prefix as before and uses a dummy node label -2 for the
		 * lower tuple. The lower tuple has no prefix and the same node
		 * labels as the original tuple.
		 */
		out->resultType = spgSplitTuple;
		out->result.splitTuple.prefixHasPrefix = in->hasPrefix;
		out->result.splitTuple.prefixPrefixDatum = in->prefixDatum;
		out->result.splitTuple.prefixNNodes = 1;
		out->result.splitTuple.prefixNodeLabels = (Datum *)palloc(sizeof(Datum));
		out->result.splitTuple.prefixNodeLabels[0] = Int16GetDatum(-2);
		out->result.splitTuple.childNodeN = 0;
		out->result.splitTuple.postfixHasPrefix = false;
	}
	else
	{
		/* Add a node for the not-previously-seen nodeChar value */
		out->resultType = spgAddNode;
		out->result.addNode.nodeLabel = Int16GetDatum(nodeChar);
		out->result.addNode.nodeN = i;
	}

	PG_RETURN_VOID();
}

// Decides how to create a new inner tuple over a set of leaf tuples
PG_FUNCTION_INFO_V1(kmer_picksplit);
Datum kmer_picksplit(PG_FUNCTION_ARGS)
{
	spgPickSplitIn *in = (spgPickSplitIn *)PG_GETARG_POINTER(0);
	spgPickSplitOut *out = (spgPickSplitOut *)PG_GETARG_POINTER(1);

	KMER *kmer0 = (KMER *)DatumGetPointer(in->datums[0]);
	int i, commonLen;
	spgNodePtr *nodes;

	/* Identify longest common prefix length among k-mers */
	commonLen = VARSIZE_ANY_EXHDR(kmer0);

	for (i = 1; i < in->nTuples && commonLen > 0; i++)
	{
		KMER *kmeri = (KMER *)DatumGetPointer(in->datums[i]);
		int tmp = commonPrefix(VARDATA_ANY(kmer0), VARDATA_ANY(kmeri),
							   VARSIZE_ANY_EXHDR(kmer0), VARSIZE_ANY_EXHDR(kmeri));
		if (tmp < commonLen)
			commonLen = tmp;
	}

	/* Ensure prefix length does not exceed max allowed for SP-GiST */
	commonLen = Min(commonLen, SPGIST_MAX_PREFIX_LENGTH);

	/* Set node prefix if there's a common prefix */
	if (commonLen == 0)
	{
		out->hasPrefix = false;
	}
	else
	{
		out->hasPrefix = true;
		out->prefixDatum = formKmerDatum(VARDATA_ANY(kmer0), commonLen);
	}

	/* Initialize node pointers based on first non-common byte */
	nodes = (spgNodePtr *)palloc(sizeof(spgNodePtr) * in->nTuples);

	for (i = 0; i < in->nTuples; i++)
	{
		KMER *kmeri = (KMER *)DatumGetPointer(in->datums[i]);

		if (commonLen < VARSIZE_ANY_EXHDR(kmeri))
			nodes[i].c = *(unsigned char *)(VARDATA_ANY(kmeri) + commonLen);
		else
			nodes[i].c = -1; /* all characters are common */
		nodes[i].i = i;
		nodes[i].d = in->datums[i];
	}

	/* Sort nodes based on their labels for grouping */
	qsort(nodes, in->nTuples, sizeof(*nodes), cmpNodePtr);

	/* Prepare the output data */
	out->nNodes = 0;
	out->nodeLabels = (Datum *)palloc(sizeof(Datum) * in->nTuples);
	out->mapTuplesToNodes = (int *)palloc(sizeof(int) * in->nTuples);
	out->leafTupleDatums = (Datum *)palloc(sizeof(Datum) * in->nTuples);

	for (i = 0; i < in->nTuples; i++)
	{
		KMER *kmeri = (KMER *)DatumGetPointer(nodes[i].d);
		Datum leafD;

		if (i == 0 || nodes[i].c != nodes[i - 1].c)
		{
			out->nodeLabels[out->nNodes] = Int16GetDatum(nodes[i].c);
			out->nNodes++;
		}

		if (commonLen < VARSIZE_ANY_EXHDR(kmeri))
		{
			leafD = formKmerDatum(VARDATA_ANY(kmeri) + commonLen + 1,
								  VARSIZE_ANY_EXHDR(kmeri) - commonLen - 1);
		}
		else
		{
			leafD = formKmerDatum(NULL, 0);
		}

		out->leafTupleDatums[nodes[i].i] = leafD;
		out->mapTuplesToNodes[nodes[i].i] = out->nNodes - 1;
	}

	PG_RETURN_VOID();
}

// Returns set of nodes (branches) to follow during tree search
PG_FUNCTION_INFO_V1(kmer_inner_consistent);
Datum kmer_inner_consistent(PG_FUNCTION_ARGS)
{
	spgInnerConsistentIn *in = (spgInnerConsistentIn *)PG_GETARG_POINTER(0);
	spgInnerConsistentOut *out = (spgInnerConsistentOut *)PG_GETARG_POINTER(1);

	KMER *reconstructedValue;
	KMER *reconstrKmer;
	int maxReconstrLen;
	KMER *prefixKmer = NULL;
	int prefixSize = 0;
	int i;

	/* Initialize the reconstructed value */
	reconstructedValue = (KMER *)DatumGetPointer(in->reconstructedValue);
	Assert(reconstructedValue == NULL ? in->level == 0 : VARSIZE_ANY_EXHDR(reconstructedValue) == in->level);

	maxReconstrLen = in->level + 1; /* Start with current level length */
	if (in->hasPrefix)
	{
		prefixKmer = (KMER *)DatumGetPointer(in->prefixDatum);
		prefixSize = VARSIZE_ANY_EXHDR(prefixKmer);
		maxReconstrLen += prefixSize;
	}

	/* Allocate and construct the new reconstructed k-mer */
	reconstrKmer = (KMER *)palloc(VARHDRSZ_SHORT + maxReconstrLen);
	SET_VARSIZE_SHORT(reconstrKmer, VARHDRSZ_SHORT + maxReconstrLen);

	if (in->level)
		memcpy(VARDATA_ANY(reconstrKmer), VARDATA_ANY(reconstructedValue), in->level);
	if (prefixSize)
		memcpy(((char *)VARDATA_ANY(reconstrKmer)) + in->level, VARDATA_ANY(prefixKmer), prefixSize);

	/* Initialize output arrays */
	out->nodeNumbers = (int *)palloc(sizeof(int) * in->nNodes);
	out->levelAdds = (int *)palloc(sizeof(int) * in->nNodes);
	out->reconstructedValues = (Datum *)palloc(sizeof(Datum) * in->nNodes);
	out->nNodes = 0;

	for (i = 0; i < in->nNodes; i++)
	{
		int16 nodeChar = DatumGetInt16(in->nodeLabels[i]);
		int thisLen;
		bool res = true;
		int j;

		/* Set or skip last character based on nodeChar */
		if (nodeChar <= 0)
			thisLen = maxReconstrLen - 1;
		else
		{
			((unsigned char *)VARDATA_ANY(reconstrKmer))[maxReconstrLen - 1] = nodeChar;
			thisLen = maxReconstrLen;
		}

		for (j = 0; j < in->nkeys; j++)
		{
			StrategyNumber strategy = in->scankeys[j].sk_strategy;
			Datum arg = in->scankeys[j].sk_argument;
			int r;
			int inSize;
			KMER *inKmer;
			QKMER *inQkmer;

			/* Apply the strategy for comparisons */
			switch (strategy)
			{
			case BTEqualStrategyNumber:
				inKmer = (KMER *)DatumGetPointer(arg);
				inSize = VARSIZE_ANY_EXHDR(inKmer);
				r = memcmp(VARDATA_ANY(reconstrKmer), VARDATA_ANY(inKmer), Min(inSize, thisLen));
				if (r != 0 || inSize < thisLen)
					res = false;
				break;
			case RTContainsStrategyNumber:
				inQkmer = (QKMER *)DatumGetPointer(arg);
				inSize = VARSIZE_ANY_EXHDR(inQkmer);
				if (inSize < thisLen)
				{
					res = false;
				}
				else
				{
					char *qkmer_str = VARDATA_ANY(inQkmer);
					char *kmer_str = VARDATA_ANY(reconstrKmer);
					for (int i = 0; i < Min(inSize, thisLen); i++)
					{
						if (!match(qkmer_str[i], kmer_str[i]))
						{
							res = false;
							break;
						}
					}
				}

				break;
			case RTPrefixStrategyNumber:
				inKmer = (KMER *)DatumGetPointer(arg);
				inSize = VARSIZE_ANY_EXHDR(inKmer);
				r = memcmp(VARDATA_ANY(reconstrKmer), VARDATA_ANY(inKmer), Min(inSize, thisLen));
				if (r != 0)
					res = false;
				break;
			default:
				elog(ERROR, "unrecognized strategy number: %d", in->scankeys[j].sk_strategy);
				break;
			}

			if (!res)
				break; /* Exit early if any condition fails */
		}

		/* Add valid nodes to output */
		if (res)
		{
			out->nodeNumbers[out->nNodes] = i;
			out->levelAdds[out->nNodes] = thisLen - in->level;

			/* Store reconstructed k-mer as a Datum */
			SET_VARSIZE_SHORT(reconstrKmer, VARHDRSZ_SHORT + thisLen);
			out->reconstructedValues[out->nNodes] = datumCopy(PointerGetDatum(reconstrKmer), false, -1);
			out->nNodes++;
		}
	}

	PG_RETURN_VOID();
}

// Returns true if a leaf tuple satisfies a query
PG_FUNCTION_INFO_V1(kmer_leaf_consistent);
Datum kmer_leaf_consistent(PG_FUNCTION_ARGS)
{
	spgLeafConsistentIn *in = (spgLeafConsistentIn *)PG_GETARG_POINTER(0);
	spgLeafConsistentOut *out = (spgLeafConsistentOut *)PG_GETARG_POINTER(1);

	int level = in->level;
	KMER *leafValue, *reconstrValue = NULL;
	char *fullValue;
	int fullLen;
	bool res;
	int j;

	/* All tests are exact, so recheck is not required */
	out->recheck = false;

	leafValue = (KMER *)DatumGetPointer(in->leafDatum);

	/* Get the reconstructed value from the previous level, if any */
	if (DatumGetPointer(in->reconstructedValue))
		reconstrValue = (KMER *)DatumGetPointer(in->reconstructedValue);

	Assert(reconstrValue == NULL ? level == 0 : VARSIZE_ANY_EXHDR(reconstrValue) == level);

	/* Calculate the full length for reconstructed k-mer */
	fullLen = level + VARSIZE_ANY_EXHDR(leafValue);
	if (VARSIZE_ANY_EXHDR(leafValue) == 0 && level > 0)
	{
		fullValue = VARDATA_ANY(reconstrValue);
		out->leafValue = PointerGetDatum(reconstrValue);
	}
	else
	{
		/* Allocate and build the full k-mer sequence */
		KMER *fullKmer = palloc(VARHDRSZ_SHORT + fullLen);
		SET_VARSIZE_SHORT(fullKmer, VARHDRSZ_SHORT + fullLen);
		fullValue = VARDATA_ANY(fullKmer);

		/* Copy previous reconstruction and leafValue sequences */
		if (level)
			memcpy(fullValue, VARDATA_ANY(reconstrValue), level);
		if (VARSIZE_ANY_EXHDR(leafValue) > 0)
			memcpy(fullValue + level, VARDATA_ANY(leafValue), VARSIZE_ANY_EXHDR(leafValue));

		out->leafValue = PointerGetDatum(fullKmer);
	}

	/* Perform the required comparisons based on strategy */
	res = true;
	for (j = 0; j < in->nkeys; j++)
	{
		StrategyNumber strategy = in->scankeys[j].sk_strategy;
		Datum arg = in->scankeys[j].sk_argument;
		int r;
		int queryLen;
		KMER *query;
		QKMER *patternQuery;

		/* Apply the comparison strategy */
		switch (strategy)
		{
		case BTEqualStrategyNumber:
			query = (KMER *)DatumGetPointer(arg);
			queryLen = VARSIZE_ANY_EXHDR(query);
			r = memcmp(fullValue, VARDATA_ANY(query), Min(queryLen, fullLen));
			res = (queryLen == fullLen) && (r == 0);
			break;
		case RTPrefixStrategyNumber:
			query = (KMER *)DatumGetPointer(arg);
			queryLen = VARSIZE_ANY_EXHDR(query);
			res = (level >= queryLen) ||
				  DatumGetBool(DirectFunctionCall2(kmer_starts_with,
												   PointerGetDatum(query),
												   out->leafValue));
			break;
		case RTContainsStrategyNumber:
			patternQuery = (QKMER *)DatumGetPointer(arg);
			queryLen = VARSIZE_ANY_EXHDR(patternQuery);
			res = (queryLen == fullLen) &&
			    DatumGetBool(DirectFunctionCall2(kmer_contains,
				                                PointerGetDatum(patternQuery),
				                                out->leafValue));
			break;
		default:
			elog(ERROR, "unrecognized strategy number: %d", in->scankeys[j].sk_strategy);
			res = false;
			break;
		}

		/* Exit early if any condition fails */
		if (!res)
			break;
	}

	PG_RETURN_BOOL(res);
}
