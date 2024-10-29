-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION kmer" to load this file. \quit

CREATE OR REPLACE FUNCTION dna_in(cstring)
    RETURNS dna
    AS 'MODULE_PATHNAME'
    LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION dna_out(dna)
    RETURNS cstring
    AS 'MODULE_PATHNAME'
    LANGUAGE C IMMUTABLE STRICT;

CREATE TYPE dna (
    INPUT = dna_in,
    OUTPUT = dna_out,
    INTERNALLENGTH = VARIABLE
);

CREATE OR REPLACE FUNCTION kmer_in(cstring)
    RETURNS kmer
    AS 'MODULE_PATHNAME'
    LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION kmer_out(kmer)
    RETURNS cstring
    AS 'MODULE_PATHNAME'
    LANGUAGE C IMMUTABLE STRICT;

CREATE TYPE kmer (
    INPUT = kmer_in,
    OUTPUT = kmer_out,
    INTERNALLENGTH = VARIABLE
);

CREATE OR REPLACE FUNCTION qkmer_in(cstring)
    RETURNS qkmer
    AS 'MODULE_PATHNAME'
    LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION qkmer_out(qkmer)
    RETURNS cstring
    AS 'MODULE_PATHNAME'
    LANGUAGE C IMMUTABLE STRICT;

CREATE TYPE qkmer (
    INPUT = qkmer_in,
    OUTPUT = qkmer_out,
    INTERNALLENGTH = VARIABLE
);

-- Length functions
CREATE FUNCTION length(dna)
    RETURNS integer
    AS 'MODULE_PATHNAME', 'dna_length'
    LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION length(kmer)
    RETURNS integer
    AS 'MODULE_PATHNAME', 'kmer_length'
    LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION length(qkmer)
    RETURNS integer
    AS 'MODULE_PATHNAME', 'qkmer_length'
    LANGUAGE C IMMUTABLE STRICT;

-- Comparison functions
CREATE FUNCTION equals(kmer, kmer)
    RETURNS boolean
    AS 'MODULE_PATHNAME', 'kmer_equals'
    LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION starts_with(kmer, kmer)
    RETURNS boolean
    AS 'MODULE_PATHNAME', 'kmer_starts_with'
    LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION starts_with_op(kmer,kmer)
    RETURNS boolean
    AS 'MODULE_PATHNAME', 'kmer_starts_with_op'
    LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION contains(qkmer,kmer)
    RETURNS boolean
    AS 'MODULE_PATHNAME', 'kmer_contains'
    LANGUAGE C IMMUTABLE STRICT;

-- Generator Function
CREATE OR REPLACE FUNCTION generate_kmers(dna, integer)
    RETURNS SETOF kmer
    AS 'MODULE_PATHNAME', 'generate_kmers'
    LANGUAGE C IMMUTABLE STRICT;


-- Comparison operators

-- Equal Operator
CREATE OPERATOR = (
  LEFTARG = kmer, RIGHTARG = kmer,
  PROCEDURE = equals
);
-- Starts with Operator
CREATE OPERATOR ^@ (
    LEFTARG = kmer,
    RIGHTARG = kmer,
    PROCEDURE= starts_with_op
);

-- Contains Operator
CREATE OPERATOR @> (
    LEFTARG = qkmer,
    RIGHTARG = kmer,
    PROCEDURE= contains
);

