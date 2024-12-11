/*
 * kmer.h
 */

#include "postgres.h"
#include "utils/varlena.h"

// DNA Sequence Type
typedef struct varlena DNA;

// K-mer Type
typedef struct varlena KMER;

// Query K-mer Type
typedef struct varlena QKMER;

// Maximum length for kmer and qkmer types
#define MAX_KMER_LENGTH 32

// Helper Function to  match the possible DNA sequences for a given QKMer
static inline bool
match(char pattern, char nucleotide)
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