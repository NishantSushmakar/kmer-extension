#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"

PG_MODULE_MAGIC;

/* Maximum length for kmer and qkmer types */
#define MAX_KMER_LENGTH 32

/* DNA Sequence Type */
typedef struct {
    int32 length;
    char sequence[FLEXIBLE_ARRAY_MEMBER];
} DNA;

/* K-mer Type */
typedef struct {
    uint8 length;
    char sequence[MAX_KMER_LENGTH];
} KMER;

/* Query K-mer Type */
typedef struct {
    uint8 length;
    char sequence[MAX_KMER_LENGTH];
} QKMER;

/* DNA Input and Output Functions */
PG_FUNCTION_INFO_V1(dna_in);
Datum
dna_in(PG_FUNCTION_ARGS)
{
    char *input = PG_GETARG_CSTRING(0);
    int len = strlen(input);

    DNA *result = (DNA *) palloc(VARHDRSZ + len);
    SET_VARSIZE(result, VARHDRSZ + len);
    memcpy(result->sequence, input, len);

    PG_RETURN_POINTER(result);
}

PG_FUNCTION_INFO_V1(dna_out);
Datum
dna_out(PG_FUNCTION_ARGS)
{
    DNA *dna = (DNA *) PG_GETARG_POINTER(0);
    char *result = psprintf("%.*s", VARSIZE_ANY_EXHDR(dna), dna->sequence);

    PG_RETURN_CSTRING(result);
}

/* KMER Input and Output Functions */
PG_FUNCTION_INFO_V1(kmer_in);
Datum
kmer_in(PG_FUNCTION_ARGS)
{
    char *input = PG_GETARG_CSTRING(0);
    int len = strlen(input);

    KMER *result = (KMER *) palloc(sizeof(KMER));
    memset(result->sequence, 0, sizeof(result->sequence));
    memcpy(result->sequence, input, len);
    result->length = len;

    PG_RETURN_POINTER(result);
}

PG_FUNCTION_INFO_V1(kmer_out);
Datum
kmer_out(PG_FUNCTION_ARGS)
{
    KMER *kmer = (KMER *) PG_GETARG_POINTER(0);
    char *result = psprintf("%.*s", kmer->length, kmer->sequence);

    PG_RETURN_CSTRING(result);
}

/* QKMER Input and Output Functions */
PG_FUNCTION_INFO_V1(qkmer_in);
Datum
qkmer_in(PG_FUNCTION_ARGS)
{
    char *input = PG_GETARG_CSTRING(0);
    int len = strlen(input);

    QKMER *result = (QKMER *) palloc(sizeof(QKMER));
    memset(result->sequence, 0, sizeof(result->sequence));
    memcpy(result->sequence, input, len);
    result->length = len;

    PG_RETURN_POINTER(result);
}

PG_FUNCTION_INFO_V1(qkmer_out);
Datum
qkmer_out(PG_FUNCTION_ARGS)
{
    QKMER *qkmer = (QKMER *) PG_GETARG_POINTER(0);
    char *result = psprintf("%.*s", qkmer->length, qkmer->sequence);

    PG_RETURN_CSTRING(result);
}

/* Length Functions */
PG_FUNCTION_INFO_V1(dna_length);
Datum
dna_length(PG_FUNCTION_ARGS)
{
    DNA *dna = (DNA *) PG_GETARG_POINTER(0);
    PG_RETURN_INT32(VARSIZE_ANY_EXHDR(dna));
}

PG_FUNCTION_INFO_V1(kmer_length);
Datum
kmer_length(PG_FUNCTION_ARGS)
{
    KMER *kmer = (KMER *) PG_GETARG_POINTER(0);
    PG_RETURN_INT32(kmer->length);
}

PG_FUNCTION_INFO_V1(qkmer_length);
Datum
qkmer_length(PG_FUNCTION_ARGS)
{
    QKMER *qkmer = (QKMER *) PG_GETARG_POINTER(0);
    PG_RETURN_INT32(qkmer->length);
}

/* Comparison functions */
PG_FUNCTION_INFO_V1(kmer_equals);
Datum
kmer_equals(PG_FUNCTION_ARGS)
{
    KMER *kmer1 = (KMER *) PG_GETARG_POINTER(0);
    KMER *kmer2 = (KMER *) PG_GETARG_POINTER(1);

    // if lengths are unequal, then they are automatically unequal
    if (kmer1->length != kmer2->length)
        PG_RETURN_BOOL(false);

    bool result = memcmp(kmer1->sequence, kmer2->sequence, kmer1->length) == 0;
    PG_RETURN_BOOL(result);
}

PG_FUNCTION_INFO_V1(kmer_starts_with);
Datum
kmer_starts_with(PG_FUNCTION_ARGS)
{
    KMER *prefix = (KMER *) PG_GETARG_POINTER(0);
    KMER *kmer = (KMER *) PG_GETARG_POINTER(1);

    // if the prefix length is longer than the kmer, then return false
    if (prefix->length > kmer->length)
        PG_RETURN_BOOL(false);

    PG_RETURN_BOOL(memcmp(prefix->sequence, kmer->sequence, prefix->length) == 0);
}