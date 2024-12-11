/*
 * kmer_spgist.h
 */

#include "postgres.h"
#include "utils/varlena.h"
//#include <varatt.h>

// Struct for sorting values in picksplit
typedef struct spgNodePtr
{
    Datum d;
    int i;
    int16 c;
} spgNodePtr;

// Define value for VARATT_SHORT_MAX if not already defined
#ifndef VARATT_SHORT_MAX
#define VARATT_SHORT_MAX 127
#endif

// Define value for VARHDRSZ_SHORT if not already defined
#ifndef VARHDRSZ_SHORT
#define VARHDRSZ_SHORT 1
#endif