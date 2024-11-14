/*
 * kmer.c
 */

#include "kmer.h"

#include "fmgr.h"
#include "funcapi.h"
#include <ctype.h>
#include "access/spgist.h"
#include "catalog/pg_type.h"
#include "utils/builtins.h"
#include "utils/elog.h"

PG_MODULE_MAGIC;

/*****************************************************************************/

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

/* Helper function to compare two kmer sequences */
static int
kmer_compare(const KMER *a, const KMER *b)
{
    int min_len = Min(VARSIZE_ANY_EXHDR(a), VARSIZE_ANY_EXHDR(b));
    int cmp = memcmp(VARDATA_ANY(a), VARDATA_ANY(b), min_len);

    if (cmp != 0) {
        return cmp;
    } else {
        /* If sequences are equal up to min_len, shorter kmer is considered smaller */
        if (VARSIZE_ANY_EXHDR(a) < VARSIZE_ANY_EXHDR(b)) return -1;
        else if (VARSIZE_ANY_EXHDR(a) > VARSIZE_ANY_EXHDR(b)) return 1;
        else return 0;
    }
}

/* DNA Input and Output Functions */
PG_FUNCTION_INFO_V1(dna_in);
Datum dna_in(PG_FUNCTION_ARGS)
{
	char *input = PG_GETARG_CSTRING(0);

	validate_sequence(input);

	DNA *result = (DNA *)cstring_to_text(input);
	PG_RETURN_POINTER(result);
}

PG_FUNCTION_INFO_V1(dna_out);
Datum dna_out(PG_FUNCTION_ARGS)
{
	DNA *dna = (DNA *)PG_GETARG_POINTER(0);
	char *result = psprintf("%.*s", VARSIZE_ANY_EXHDR(dna), VARDATA_ANY(dna));

	PG_RETURN_CSTRING(result);
}

/* KMER Input and Output Functions */
PG_FUNCTION_INFO_V1(kmer_in);
Datum kmer_in(PG_FUNCTION_ARGS)
{
    char *input = PG_GETARG_CSTRING(0);
    int len = strlen(input);

    if (len > MAX_KMER_LENGTH)
   	{
   		ereport(ERROR,
   				(errcode(ERRCODE_STRING_DATA_RIGHT_TRUNCATION),
   				 errmsg("KMer Sequence larger than length 32")));
   	}

    validate_sequence(input);

    KMER *result = (KMER *)cstring_to_text(input);
    PG_RETURN_POINTER(result);
}

PG_FUNCTION_INFO_V1(kmer_out);
Datum kmer_out(PG_FUNCTION_ARGS)
{
	KMER *kmer = (KMER *)PG_GETARG_POINTER(0);
	char *result = psprintf("%.*s", VARSIZE_ANY_EXHDR(kmer), VARDATA_ANY(kmer));

	PG_RETURN_CSTRING(result);
}

/* QKMER Input and Output Functions */
PG_FUNCTION_INFO_V1(qkmer_in);
Datum qkmer_in(PG_FUNCTION_ARGS)
{
	char *input = PG_GETARG_CSTRING(0);
	int len = strlen(input);
	char *ptr = input;
	char c;

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

	QKMER *result = (QKMER *)cstring_to_text(input);
	PG_RETURN_POINTER(result);
}

PG_FUNCTION_INFO_V1(qkmer_out);
Datum qkmer_out(PG_FUNCTION_ARGS)
{
	QKMER *qkmer = (QKMER *)PG_GETARG_POINTER(0);
	char *result = psprintf("%.*s", VARSIZE_ANY_EXHDR(qkmer), VARDATA_ANY(qkmer));

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
