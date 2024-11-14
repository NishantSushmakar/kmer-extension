-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION kmer" to load this file. \quit

CREATE OR REPLACE FUNCTION dna_in(cstring)
    RETURNS dna
    AS 'MODULE_PATHNAME'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE OR REPLACE FUNCTION dna_out(dna)
    RETURNS cstring
    AS 'MODULE_PATHNAME'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE TYPE dna (
    INPUT = dna_in,
    OUTPUT = dna_out,
    INTERNALLENGTH = VARIABLE
);

CREATE OR REPLACE FUNCTION kmer_in(cstring)
    RETURNS kmer
    AS 'MODULE_PATHNAME'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE OR REPLACE FUNCTION kmer_out(kmer)
    RETURNS cstring
    AS 'MODULE_PATHNAME'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE TYPE kmer (
    INPUT = kmer_in,
    OUTPUT = kmer_out,
    INTERNALLENGTH = VARIABLE
);

CREATE OR REPLACE FUNCTION qkmer_in(cstring)
    RETURNS qkmer
    AS 'MODULE_PATHNAME'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE OR REPLACE FUNCTION qkmer_out(qkmer)
    RETURNS cstring
    AS 'MODULE_PATHNAME'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE TYPE qkmer (
    INPUT = qkmer_in,
    OUTPUT = qkmer_out,
    INTERNALLENGTH = VARIABLE
);

-- Length functions
CREATE FUNCTION length(dna)
    RETURNS integer
    AS 'MODULE_PATHNAME', 'dna_length'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION length(kmer)
    RETURNS integer
    AS 'MODULE_PATHNAME', 'kmer_length'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION length(qkmer)
    RETURNS integer
    AS 'MODULE_PATHNAME', 'qkmer_length'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

-- Comparison functions
CREATE FUNCTION equals(kmer, kmer)
    RETURNS boolean
    AS 'MODULE_PATHNAME', 'kmer_equals'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION starts_with(kmer, kmer)
    RETURNS boolean
    AS 'MODULE_PATHNAME', 'kmer_starts_with'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION starts_with_op(kmer,kmer)
    RETURNS boolean
    AS 'MODULE_PATHNAME', 'kmer_starts_with_op'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION contains(qkmer,kmer)
    RETURNS boolean
    AS 'MODULE_PATHNAME', 'kmer_contains'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION kmer_lt(kmer, kmer) 
    RETURNS boolean
    AS 'MODULE_PATHNAME', 'kmer_lt'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION kmer_le(kmer, kmer) 
    RETURNS boolean
    AS 'MODULE_PATHNAME', 'kmer_le'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION kmer_gt(kmer, kmer) 
    RETURNS boolean
    AS 'MODULE_PATHNAME', 'kmer_gt'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION kmer_ge(kmer, kmer) 
    RETURNS boolean
    AS 'MODULE_PATHNAME', 'kmer_ge'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

-- Generator Function
CREATE OR REPLACE FUNCTION generate_kmers(dna, integer)
    RETURNS SETOF kmer
    AS 'MODULE_PATHNAME', 'generate_kmers'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

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
    PROCEDURE = starts_with_op
);

-- Contains Operator
CREATE OPERATOR @> (
    LEFTARG = qkmer,
    RIGHTARG = kmer,
    PROCEDURE = contains
);

CREATE OPERATOR < (
    LEFTARG = kmer,
    RIGHTARG = kmer,
    PROCEDURE = kmer_lt
);

CREATE OPERATOR <= (
    LEFTARG = kmer,
    RIGHTARG = kmer,
    PROCEDURE = kmer_le
);

CREATE OPERATOR >= (
    LEFTARG = kmer,
    RIGHTARG = kmer,
    PROCEDURE = kmer_ge
);

CREATE OPERATOR > (
    LEFTARG = kmer,
    RIGHTARG = kmer,
    PROCEDURE = kmer_gt
);

CREATE FUNCTION kmer_config(internal, internal)
    RETURNS void
    AS 'MODULE_PATHNAME', 'kmer_config'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION kmer_choose(internal, internal)
    RETURNS void
    AS 'MODULE_PATHNAME', 'kmer_choose'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION kmer_picksplit(internal, internal)
    RETURNS void
    AS 'MODULE_PATHNAME', 'kmer_picksplit'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION kmer_inner_consistent(internal, internal)
    RETURNS void
    AS 'MODULE_PATHNAME', 'kmer_inner_consistent'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION kmer_leaf_consistent(internal, internal)
    RETURNS boolean
    AS 'MODULE_PATHNAME', 'kmer_leaf_consistent'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

-- Create the operator class for SP-GiST support
CREATE OPERATOR CLASS kmer_spgist_ops
    DEFAULT FOR TYPE kmer USING SPGIST AS
    -- Define the required SP-GiST support functions
    OPERATOR 3 = (kmer, kmer),
    OPERATOR 7 @> (qkmer, kmer),
    OPERATOR 28 ^@ (kmer, kmer),
    FUNCTION 1 kmer_config(internal, internal),
    FUNCTION 2 kmer_choose(internal, internal),
    FUNCTION 3 kmer_picksplit(internal, internal),
    FUNCTION 4 kmer_inner_consistent(internal, internal),
    FUNCTION 5 kmer_leaf_consistent(internal, internal);