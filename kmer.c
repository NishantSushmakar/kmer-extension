#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"
#include "lib/stringinfo.h"
#include "utils/elog.h"
#include <ctype.h>

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
    int32 length;
    char sequence[FLEXIBLE_ARRAY_MEMBER];
} KMER;

/* Query K-mer Type */
typedef struct {
    int32 length;
    char sequence[FLEXIBLE_ARRAY_MEMBER];
} QKMER;


/* Helper Function to Validate the DNA Sequence for A,C,G and T characters */

static inline void validate_sequence(char *input){

    char *ptr = input;
    char c;

    for (ptr=input;*ptr;ptr++){
        c = tolower(*ptr);
        *ptr = c;

        if ((c!='a')&&(c!='c')&&(c!='g')&&(c!='t')){
            ereport(ERROR,
                    (errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
                    errmsg("Invalid DNA Sequence"),
                    errdetail("Valid characters are A, C, G, T (case-insensitive).")));

        }
    }

    return;
}



/* DNA Input and Output Functions */
PG_FUNCTION_INFO_V1(dna_in);
Datum
dna_in(PG_FUNCTION_ARGS)
{
    char *input = PG_GETARG_CSTRING(0);
    int len;
    

    len = strlen(input);

    validate_sequence(input);
    

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
    int len;

    
    len = strlen(input);

    if (len > MAX_KMER_LENGTH){
        ereport(ERROR,
                    (errcode(ERRCODE_STRING_DATA_RIGHT_TRUNCATION),
                    errmsg("KMer Sequence larger than length 32")));        

    }


    validate_sequence(input);

    KMER *result = (KMER *) palloc(VARHDRSZ + len);
    SET_VARSIZE(result, VARHDRSZ + len);
    memcpy(result->sequence, input, len);

    PG_RETURN_POINTER(result);
}

PG_FUNCTION_INFO_V1(kmer_out);
Datum
kmer_out(PG_FUNCTION_ARGS)
{
    KMER *kmer = (KMER *) PG_GETARG_POINTER(0);
    char *result = psprintf("%.*s", VARSIZE_ANY_EXHDR(kmer), kmer->sequence);

    PG_RETURN_CSTRING(result);
}

/* QKMER Input and Output Functions */
PG_FUNCTION_INFO_V1(qkmer_in);
Datum
qkmer_in(PG_FUNCTION_ARGS)
{
    char *input = PG_GETARG_CSTRING(0);
    int len;
    char *ptr = input;
    char c;

    len = strlen(input);

    if (len > MAX_KMER_LENGTH){
        ereport(ERROR,
                    (errcode(ERRCODE_STRING_DATA_RIGHT_TRUNCATION),
                    errmsg("QKMer Sequence larger than length 32")));        

    }

    for (ptr=input;*ptr;ptr++){
        c = tolower(*ptr);
        *ptr = c;

        if (c != 'a' &&   // Adenine
        c != 'c' &&   // Cytosine
        c != 'g' &&   // Guanine
        c != 't' &&   // Thymine
        c != 'u' &&   // Uracil
        c != 'r' &&   // A or G
        c != 'y' &&   // C or T
        c != 'k' &&   // G or T
        c != 'm' &&   // A or C
        c != 's' &&   // G or C
        c != 'w' &&   // A or T
        c != 'b' &&   // C, G, or T (not A)
        c != 'd' &&   // A, G, or T (not C)
        c != 'h' &&   // A, C, or T (not G)
        c != 'v' &&   // A, C, or G (not T)
        c != 'n'      // A, T, C, or G (any nucleotide)
        ){ereport(ERROR,
                    (errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
                    errmsg("Invalid QKMer Sequence")));} 

    }   

    QKMER *result = (QKMER *) palloc(VARHDRSZ + len);
    SET_VARSIZE(result, VARHDRSZ + len);
    memcpy(result->sequence, input, len);

    PG_RETURN_POINTER(result);
}

PG_FUNCTION_INFO_V1(qkmer_out);
Datum
qkmer_out(PG_FUNCTION_ARGS)
{
    QKMER *qkmer = (QKMER *) PG_GETARG_POINTER(0);
    char *result = psprintf("%.*s", VARSIZE_ANY_EXHDR(qkmer), qkmer->sequence);

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