-- ############################# Data Types #############################

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

    -- TEST 1: DNA 

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

    -- TEST 1.1 DEfining valid values
        SELECT 'AAAACCCCGGGGTTTT'::dna, 'ACGTTGCA'::dna;  
    
    -- Result:
        --       dna        |   dna    
        -- ------------------+----------
        -- aaaaccccggggtttt | acgttgca

    -- Execution Plan:

    --                                     QUERY PLAN                                      
    -- -------------------------------------------------------------------------------------
    -- Result  (cost=0.00..0.01 rows=1 width=64) (actual time=0.007..0.008 rows=1 loops=1)
    -- Planning Time: 0.019 ms
    -- Execution Time: 0.445 ms
    -- (3 rows)

-------------------------------------------------------------------------------------

    -- TEST 1.2 Defining invalid values

        SELECT 'ACGTN'::dna; -- Contains invalid character 'N'
    
    -- Result:

        -- ERROR:  Invalid DNA Sequence
        -- LINE 1: SELECT 'ACGTN'::dna;
        --                ^
        -- DETAIL:  Valid characters are A, C, G, T (case-insensitive).

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

    -- TEST 2: KMER 

-------------------------------------------------------------------------------------    
-------------------------------------------------------------------------------------

    -- TEST 2.1 Defining valid values
        SELECT 'AAAACCCCGGGGTTTTAAAACCCCGGGGTTTT'::kmer, 'GATTACA'::kmer;                      
    
    -- Result:
        --                kmer               |  kmer   
        -- ----------------------------------+---------
        --  aaaaccccggggttttaaaaccccggggtttt | gattaca
        -- (1 row)
    
    -- Execution Plan
        --                                      QUERY PLAN                                      
        -- -------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=64) (actual time=0.003..0.004 rows=1 loops=1)
        --  Planning Time: 0.030 ms
        --  Execution Time: 0.022 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

    -- TEST 2.2 Defining invalid values
        
        SELECT 'AAAAAAAACCCCCCCCGGGGGGGGTTTTTTTTT'::kmer; -- Exceeds 32 nucleotides
    
    -- Result

        -- ERROR:  KMer Sequence larger than length 32
        -- LINE 1: SELECT 'AAAAAAAACCCCCCCCGGGGGGGGTTTTTTTTT'::kmer


-------------------------------------------------------------------------------------

    -- TEST 2.3 Defining invalid values

        SELECT 'AGTCN'::kmer; -- Contains invalid character 'N'
    
    -- Result

        -- ERROR:  Invalid DNA Sequence
        -- LINE 1: SELECT 'AGTCN'::kmer;
        --                ^
        -- DETAIL:  Valid characters are A, C, G, T (case-insensitive).

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

    -- TEST 3: QKMER

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

    -- TEST 3.1: Defining valid values
    
        SELECT 'ACGT'::qkmer, 'AAAAAAAACCCCCCCCGGGGGGGGTTTTTTTT'::qkmer;
    
    -- Result
        --  qkmer |              qkmer               
        -- -------+----------------------------------
        --  acgt  | aaaaaaaaccccccccggggggggtttttttt
        -- (1 row)

    -- Execution Plan

        --                                      QUERY PLAN                                      
        -- -------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=64) (actual time=0.003..0.003 rows=1 loops=1)
        --  Planning Time: 0.033 ms
        --  Execution Time: 0.016 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

    -- TEST 3.2 Defining invalid values
        
        SELECT 'AAAAAAAACCCCCCCCGGGGGGGGTTTTTTTTT'::qkmer; -- Exceeds 32 nucleotides
    
    -- Result 
        --ERROR:  QKMer Sequence larger than length 32
        --LINE 1: SELECT 'AAAAAAAACCCCCCCCGGGGGGGGTTTTTTTTT'::qkmer;
        --               ^

-------------------------------------------------------------------------------------

    -- TEST 3.2 Defining invalid values
    
        SELECT 'ACGT123'::qkmer; -- Contains numbers
    
    -- Result
        -- ERROR:  Invalid QKMer Sequence
        -- LINE 1: SELECT 'ACGT123'::qkmer;
        --         ^


-- ######################################################################




-- ############################## length ################################

-- Functionality Test: Test if the function works as expected
    SELECT length('ACGTACGT'::dna), length('ACGTACGT'::kmer), length('RYN'::qkmer);

-- Empty sequences: Measure the length of empty sequences
    SELECT length(''::dna), length(''::kmer), length(''::qkmer);

-- Null sequences: Measure the length of null sequences
    SELECT length(NULL::dna), length(NULL::kmer), length(NULL::qkmer);

-- ########################################################################




-- ############################ generate_kmers ############################

-- Empty sequences: Generate kmers with length 0
    SELECT * FROM generate_kmers('ACGT'::dna, 0); -- Throw error

-- Unmatching length: Generate kmers with different lengths
-- length less than K: Return an exception
    SELECT * FROM generate_kmers('AC'::dna, 5); 

-- length greater than k: Return 6 sequences
    SELECT * FROM generate_kmers('ACGTACGT'::dna, 3); 

-- length equal than k: Return the same sequence
    SELECT * FROM generate_kmers('ACGTACGT'::dna, 8); 


-- ################################ = Operator ################################

-- Functionality Test: Test whether the operator works as expected or not
    SELECT 'ACGTACGT'::kmer = 'ACGTACGT'::kmer; -- Return True

-- Null values: Test whether two null values are the same or whether a null value and a non null are the same 
    SELECT 
            NULL::kmer = 'ACGTA'::kmer, -- Return NULL 
            NULL::kmer = NULL::kmer, -- Return Null
            ''::kmer = NULL::kmer; -- Return Null

-- Empty values: Test whether two empty sequences are the same or one empty and one full sequence
    -- Return True
    SELECT ''::kmer = ''::kmer;

    -- Return False
    SELECT 'A'::kmer = ''::kmer;

-- ########################################################################



-- ################################ equals ################################
-- Functionality Test: Test whether the function works as expected or not
    SELECT equals('ACGTACGT'::kmer, 'ACGTACGT'::kmer); -- Return True

-- Null values: Test whether two null values are the same or whether a null value and a non null are the same 
    SELECT 
            equals(NULL::kmer, 'ACGTA'::kmer), -- Return NULL 
            equals(NULL::kmer, NULL::kmer), -- Return Null
            equals(''::kmer, NULL::kmer); -- Return Null

-- Empty values: Test whether two empty sequences are the same or one empty and one full sequence
    -- Return True
    SELECT equals(''::kmer, ''::kmer);

    -- Return False
    SELECT equals('A'::kmer, ''::kmer);


-- ########################################################################



-- ############################# starts_with ##############################

-- Functionality Test: Test whether the function works as expected or not
    SELECT starts_with('ACG'::kmer, 'ACGTACGT'::kmer); -- Return True

-- Null values
    SELECT starts_with(NULL::kmer, 'ACGT'::kmer), -- return null
            starts_with('ACGT'::kmer, NULL::kmer); -- return null

-- Empty values
    SELECT starts_with(''::kmer, 'AGT'::kmer); -- Return True

-- Search substring with length greater than the initial sequence
    SELECT starts_with('ACGTACGT'::kmer, 'AC'::kmer); -- Return false

-- Data type mismatch.
    SELECT starts_with('RCGT'::qkmer, 'ACGT'::dna); -- Error: Data type mismatch
    SELECT starts_with('ACGT'::qkmer, 'ACGT'::dna); -- Error: Data type mismatch

-- ########################################################################



-- ############################## ^@ Operator #############################

-- Functionality Test: Test whether the operator works as expected or not
    SELECT 'ACGTACGT'::kmer  ^@ 'ACG'::kmer ; -- Return True

-- ^@ Operator Functionality: Test wether the operator works as expected
    SELECT 'ACGT'::kmer ^@ 'AC'; -- Return True

-- Null values
    SELECT NULL::kmer ^@ 'ACGT'::kmer, -- return null
            'ACGT'::kmer ^@ NULL::kmer; -- return null

-- Empty values
    SELECT ''::kmer ^@ 'AGT'::kmer; -- Return False
    SELECT   'AGT'::kmer ^@ ''::kmer; -- Return True

-- Search substring with length greater than the initial sequence
    SELECT 'AC'::kmer ^@ 'ACGTACGT'::kmer; -- Return false

-- Data type mismatch.
    SELECT 'RCGT'::qkmer ^@ 'ACGT'::dna; -- Error: Data type mismatch
    SELECT 'ACGT'::qkmer ^@ 'ACGT'::dna; -- Error: Data type mismatch

-- ########################################################################



-- ############################### contains ###############################

-- Functionality Test: Test whether the function works as expected or not
    SELECT contains('ACG'::qkmer, 'ACGTACGT'::kmer); -- Return False
    SELECT contains('ACNTANGT'::qkmer, 'ACGTACGT'::kmer); -- Return True

-- Null values
    SELECT contains(NULL::qkmer, 'ACGT'::kmer), -- return null
            contains('ACGT'::qkmer, NULL::kmer); -- return null

-- Empty values
    SELECT contains(''::qkmer, 'AGT'::kmer); -- Return True

-- Search substring with length greater than the initial sequence
    SELECT contains('ACGTACGT'::qkmer, 'AC'::kmer); -- Return false

-- Data type mismatch.
    SELECT contains('RCGT'::qkmer, 'ACGT'::dna); -- Error: Data type mismatch
    SELECT contains('ACGT'::qkmer, 'ACGT'::dna); -- Error: Data type mismatch

-- ########################################################################



-- ############################## @> Operator #############################

-- Functionality Test: Test whether the operator works as expected or not
    SELECT 'ACG'::qkmer @> 'ACGTACGT'::kmer; -- Return False
    SELECT 'ACNTANGT'::qkmer @> 'ACGTACGT'::kmer; -- Return True

-- @> Operator Functionality: Test wether the operator works as expected
    SELECT 'ACGT'::qkmer @> 'AC'; -- Return False

-- Null values
    SELECT NULL::qkmer @> 'ACGT'::kmer, -- return null
            'ACGT'::qkmer @> NULL::kmer; -- return null

-- Empty values
    SELECT ''::qkmer @> 'AGT'::kmer; -- Return False

-- Search substring with length greater than the initial sequence
    SELECT 'ACGTACGT'::qkmer @> 'AC'::kmer; -- Return false

-- Data type mismatch.
    SELECT 'RCGT'::qkmer @> 'ACGT'::kmer; -- Error: Data type mismatch
    SELECT 'ACGT'::qkmer @> 'ACGT'::kmer; -- Error: Data type mismatch

-- ########################################################################



-- ############################### Count ###############################

-- COUNT 
-- Return 5
    SELECT COUNT(k.kmer) 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS k(kmer); 

-- ########################################################################



-- ############################### GROUP BY ###############################

-- GROUP BY Using column name and number in the clause
-- Return 5 rows with 1 in each count, but for ACGT, which should be 2

    SELECT k.kmer, COUNT(*) as kmer_count 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS k(kmer) 
    GROUP BY 1;
    
-- ########################################################################



-- ################################## INSERTION, DELETION, SEARCH & INDEXING #######################################

CREATE TABLE dna_kmer_test (
    dna dna,
    kmer kmer,
    qkmer qkmer
);

COPY dna_kmer_test(dna, kmer, qkmer)
FROM '/path/to/your/sequences.csv'
DELIMITER ','
CSV HEADER;

-- DELETION
    DELETE FROM dna_kmer_test WHERE kmer_sequence = 'CGTACGTA'::kmer;

-- SEARCH without index
    SELECT * FROM dna_kmer_test WHERE kmer_sequence = 'AGCTAGCT'::kmer;

-- INDEX
    CREATE INDEX kmer_index ON dna_kmer_test USING spgist (kmer_sequence);

-- SEARCH with index
    SET enable_seqscan = off;
    SELECT * FROM dna_kmer_test WHERE kmer_sequence = 'AGCTAGCT'::kmer;
    SELECT * FROM dna_kmer_test WHERE kmer_sequence ^@ 'ACG';
    SELECT * FROM dna_kmer_test WHERE 'ANGTA'::qkmer @> kmer_sequence;
    SELECT * FROM dna_kmer_test WHERE 'ACGNN'::qkmer @> kmer_sequence;


-- ########################################################################