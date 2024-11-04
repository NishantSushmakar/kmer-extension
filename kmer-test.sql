-- Check length for dna, kmer, qkmer
-- dna : no specified length
-- kmer: maximum length of 32 nucleotides only for standard nucleotides: A, C, G, T
-- qkmer: same as kmer but with the extension of any other nucleotide

-- Tests for length
    -- Empty sequences
    -- Null sequences
    -- Sequences with unsopported characters 

-- Tests for generate_kmers
    -- Unsopported characters 
    -- For 0 characters 
    -- For unmatching length of the sequence and length of final kmers (less and more)
    -- Cartesian Product 
    -- alias for a different data type
    -- Inner/Left/Right Join
    -- Implicit join

-- Tests for equal
    -- Different data types
    -- Using = and != 
    -- Null values
    -- Empty values
    -- Inner/Left/Right Join
    -- Implicit join

-- Tests for starts_with
    -- Inner/Left/Right Join
    -- Implicit join
    -- Null values
    -- Empty values
    -- Searched substring has length greater than the inital sequence
    -- Search for unsopperted characters
    -- works with ˆ@ and NOT ˆ@

-- Tests for contains
    -- Inner/Left/Right Join
    -- Implicit join
    -- Null values
    -- Empty values
    -- Searched substring has length greater than the inital sequence
    -- Search for unsopperted characters
    -- works with @> and NOT @>

-- Tests for GROUP BY 
    -- COUNT DISTINCT
    -- SUM
    -- AVG
    -- MAX
    -- MIN
    -- WINDOW FUNCTIONS
    -- column name and number
    -- duplicate columns
    -- Conmutativity of the grouping
    -- group aggregate functions
