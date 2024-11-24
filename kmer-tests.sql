-- ############################# Data Types #############################

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

    -- TEST 1: DNA 

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

    -- TEST 1.1 Defining valid values
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

-- TEST 4.1: Functionality Test: Test if the function works as expected

    SELECT length('ACGTACGT'::dna), length('ACGTACGT'::kmer), length('RYN'::qkmer);

    -- Result
        --  length | length | length 
        -- --------+--------+--------
        --       8 |      8 |      3
        -- (1 row)
    
    -- Execution Plan
        --                                          QUERY PLAN                                      
        -- -------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=12) (actual time=0.001..0.002 rows=1 loops=1)
        --  Planning Time: 0.043 ms
        --  Execution Time: 0.039 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 4.2: Empty sequences: Measure the length of empty sequences
    
    SELECT length(''::dna), length(''::kmer), length(''::qkmer);

    -- Result 
        --  length | length | length 
        -- --------+--------+--------
        --       0 |      0 |      0
        -- (1 row)

    -- Execution
        --                                      QUERY PLAN                                      
        -- -------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=12) (actual time=0.001..0.002 rows=1 loops=1)
        --  Planning Time: 0.046 ms
        --  Execution Time: 0.014 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 4.3: Null sequences: Measure the length of null sequences
    
    SELECT length(NULL::dna), length(NULL::kmer), length(NULL::qkmer);

    -- Result
        --  length | length | length 
        -- --------+--------+--------
        --         |        |       
        -- (1 row)
    
    -- Execution Plan
        --                                          QUERY PLAN                                      
        -- -------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=12) (actual time=0.003..0.004 rows=1 loops=1)
        --  Planning Time: 0.047 ms
        --  Execution Time: 0.022 ms
        -- (3 rows)


-- ########################################################################




-- ############################ generate_kmers ############################

-- TEST 5.1: Empty sequences: Generate kmers with length 0
    
    SELECT * FROM generate_kmers('ACGT'::dna, 0); -- Throw error

    -- Result
        -- ERROR:  Invalid KMER Length

-------------------------------------------------------------------------------------

-- TEST 5.2: Unmatching length: Generate kmers with different lengths

    -- TEST 5.2.1: length less than K: Return an exception

        SELECT * FROM generate_kmers('AC'::dna, 5); 

        -- Result
            -- ERROR:  Invalid KMER Length

-------------------------------------------------------------------------------------

    -- TEST 5.2.2: length greater than k: Return 6 sequences

        SELECT * FROM generate_kmers('ACGTACGT'::dna, 3); 

        -- Result
            --  generate_kmers 
            -- ----------------
            --  acg
            --  cgt
            --  gta
            --  tac
            --  acg
            --  cgt
            -- (6 rows) 

        -- Execution Plan 
            --                                                     QUERY PLAN                                                    
            -- ------------------------------------------------------------------------------------------------------------------
            --  Function Scan on generate_kmers  (cost=0.00..10.00 rows=1000 width=32) (actual time=0.105..0.107 rows=6 loops=1)
            --  Planning Time: 0.042 ms
            --  Execution Time: 0.144 ms
            -- (3 rows)

-------------------------------------------------------------------------------------

    -- TEST 5.2.3: length equal than k: Return the same sequence

        SELECT * FROM generate_kmers('ACGTACGT'::dna, 8); 

        -- Result
            --  generate_kmers 
            -- ----------------
            --  acgtacgt
            -- (1 row)
        
        -- Execution Plan 

            --                                                     QUERY PLAN                                                    
            -- ------------------------------------------------------------------------------------------------------------------
            --  Function Scan on generate_kmers  (cost=0.00..10.00 rows=1000 width=32) (actual time=0.016..0.017 rows=1 loops=1)
            --  Planning Time: 0.048 ms
            --  Execution Time: 0.035 ms
            -- (3 rows)



-- ################################ = Operator ################################

-- TEST 6.1: Functionality Test: Test whether the operator works as expected or not
    
    SELECT 'ACGTACGT'::kmer = 'ACGTACGT'::kmer; -- Return True
    
    -- Result
        --  ?column? 
        -- ----------
        --  t
        -- (1 row)
    
    -- Execution Plan

        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.001..0.001 rows=1 loops=1)
        --  Planning Time: 0.026 ms
        --  Execution Time: 0.011 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 6.2: Null values: Test whether two null values are the same or whether a null value and a non null are the same 
    
    SELECT 
            NULL::kmer = 'ACGTA'::kmer, -- Return NULL 
            NULL::kmer = NULL::kmer, -- Return Null
            ''::kmer = NULL::kmer; -- Return Null

    -- Result
        --  ?column? | ?column? | ?column? 
        -- ----------+----------+----------
        --           |          | 
        -- (1 row)
    
    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=3) (actual time=0.003..0.004 rows=1 loops=1)
        --  Planning Time: 0.060 ms
        --  Execution Time: 0.020 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 6.3: Empty values: Test whether two empty sequences are the same or one empty and one full sequence
    
    SELECT ''::kmer = ''::kmer; -- Return True

    -- Result
        --  ?column? 
        -- ----------
        --  t
        -- (1 row)

    -- Execution Plan
        --                                          QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.001..0.002 rows=1 loops=1)
        --  Planning Time: 0.047 ms
        --  Execution Time: 0.015 ms
        -- (3 rows)

-- TEST 6.4: Empty values: Test whether an empty sequence and one full sequence

    SELECT 'A'::kmer = ''::kmer; -- Return False
    
    -- Result
        --  ?column? 
        -- ----------
        --  f
        -- (1 row)
    
    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.001..0.001 rows=1 loops=1)
        --  Planning Time: 0.026 ms
        --  Execution Time: 0.011 ms
        -- (3 rows)

-- ########################################################################



-- ################################ equals ################################

-- TEST 7.1: Functionality Test: Test whether the function works as expected or not
    
    SELECT equals('ACGTACGT'::kmer, 'ACGTACGT'::kmer); -- Return True

    -- Result
        --  equals 
        -- --------
        --  t
        -- (1 row
    
    -- Execution Plan

        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.002..0.003 rows=1 loops=1)
        --  Planning Time: 0.059 ms
        --  Execution Time: 0.021 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 7.2: Null values: Test whether two null values are the same or whether a null value and a non null are the same 
    
    SELECT 
            equals(NULL::kmer, 'ACGTA'::kmer), -- Return NULL 
            equals(NULL::kmer, NULL::kmer), -- Return Null
            equals(''::kmer, NULL::kmer); -- Return Null
    
    -- Result
        --  equals | equals | equals 
        -- --------+--------+--------
        --         |        | 
        -- (1 row)

    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=3) (actual time=0.003..0.003 rows=1 loops=1)
        --  Planning Time: 0.060 ms
        --  Execution Time: 0.020 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 7.3: Test whether two empty sequences are the same or one empty and one full sequence
    
    SELECT equals(''::kmer, ''::kmer); -- Return True
    
    -- Result
        --  equals 
        -- --------
        --  t
        -- (1 row)

    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.001..0.002 rows=1 loops=1)
        --  Planning Time: 0.041 ms
        --  Execution Time: 0.017 ms
        -- (3 rows)

-------------------------------------------------------------------------------------
    
    -- TEST 7.4: Test whether one empty and one full sequence are the same

        SELECT equals('A'::kmer, ''::kmer); -- Return False

    -- Result
        --  equals 
        -- --------
        --  f
        -- (1 row)

    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.001..0.001 rows=1 loops=1)
        --  Planning Time: 0.033 ms
        --  Execution Time: 0.013 ms
        -- (3 rows)

-- ########################################################################



-- ############################# starts_with ##############################

-- TEST 8.1: Test whether the function works as expected or not
    
    SELECT starts_with('ACG'::kmer, 'ACGTACGT'::kmer); -- Return True

    -- Result
        --  starts_with 
        -- -------------
        --  t
        -- (1 row)
    
    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.003..0.003 rows=1 loops=1)
        --  Planning Time: 0.035 ms
        --  Execution Time: 0.021 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 8.2: Null values

    SELECT starts_with(NULL::kmer, 'ACGT'::kmer), -- return null
            starts_with('ACGT'::kmer, NULL::kmer); -- return null
    
    -- Result
        --  starts_with | starts_with 
        -- -------------+-------------
        --              | 
        -- (1 row)
    
    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=2) (actual time=0.002..0.003 rows=1 loops=1)
        --  Planning Time: 0.047 ms
        --  Execution Time: 0.018 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 8.3: Empty values
    
    SELECT starts_with(''::kmer, 'AGT'::kmer); -- Return True
    
    -- Result
        --  starts_with 
        -- -------------
        --  t
        -- (1 row)
    
    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.002..0.003 rows=1 loops=1)
        --  Planning Time: 0.066 ms
        --  Execution Time: 0.020 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 8.4: Search substring with length greater than the initial sequence
    
    SELECT starts_with('ACGTACGT'::kmer, 'AC'::kmer); -- Return false

    -- Result
        --  starts_with 
        -- -------------
        --  f
        -- (1 row)

    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.001..0.001 rows=1 loops=1)
        --  Planning Time: 0.033 ms
        --  Execution Time: 0.009 ms

-------------------------------------------------------------------------------------

-- TEST 8.5: Data type mismatch.

    SELECT starts_with('RCGT'::qkmer, 'ACGT'::dna); -- Error: Data type mismatch

    -- Result
        -- ERROR:  function starts_with(qkmer, dna) does not exist
        -- LINE 1: SELECT starts_with('RCGT'::qkmer, 'ACGT'::dna);
        --                ^
        -- HINT:  No function matches the given name and argument types. You might need to add explicit type casts.

-- ########################################################################



-- ############################## ^@ Operator #############################

-- TEST 9.1: Test whether the operator works as expected or not

    SELECT 'ACGTACGT'::kmer  ^@ 'ACG'::kmer ; -- Return True

    -- Result
        --  ?column? 
        -- ----------
        --  t
        -- (1 row)

    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.001..0.002 rows=1 loops=1)
        --  Planning Time: 0.039 ms
        --  Execution Time: 0.015 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 9.2: Test wether the operator works as expected

    SELECT 'ACGT'::kmer ^@ 'AC'; -- Return True
    
    -- Result
        --  ?column? 
        -- ----------
        --  t
        -- (1 row)
    
    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.002..0.002 rows=1 loops=1)
        --  Planning Time: 0.109 ms
        --  Execution Time: 0.021 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 9.3: Null values

    SELECT NULL::kmer ^@ 'ACGT'::kmer, -- return null
            'ACGT'::kmer ^@ NULL::kmer; -- return null
    
    -- Result
        --  ?column? | ?column? 
        -- ----------+----------
        --           | 
        -- (1 row)
    
    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=2) (actual time=0.002..0.003 rows=1 loops=1)
        --  Planning Time: 0.023 ms
        --  Execution Time: 0.016 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 9.4: Empty values
    
    SELECT ''::kmer ^@ 'AGT'::kmer; -- Return False
    
    -- Result
        --  ?column? 
        -- ----------
        --  f
        -- (1 row)
    
    -- Execution Plan
        --                                         QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.001..0.002 rows=1 loops=1)
        --  Planning Time: 0.043 ms
        --  Execution Time: 0.017 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 9.5: Search substring with length greater than the initial sequence
    SELECT 'AC'::kmer ^@ 'ACGTACGT'::kmer; -- Return false
    
    -- Result
        --  ?column? 
        -- ----------
        --  f
        -- (1 row)
    
    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.001..0.002 rows=1 loops=1)
        --  Planning Time: 0.129 ms
        --  Execution Time: 0.019 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 9.6: Data type mismatch.
    
    SELECT 'RCGT'::qkmer ^@ 'ACGT'::dna; -- Error: Data type mismatch
    
    -- Result
        -- ERROR:  operator does not exist: qkmer ^@ dna
        -- LINE 1: SELECT 'RCGT'::qkmer ^@ 'ACGT'::dna;
        --                              ^
        -- HINT:  No operator matches the given name and argument types. You might need to add explicit type casts.

-- ########################################################################



-- ############################### contains ###############################

-- TEST 10.1: Test whether the function works as expected or not
    SELECT contains('ACNTANGT'::qkmer, 'ACGTACGT'::kmer); -- Return True

    -- Result
        --  contains 
        -- ----------
        --  t
        -- (1 row)
    
    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.001..0.002 rows=1 loops=1)
        --  Planning Time: 0.040 ms
        --  Execution Time: 0.018 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 10.2: Null values
    
    SELECT contains(NULL::qkmer, 'ACGT'::kmer), -- return null
            contains('ACGT'::qkmer, NULL::kmer); -- return null
    
    -- Result
        --  contains | contains 
        -- ----------+----------
        --           | 
        -- (1 row)
    
    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=2) (actual time=0.002..0.006 rows=1 loops=1)
        --  Planning Time: 0.057 ms
        --  Execution Time: 0.023 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 10.3: Empty values
    
    SELECT contains(''::qkmer, 'AGT'::kmer); -- Return True
    
    -- Result
        --  contains 
        -- ----------
        --  f
        -- (1 row)
    
    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.001..0.002 rows=1 loops=1)
        --  Planning Time: 0.038 ms
        --  Execution Time: 0.015 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 10.4: Search substring with length greater than the initial sequence
    
    SELECT contains('ACGTACGT'::qkmer, 'AC'::kmer); -- Return false
    
    -- Result
        --  contains 
        -- ----------
        --  f
        -- (1 row)
    
    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.001..0.002 rows=1 loops=1)
        --  Planning Time: 0.062 ms
        --  Execution Time: 0.016 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 10.5: Data type mismatch.

    SELECT contains('RCGT'::qkmer, 'ACGT'::dna); -- Error: Data type mismatch

    -- ERROR:  function contains(qkmer, dna) does not exist
    -- LINE 1: SELECT contains('RCGT'::qkmer, 'ACGT'::dna);
    --                ^
    -- HINT:  No function matches the given name and argument types. You might need to add explicit type casts.

-- ########################################################################



-- ############################## @> Operator #############################

-- TEST 11.1: Test whether the operator works as expected or not
    
    SELECT 'ACG'::qkmer @> 'ACGTACGT'::kmer; -- Return False
    
    -- Result
        --  ?column? 
        -- ----------
        --  f
        -- (1 row)
    
    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.001..0.002 rows=1 loops=1)
        --  Planning Time: 0.061 ms
        --  Execution Time: 0.017 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 11.2: Test wether the operator works as expected
    
    SELECT 'ACGT'::qkmer @> 'AC'; -- Return False
    
    -- Result
        --  ?column? 
        -- ----------
        --  f
        -- (1 row)

    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.001..0.002 rows=1 loops=1)
        --  Planning Time: 0.085 ms
        --  Execution Time: 0.018 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 11.3: Null values

    SELECT NULL::qkmer @> 'ACGT'::kmer, -- return null
            'ACGT'::qkmer @> NULL::kmer; -- return null

    -- Result
        --  ?column? | ?column? 
        -- ----------+----------
        --           | 
        -- (1 row)
    
    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=2) (actual time=0.002..0.003 rows=1 loops=1)
        --  Planning Time: 0.069 ms
        --  Execution Time: 0.037 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 11.4: Empty values

    SELECT ''::qkmer @> 'AGT'::kmer; -- Return False

    -- Result
        --  ?column? 
        -- ----------
        --  f
        -- (1 row)

    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.001..0.002 rows=1 loops=1)
        --  Planning Time: 0.126 ms
        --  Execution Time: 0.019 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 11.5: Search substring with length greater than the initial sequence
    
    SELECT 'ACGTACGT'::qkmer @> 'AC'::kmer; -- Return false
    
    -- Result
        --  ?column? 
        -- ----------
        --  f
        -- (1 row)
    
    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.002..0.002 rows=1 loops=1)
        --  Planning Time: 0.082 ms
        --  Execution Time: 0.019 ms
        -- (3 rows)

-------------------------------------------------------------------------------------

-- TEST 11.6: Data type mismatch.
    
    SELECT 'RCGT'::qkmer @> 'ACGT'::kmer; -- Error: Data type mismatch
    
    -- Result
        --  ?column? 
        -- ----------
        --  t
        -- (1 row)
    
    -- Execution Plan
        --                                      QUERY PLAN                                     
        -- ------------------------------------------------------------------------------------
        --  Result  (cost=0.00..0.01 rows=1 width=1) (actual time=0.001..0.002 rows=1 loops=1)
        --  Planning Time: 0.051 ms
        --  Execution Time: 0.018 ms
        -- (3 rows)

-- ########################################################################



-- ############################### Count ###############################

-- TEST 12.1: COUNT 

    SELECT COUNT(k.kmer) 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS k(kmer); -- Return 5
    
    -- Result
        --  count 
        -- -------
        --      5
        -- (1 row)

    -- Execution Plan
    --                                                             QUERY PLAN                                                        
    -- --------------------------------------------------------------------------------------------------------------------------
    --  Aggregate  (cost=12.50..12.51 rows=1 width=8) (actual time=0.020..0.020 rows=1 loops=1)
    --    ->  Function Scan on generate_kmers k  (cost=0.00..10.00 rows=1000 width=32) (actual time=0.012..0.013 rows=5 loops=1)
    --  Planning Time: 0.063 ms
    --  Execution Time: 0.092 ms
    -- (4 rows)

-- ########################################################################



-- ############################### GROUP BY ###############################

-- TEST 13.1: GROUP BY Using column name and number in the clause

    SELECT k.kmer, COUNT(*) as kmer_count 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS k(kmer) 
    GROUP BY 1; -- Return 5 rows with 1 in each count, but for ACGT, which should be 2
    
    -- Result
        --  kmer | kmer_count 
        -- ------+------------
        --  tacg |          1
        --  acgt |          2
        --  cgta |          1
        --  gtac |          1
        -- (4 rows)

    -- Execution Plan
        --                                                         QUERY PLAN                                                        
        -- --------------------------------------------------------------------------------------------------------------------------
        --  HashAggregate  (cost=15.00..17.00 rows=200 width=40) (actual time=0.026..0.028 rows=4 loops=1)
        --    Group Key: kmer
        --    Batches: 1  Memory Usage: 40kB
        --    ->  Function Scan on generate_kmers k  (cost=0.00..10.00 rows=1000 width=32) (actual time=0.014..0.014 rows=5 loops=1)
        --  Planning Time: 0.102 ms
        --  Execution Time: 0.097 ms
        -- (6 rows)

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