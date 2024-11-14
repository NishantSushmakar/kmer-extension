/*
 * kmer_spgist.h
 */

#include "postgres.h"
#include "utils/varlena.h"
#include <varatt.h>

// Struct for sorting values in picksplit
typedef struct spgNodePtr
{
    Datum d;
    int i;
    int16 c;
} spgNodePtr;

#define SPGIST_MAX_PREFIX_LENGTH Max((int)(BLCKSZ - 258 * 16 - 100), 32)

// Define value for VARATT_SHORT_MAX if not already definided
#ifndef VARATT_SHORT_MAX
#define VARATT_SHORT_MAX 127
#endif

// Define value for VARHDRSZ_SHORT if not already definided
#ifndef VARHDRSZ_SHORT
#define VARHDRSZ_SHORT 1
#endif

/*SP-Gist index helper functions*/
// Create a new KMER
static inline Datum
formKmerDatum(const char *data, int datalen)
{
    char *kmer;
    Assert(datalen + VARHDRSZ_SHORT <= VARATT_SHORT_MAX);

    kmer = (char *)palloc(datalen + VARHDRSZ);

    // Check if the kmer structure uses the short or regular headers
    if (datalen + VARHDRSZ_SHORT <= VARATT_SHORT_MAX)
    {
        SET_VARSIZE_SHORT(kmer, datalen + VARHDRSZ_SHORT);
        if (datalen)
            memcpy(kmer + VARHDRSZ_SHORT, data, datalen);
    }
    else
    {
        SET_VARSIZE(kmer, datalen + VARHDRSZ);
        memcpy(kmer + VARHDRSZ, data, datalen);
    }

    // Return the KMER structure as a Datum
    return PointerGetDatum(kmer);
}

// Checks if two kmers have the same prefix
static inline int
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

// Qsort comparator to sort spgNodePtr structs by "c"
static inline int
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

// Checks if a given char is present in the node label
static inline bool
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