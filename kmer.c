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

/* Helper Function to  match the possible DNA sequences for a given QKMer */
static inline bool match(char pattern, char nucleotide){

       if (pattern == nucleotide || pattern == 'n')
            return true;
        
    
        switch(pattern){
        case 'r': return nucleotide == 'a' || nucleotide == 'g';  // puRine
        case 'y': return nucleotide == 'c' || nucleotide == 't';  // pYrimidine
        case 'k': return nucleotide == 'g' || nucleotide == 't';  // Keto
        case 'm': return nucleotide == 'a' || nucleotide == 'c';  // aMino
        case 's': return nucleotide == 'g' || nucleotide == 'c';  // Strong
        case 'w': return nucleotide == 'a' || nucleotide == 't';  // Weak
        case 'b': return nucleotide == 'c' || nucleotide == 'g' || nucleotide == 't';  // not A
        case 'd': return nucleotide == 'a' || nucleotide == 'g' || nucleotide == 't';  // not C
        case 'h': return nucleotide == 'a' || nucleotide == 'c' || nucleotide == 't';  // not G
        case 'v': return nucleotide == 'a' || nucleotide == 'c' || nucleotide == 'g';  // not T
        default: false;

        }

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
    PG_RETURN_INT32(VARSIZE_ANY_EXHDR(kmer));
}

PG_FUNCTION_INFO_V1(qkmer_length);
Datum
qkmer_length(PG_FUNCTION_ARGS)
{
    QKMER *qkmer = (QKMER *) PG_GETARG_POINTER(0);
    PG_RETURN_INT32(VARSIZE_ANY_EXHDR(qkmer));
}

/* Comparison functions */
PG_FUNCTION_INFO_V1(kmer_equals);
Datum
kmer_equals(PG_FUNCTION_ARGS)
{
    KMER *kmer1 = (KMER *) PG_GETARG_POINTER(0);
    KMER *kmer2 = (KMER *) PG_GETARG_POINTER(1);

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

PG_FUNCTION_INFO_V1(kmer_starts_with);
Datum
kmer_starts_with(PG_FUNCTION_ARGS)
{
    KMER *prefix = (KMER *) PG_GETARG_POINTER(0);
    KMER *kmer = (KMER *) PG_GETARG_POINTER(1);


    
    int len1 = VARSIZE_ANY_EXHDR(prefix);
    int len2 = VARSIZE_ANY_EXHDR(kmer);

    // if length of prefix greater than kmer then its always false
    if (len1 > len2)
        PG_RETURN_BOOL(false);
        
    
    bool result = memcmp(VARDATA_ANY(prefix),VARDATA_ANY(kmer),len1) == 0;

    PG_RETURN_BOOL(result);
}

PG_FUNCTION_INFO_V1(kmer_starts_with_op);
Datum
kmer_starts_with_op(PG_FUNCTION_ARGS)
{
    KMER *kmer = (KMER *) PG_GETARG_POINTER(0);
    KMER *prefix = (KMER *) PG_GETARG_POINTER(1);


    
    int len1 = VARSIZE_ANY_EXHDR(prefix);
    int len2 = VARSIZE_ANY_EXHDR(kmer);

    // if length of prefix greater than kmer then its always false
    if (len1 > len2)
        PG_RETURN_BOOL(false);
        
    bool result = memcmp(VARDATA_ANY(prefix),VARDATA_ANY(kmer),len1) == 0;

    PG_RETURN_BOOL(result);
}

PG_FUNCTION_INFO_V1(kmer_contains);
Datum
kmer_contains(PG_FUNCTION_ARGS)
{
    QKMER *qkmer = (QKMER *) PG_GETARG_POINTER(0);
    KMER *kmer = (KMER *) PG_GETARG_POINTER(1);


    
    int len1 = VARSIZE_ANY_EXHDR(qkmer);
    int len2 = VARSIZE_ANY_EXHDR(kmer);

    // if length of Qkmer and kmer not equal then that is not a match
    if (len1 != len2)
        PG_RETURN_BOOL(false);


    char *qkmer_str = VARDATA_ANY(qkmer);
    char *kmer_str = VARDATA_ANY(kmer);      

    for(int i=0;i<len1;i++){

        if(!match(qkmer_str[i],kmer_str[i])){
            PG_RETURN_BOOL(false);
        }

    }

    PG_RETURN_BOOL(true);
}