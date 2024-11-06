#include "postgres.h"
#include "fmgr.h"
#include "funcapi.h"
#include <ctype.h>
#include "access/hash.h"
#include "access/spgist.h"
#include "catalog/pg_type.h"
#include "common/int.h"
#include "executor/spi.h"
#include "lib/stringinfo.h"
#include "mb/pg_wchar.h"
#include "utils/datum.h"
#include "utils/fmgrprotos.h"
#include "utils/pg_locale.h"
#include "utils/varlena.h"
#include "utils/elog.h"
#include "utils/builtins.h"
#include "utils/typcache.h"
#include "utils/syscache.h"
#include "catalog/namespace.h"
#include "utils/fmgroids.h"

PG_MODULE_MAGIC;

/* Maximum length for kmer and qkmer types */
#define MAX_KMER_LENGTH 32
#define SPGIST_MAX_PREFIX_LENGTH Max((int)(BLCKSZ - 258 * 16 - 100), 32)
#define SPG_STRATEGY_ADDITION (10)
#define SPG_IS_COLLATION_AWARE_STRATEGY(s) ((s) > SPG_STRATEGY_ADDITION && (s) != RTPrefixStrategyNumber)

/* DNA Sequence Type */
typedef struct
{
	int32 length;
	char sequence[FLEXIBLE_ARRAY_MEMBER];
} DNA;

/* K-mer Type */
typedef struct
{
	int32 length;
	char sequence[FLEXIBLE_ARRAY_MEMBER];
} KMER;

/* Query K-mer Type */
typedef struct
{
	int32 length;
	char sequence[FLEXIBLE_ARRAY_MEMBER];
} QKMER;

/* Struct for sorting values in picksplit */
typedef struct spgNodePtr
{
	Datum d;
	int i;
	int16 c;
} spgNodePtr;

/* Helper Function to Validate the DNA Sequence for A,C,G and T characters */

static inline void validate_sequence(char *input)
{

	char *ptr = input;
	char c;

	for (ptr = input; *ptr; ptr++)
	{
		c = tolower(*ptr);
		*ptr = c;

		if ((c != 'a') && (c != 'c') && (c != 'g') && (c != 't'))
		{
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
					 errmsg("Invalid DNA Sequence"),
					 errdetail("Valid characters are A, C, G, T (case-insensitive).")));
		}
	}

	return;
}

/* Helper Function to  match the possible DNA sequences for a given QKMer */
static inline bool match(char pattern, char nucleotide)
{

	if (pattern == nucleotide || pattern == 'n')
		return true;

	switch (pattern)
	{
	case 'r':
		return nucleotide == 'a' || nucleotide == 'g'; // puRine
	case 'y':
		return nucleotide == 'c' || nucleotide == 't'; // pYrimidine
	case 'k':
		return nucleotide == 'g' || nucleotide == 't'; // Keto
	case 'm':
		return nucleotide == 'a' || nucleotide == 'c'; // aMino
	case 's':
		return nucleotide == 'g' || nucleotide == 'c'; // Strong
	case 'w':
		return nucleotide == 'a' || nucleotide == 't'; // Weak
	case 'b':
		return nucleotide == 'c' || nucleotide == 'g' || nucleotide == 't'; // not A
	case 'd':
		return nucleotide == 'a' || nucleotide == 'g' || nucleotide == 't'; // not C
	case 'h':
		return nucleotide == 'a' || nucleotide == 'c' || nucleotide == 't'; // not G
	case 'v':
		return nucleotide == 'a' || nucleotide == 'c' || nucleotide == 'g'; // not T
	default:
		return false;
	}
}

/* Helper function to compare two kmer sequences */
static int
kmer_compare(const KMER *a, const KMER *b)
{
    int min_len = Min(a->length, b->length);
    int cmp = memcmp(a->sequence, b->sequence, min_len);

    if (cmp != 0) {
        return cmp;
    } else {
        /* If sequences are equal up to min_len, shorter kmer is considered smaller */
        if (a->length < b->length) return -1;
        else if (a->length > b->length) return 1;
        else return 0;
    }
}


/*SP-Gist index helper functions*/
static Datum
formKmerDatum(const char *data, int datalen)
{
	// Validate the input length
	if (datalen > MAX_KMER_LENGTH)
	{
		ereport(ERROR,
				(errcode(ERRCODE_STRING_DATA_RIGHT_TRUNCATION),
				 errmsg("KMer Sequence larger than maximum allowed length")));
	}

	// Allocate memory for KMER, including the length of the sequence
	KMER *kmer_p = (KMER *)palloc(VARHDRSZ + datalen);

	// Set the VARSIZE and assign sequence length
	SET_VARSIZE(kmer_p, VARHDRSZ + datalen);

	// Copy the sequence data
	memcpy(kmer_p->sequence, data, datalen);

	// Return the KMER structure as a Datum
	return PointerGetDatum(kmer_p);
}

static int
commonPrefix(const char *a, const char *b, int lena, int lenb)
{
	int i = 0;

	while (i < lena && i < lenb && *a == *b)
	{
		a++;
		b++;
		i++;
	}

	return i;
}

/* qsort comparator to sort spgNodePtr structs by "c" */
static int
cmpNodePtr(const void *a, const void *b)
{
    const spgNodePtr *aa = (const spgNodePtr *)a;
    const spgNodePtr *bb = (const spgNodePtr *)b;

    if (aa->c < bb->c)
        return -1;
    else if (aa->c > bb->c)
        return 1;
    else
        return 0;
}

static bool
searchChar(Datum *nodeLabels, int nNodes, int16 c, int *i)
{
	int StopLow = 0,
		StopHigh = nNodes;

	while (StopLow < StopHigh)
	{
		int StopMiddle = (StopLow + StopHigh) >> 1;
		int16 middle = DatumGetInt16(nodeLabels[StopMiddle]);

		if (c < middle)
			StopHigh = StopMiddle;
		else if (c > middle)
			StopLow = StopMiddle + 1;
		else
		{
			*i = StopMiddle;
			return true;
		}
	}

	*i = StopHigh;
	return false;
}


/* DNA Input and Output Functions */
PG_FUNCTION_INFO_V1(dna_in);
Datum dna_in(PG_FUNCTION_ARGS)
{
	char *input = PG_GETARG_CSTRING(0);
	int len;

	len = strlen(input);

	validate_sequence(input);

	DNA *result = (DNA *)palloc(VARHDRSZ + len);
	SET_VARSIZE(result, VARHDRSZ + len);
	memcpy(result->sequence, input, len);

	PG_RETURN_POINTER(result);
}

PG_FUNCTION_INFO_V1(dna_out);
Datum dna_out(PG_FUNCTION_ARGS)
{
	DNA *dna = (DNA *)PG_GETARG_POINTER(0);
	char *result = psprintf("%.*s", VARSIZE_ANY_EXHDR(dna), dna->sequence);

	PG_RETURN_CSTRING(result);
}

/* KMER Input and Output Functions */
PG_FUNCTION_INFO_V1(kmer_in);
Datum kmer_in(PG_FUNCTION_ARGS)
{
	char *input = PG_GETARG_CSTRING(0);
	int len;

	len = strlen(input);

	if (len > MAX_KMER_LENGTH)
	{
		ereport(ERROR,
				(errcode(ERRCODE_STRING_DATA_RIGHT_TRUNCATION),
				 errmsg("KMer Sequence larger than length 32")));
	}

	validate_sequence(input);

	KMER *result = (KMER *)palloc(VARHDRSZ + len);
	SET_VARSIZE(result, VARHDRSZ + len);
	memcpy(result->sequence, input, len);

	PG_RETURN_POINTER(result);
}

PG_FUNCTION_INFO_V1(kmer_out);
Datum kmer_out(PG_FUNCTION_ARGS)
{
	KMER *kmer = (KMER *)PG_GETARG_POINTER(0);
	char *result = psprintf("%.*s", VARSIZE_ANY_EXHDR(kmer), kmer->sequence);

	PG_RETURN_CSTRING(result);
}

/* QKMER Input and Output Functions */
PG_FUNCTION_INFO_V1(qkmer_in);
Datum qkmer_in(PG_FUNCTION_ARGS)
{
	char *input = PG_GETARG_CSTRING(0);
	int len;
	char *ptr = input;
	char c;

	len = strlen(input);

	if (len > MAX_KMER_LENGTH)
	{
		ereport(ERROR,
				(errcode(ERRCODE_STRING_DATA_RIGHT_TRUNCATION),
				 errmsg("QKMer Sequence larger than length 32")));
	}

	for (ptr = input; *ptr; ptr++)
	{
		c = tolower(*ptr);
		*ptr = c;

		if (c != 'a' && // Adenine
			c != 'c' && // Cytosine
			c != 'g' && // Guanine
			c != 't' && // Thymine
			c != 'u' && // Uracil
			c != 'r' && // A or G
			c != 'y' && // C or T
			c != 'k' && // G or T
			c != 'm' && // A or C
			c != 's' && // G or C
			c != 'w' && // A or T
			c != 'b' && // C, G, or T (not A)
			c != 'd' && // A, G, or T (not C)
			c != 'h' && // A, C, or T (not G)
			c != 'v' && // A, C, or G (not T)
			c != 'n'	// A, T, C, or G (any nucleotide)
		)
		{
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
					 errmsg("Invalid QKMer Sequence")));
		}
	}

	QKMER *result = (QKMER *)palloc(VARHDRSZ + len);
	SET_VARSIZE(result, VARHDRSZ + len);
	memcpy(result->sequence, input, len);

	PG_RETURN_POINTER(result);
}

PG_FUNCTION_INFO_V1(qkmer_out);
Datum qkmer_out(PG_FUNCTION_ARGS)
{
	QKMER *qkmer = (QKMER *)PG_GETARG_POINTER(0);
	char *result = psprintf("%.*s", VARSIZE_ANY_EXHDR(qkmer), qkmer->sequence);

	PG_RETURN_CSTRING(result);
}

/* Length Functions */
PG_FUNCTION_INFO_V1(dna_length);
Datum dna_length(PG_FUNCTION_ARGS)
{
	DNA *dna = (DNA *)PG_GETARG_POINTER(0);
	PG_RETURN_INT32(VARSIZE_ANY_EXHDR(dna));
}

PG_FUNCTION_INFO_V1(kmer_length);
Datum kmer_length(PG_FUNCTION_ARGS)
{
	KMER *kmer = (KMER *)PG_GETARG_POINTER(0);
	PG_RETURN_INT32(VARSIZE_ANY_EXHDR(kmer));
}

PG_FUNCTION_INFO_V1(qkmer_length);
Datum qkmer_length(PG_FUNCTION_ARGS)
{
	QKMER *qkmer = (QKMER *)PG_GETARG_POINTER(0);
	PG_RETURN_INT32(VARSIZE_ANY_EXHDR(qkmer));
}

/* Comparison functions */

// Equals Function
PG_FUNCTION_INFO_V1(kmer_equals);
Datum kmer_equals(PG_FUNCTION_ARGS)
{
	KMER *kmer1 = (KMER *)PG_GETARG_POINTER(0);
	KMER *kmer2 = (KMER *)PG_GETARG_POINTER(1);

	// If either of the value is null return false
	if (PG_ARGISNULL(0) || PG_ARGISNULL(1))
		PG_RETURN_BOOL(false);

	int len1 = VARSIZE_ANY_EXHDR(kmer1);
	int len2 = VARSIZE_ANY_EXHDR(kmer2);

	// if lengths are unequal, then they are automatically unequal
	if (len1 != len2)
		PG_RETURN_BOOL(false);

	bool result = memcmp(VARDATA_ANY(kmer1), VARDATA_ANY(kmer2), len1) == 0;
	PG_RETURN_BOOL(result);
}

// starts with function
PG_FUNCTION_INFO_V1(kmer_starts_with);
Datum kmer_starts_with(PG_FUNCTION_ARGS)
{
	KMER *prefix = (KMER *)PG_GETARG_POINTER(0);
	KMER *kmer = (KMER *)PG_GETARG_POINTER(1);

	int len1 = VARSIZE_ANY_EXHDR(prefix);
	int len2 = VARSIZE_ANY_EXHDR(kmer);

	// if length of prefix greater than kmer then its always false
	if (len1 > len2)
		PG_RETURN_BOOL(false);

	bool result = memcmp(VARDATA_ANY(prefix), VARDATA_ANY(kmer), len1) == 0;

	PG_RETURN_BOOL(result);
}

// starts with function specially for the operator
PG_FUNCTION_INFO_V1(kmer_starts_with_op);
Datum kmer_starts_with_op(PG_FUNCTION_ARGS)
{
	KMER *kmer = (KMER *)PG_GETARG_POINTER(0);
	KMER *prefix = (KMER *)PG_GETARG_POINTER(1);

	int len1 = VARSIZE_ANY_EXHDR(prefix);
	int len2 = VARSIZE_ANY_EXHDR(kmer);

	// if length of prefix greater than kmer then its always false
	if (len1 > len2)
		PG_RETURN_BOOL(false);

	bool result = memcmp(VARDATA_ANY(prefix), VARDATA_ANY(kmer), len1) == 0;

	PG_RETURN_BOOL(result);
}

// contains function
PG_FUNCTION_INFO_V1(kmer_contains);
Datum kmer_contains(PG_FUNCTION_ARGS)
{
	QKMER *qkmer = (QKMER *)PG_GETARG_POINTER(0);
	KMER *kmer = (KMER *)PG_GETARG_POINTER(1);

	int len1 = VARSIZE_ANY_EXHDR(qkmer);
	int len2 = VARSIZE_ANY_EXHDR(kmer);

	// if length of Qkmer and kmer not equal then that is not a match
	if (len1 != len2)
		PG_RETURN_BOOL(false);

	char *qkmer_str = VARDATA_ANY(qkmer);
	char *kmer_str = VARDATA_ANY(kmer);

	for (int i = 0; i < len1; i++)
	{

		if (!match(qkmer_str[i], kmer_str[i]))
		{
			PG_RETURN_BOOL(false);
		}
	}

	PG_RETURN_BOOL(true);
}

/* kmer_lt: Returns true if a < b */
PG_FUNCTION_INFO_V1(kmer_lt);
Datum kmer_lt(PG_FUNCTION_ARGS)
{
    KMER *a = (KMER *) PG_GETARG_POINTER(0);
    KMER *b = (KMER *) PG_GETARG_POINTER(1);

    PG_RETURN_BOOL(kmer_compare(a, b) < 0);
}

/* kmer_le: Returns true if a <= b */
PG_FUNCTION_INFO_V1(kmer_le);
Datum kmer_le(PG_FUNCTION_ARGS)
{
    KMER *a = (KMER *) PG_GETARG_POINTER(0);
    KMER *b = (KMER *) PG_GETARG_POINTER(1);

    PG_RETURN_BOOL(kmer_compare(a, b) <= 0);
}

/* kmer_gt: Returns true if a > b */
PG_FUNCTION_INFO_V1(kmer_gt);
Datum kmer_gt(PG_FUNCTION_ARGS)
{
    KMER *a = (KMER *) PG_GETARG_POINTER(0);
    KMER *b = (KMER *) PG_GETARG_POINTER(1);

    PG_RETURN_BOOL(kmer_compare(a, b) > 0);
}

/* kmer_ge: Returns true if a >= b */
PG_FUNCTION_INFO_V1(kmer_ge);
Datum kmer_ge(PG_FUNCTION_ARGS)
{
    KMER *a = (KMER *) PG_GETARG_POINTER(0);
    KMER *b = (KMER *) PG_GETARG_POINTER(1);

    PG_RETURN_BOOL(kmer_compare(a, b) >= 0);
}


// generate kmer function
// https://www.postgresql.org/docs/current/xfunc-c.html#XFUNC-C-RETURN-SET
PG_FUNCTION_INFO_V1(generate_kmers);
Datum generate_kmers(PG_FUNCTION_ARGS)
{

	FuncCallContext *funcctx;
	int call_cntr;
	int max_calls;

	if (SRF_IS_FIRSTCALL())
	{

		MemoryContext oldcontext;

		funcctx = SRF_FIRSTCALL_INIT();
		oldcontext = MemoryContextSwitchTo(funcctx->multi_call_memory_ctx);

		DNA *dna = (DNA *)PG_GETARG_POINTER(0);
		int window_size = PG_GETARG_INT32(1);

		int len_dna = VARSIZE_ANY_EXHDR(dna);

		if (len_dna < window_size || window_size <= 0 || window_size > MAX_KMER_LENGTH)
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
					 errmsg("Invalid KMER Length")));

		// Total Number of calls to make
		funcctx->max_calls = len_dna - window_size + 1;

		// User context saved for each call
		funcctx->user_fctx = palloc(sizeof(struct {
			char *sequence;
			int k_size;
		}));

		((struct { char *sequence; int k_size; } *)funcctx->user_fctx)->sequence = pstrdup(VARDATA_ANY(dna));
		((struct { char *sequence; int k_size; } *)funcctx->user_fctx)->k_size = window_size;

		MemoryContextSwitchTo(oldcontext);
	}

	funcctx = SRF_PERCALL_SETUP();

	call_cntr = funcctx->call_cntr;
	max_calls = funcctx->max_calls;

	if (call_cntr < max_calls)
	{

		char *dna_sequence = ((struct { char *sequence; int k_size; } *)funcctx->user_fctx)->sequence;
		int window_size = ((struct { char *sequence; int k_size; } *)funcctx->user_fctx)->k_size;

		KMER *kmer = (KMER *)palloc(VARHDRSZ + window_size);
		SET_VARSIZE(kmer, VARHDRSZ + window_size);
		memcpy(VARDATA(kmer), dna_sequence + call_cntr, window_size);

		SRF_RETURN_NEXT(funcctx, PointerGetDatum(kmer));
	}
	else
	{
		SRF_RETURN_DONE(funcctx);
	}
}

PG_FUNCTION_INFO_V1(kmer_cmp);
Datum kmer_cmp(PG_FUNCTION_ARGS)
{
	KMER *kmer1 = (KMER *)PG_GETARG_POINTER(0);
	KMER *kmer2 = (KMER *)PG_GETARG_POINTER(1);

	int len1 = VARSIZE_ANY_EXHDR(kmer1);
	int len2 = VARSIZE_ANY_EXHDR(kmer2);

	// First compare the lengths
	if (len1 > len2)
		PG_RETURN_INT32(1);
	else if (len1 < len2)
		PG_RETURN_INT32(-1);

	// If lengths are equal, compare the sequences

	PG_RETURN_INT32(0);
}

PG_FUNCTION_INFO_V1(kmer_hash);
Datum kmer_hash(PG_FUNCTION_ARGS)
{
	KMER *kmer = (KMER *)PG_GETARG_POINTER(0);
	int len = VARSIZE_ANY_EXHDR(kmer);
	Datum result;

	/* Use the built-in hash function on the entire KMER contents */
	result = hash_any((unsigned char *)VARDATA_ANY(kmer), len);

	PG_RETURN_DATUM(result);
}


/*SP-Gist index functions implementation*/
PG_FUNCTION_INFO_V1(kmer_config);
Datum kmer_config(PG_FUNCTION_ARGS)
{
	spgConfigOut *cfg = (spgConfigOut *)PG_GETARG_POINTER(1);

	Oid KMEROID = TypenameGetTypid("kmer");

	/* Set the prefix and label types specific to the kmer data type */
	cfg->prefixType = KMEROID;
	cfg->labelType = INT2OID;
	cfg->leafType = KMEROID;
	cfg->canReturnData = true;
	cfg->longValuesOK = false;

	PG_RETURN_VOID();
}

PG_FUNCTION_INFO_V1(kmer_choose);
Datum kmer_choose(PG_FUNCTION_ARGS)
{
	spgChooseIn *in = (spgChooseIn *) PG_GETARG_POINTER(0);
	spgChooseOut *out = (spgChooseOut *) PG_GETARG_POINTER(1);

	KMER *inKmer = (KMER *) DatumGetPointer(in->datum);
	char *inStr = inKmer->sequence;
	int inSize = inKmer->length;
	char *prefixStr = NULL;
	int prefixSize = 0;
	int commonLen = 0;
	int16 nodeChar = 0;
	int i = 0;

	/* Check for prefix match, set nodeChar to first byte after prefix */
	if (in->hasPrefix)
	{
		KMER *prefixKmer = (KMER *)DatumGetPointer(in->prefixDatum);
		prefixStr = prefixKmer->sequence;
		prefixSize = prefixKmer->length;

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

PG_FUNCTION_INFO_V1(kmer_picksplit);
Datum kmer_picksplit(PG_FUNCTION_ARGS)
{
	spgPickSplitIn *in = (spgPickSplitIn *)PG_GETARG_POINTER(0);
	spgPickSplitOut *out = (spgPickSplitOut *)PG_GETARG_POINTER(1);
	KMER *kmer0 = (KMER *)DatumGetPointer(in->datums[0]);
	int i, commonLen;
	spgNodePtr *nodes;

	/* Identify longest common prefix length among k-mers */
	commonLen = kmer0->length;
	for (i = 1; i < in->nTuples && commonLen > 0; i++)
	{
		KMER *kmeri = (KMER *)DatumGetPointer(in->datums[i]);
		int tmp = commonPrefix(kmer0->sequence, kmeri->sequence, kmer0->length, kmeri->length);

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
		out->prefixDatum = formKmerDatum(kmer0->sequence, commonLen);
	}

	/* Initialize node pointers based on first non-common byte */
	nodes = (spgNodePtr *)palloc(sizeof(spgNodePtr) * in->nTuples);

	for (i = 0; i < in->nTuples; i++)
	{
		KMER *kmeri = (KMER *)DatumGetPointer(in->datums[i]);

		if (commonLen < kmeri->length)
			nodes[i].c = *(unsigned char *)(kmeri->sequence + commonLen);
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

		if (commonLen < kmeri->length)
			leafD = formKmerDatum(kmeri->sequence + commonLen + 1, kmeri->length - commonLen - 1);
		else
			leafD = formKmerDatum(NULL, 0);

		out->leafTupleDatums[nodes[i].i] = leafD;
		out->mapTuplesToNodes[nodes[i].i] = out->nNodes - 1;
	}

	PG_RETURN_VOID();
}

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
	Assert(reconstructedValue == NULL ? in->level == 0 : reconstructedValue->length == in->level);

	maxReconstrLen = in->level + 1; /* Start with current level length */
	if (in->hasPrefix)
	{
		prefixKmer = (KMER *)DatumGetPointer(in->prefixDatum);
		prefixSize = prefixKmer->length;
		maxReconstrLen += prefixSize;
	}

	/* Allocate and construct the new reconstructed k-mer */
	reconstrKmer = (KMER *)palloc(VARHDRSZ + maxReconstrLen);
	SET_VARSIZE(reconstrKmer, VARHDRSZ + maxReconstrLen);

	if (in->level)
		memcpy(reconstrKmer->sequence, reconstructedValue->sequence, in->level);
	if (prefixSize)
		memcpy(reconstrKmer->sequence + in->level, prefixKmer->sequence, prefixSize);

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
			reconstrKmer->sequence[maxReconstrLen - 1] = (char)nodeChar;
			thisLen = maxReconstrLen;
		}

		for (j = 0; j < in->nkeys; j++)
		{
			StrategyNumber strategy = in->scankeys[j].sk_strategy;
			KMER *inKmer = (KMER *)DatumGetPointer(in->scankeys[j].sk_argument);
			int inSize = inKmer->length;
			int r = memcmp(reconstrKmer->sequence, inKmer->sequence, Min(inSize, thisLen));

			/* Apply the strategy for comparisons */
			switch (strategy)
			{
			case BTLessStrategyNumber:
			case BTLessEqualStrategyNumber:
				if (r > 0)
					res = false;
				break;
			case BTEqualStrategyNumber:
				if (r != 0 || inSize < thisLen)
					res = false;
				break;
			case BTGreaterEqualStrategyNumber:
			case BTGreaterStrategyNumber:
				if (r < 0)
					res = false;
				break;
			case RTPrefixStrategyNumber:
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
			SET_VARSIZE(reconstrKmer, VARHDRSZ + thisLen);
			out->reconstructedValues[out->nNodes] = datumCopy(PointerGetDatum(reconstrKmer), false, -1);
			out->nNodes++;
		}
	}

	PG_RETURN_VOID();
}

PG_FUNCTION_INFO_V1(kmer_leaf_consistent);
Datum kmer_leaf_consistent(PG_FUNCTION_ARGS)
{
	spgLeafConsistentIn *in = (spgLeafConsistentIn *) PG_GETARG_POINTER(0);
	spgLeafConsistentOut *out = (spgLeafConsistentOut *) PG_GETARG_POINTER(1);
	int level = in->level;
	KMER *leafValue, *reconstrValue = NULL;
	char *fullValue;
	int fullLen;
	bool res;
	int j;

	/* All tests are exact, so recheck is not required */
	out->recheck = false;

	leafValue = (KMER *) DatumGetPointer(in->leafDatum);

	/* Get the reconstructed value from the previous level, if any */
	if (DatumGetPointer(in->reconstructedValue))
		reconstrValue = (KMER *) DatumGetPointer(in->reconstructedValue);

	Assert(reconstrValue == NULL ? level == 0 : reconstrValue->length == level);

	/* Calculate the full length for reconstructed k-mer */
	fullLen = level + leafValue->length;
	if (leafValue->length == 0 && level > 0)
	{
		fullValue = reconstrValue->sequence;
		out->leafValue = PointerGetDatum(reconstrValue);
	}
	else
	{
		/* Allocate and build the full k-mer sequence */
		KMER *fullKmer = palloc(VARHDRSZ + fullLen);
		SET_VARSIZE(fullKmer, VARHDRSZ + fullLen);
		fullValue = fullKmer->sequence;

		/* Copy previous reconstruction and leafValue sequences */
		if (level)
			memcpy(fullValue, reconstrValue->sequence, level);
		if (leafValue->length > 0)
			memcpy(fullValue + level, leafValue->sequence, leafValue->length);

		out->leafValue = PointerGetDatum(fullKmer);
	}

	/* Perform the required comparisons based on strategy */
	res = true;
	for (j = 0; j < in->nkeys; j++)
	{
		StrategyNumber strategy = in->scankeys[j].sk_strategy;
		KMER *query = (KMER *)DatumGetPointer(in->scankeys[j].sk_argument);
		int queryLen = query->length;
		int r = memcmp(fullValue, query->sequence, Min(queryLen, fullLen));

		/* Adjust comparison based on lengths if necessary */
		if (r == 0)
		{
			if (queryLen > fullLen)
				r = -1;
			else if (queryLen < fullLen)
				r = 1;
		}

		/* Apply the comparison strategy */
		switch (strategy)
		{
		case BTLessStrategyNumber:
			res = (r < 0);
			break;
		case BTLessEqualStrategyNumber:
			res = (r <= 0);
			break;
		case BTEqualStrategyNumber:
			res = (r == 0);
			break;
		case BTGreaterEqualStrategyNumber:
			res = (r >= 0);
			break;
		case BTGreaterStrategyNumber:
			res = (r > 0);
			break;
		case RTPrefixStrategyNumber:
			/* Prefix match checks the start of the full sequence */
			res = (level >= queryLen) ||
				  (memcmp(fullValue, query->sequence, queryLen) == 0);
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
