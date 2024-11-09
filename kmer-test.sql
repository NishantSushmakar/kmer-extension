-- ################################## INSERTION, DELETION, SEARCH & INDEXING #######################################

CREATE TABLE dna_kmer_test (
    id SERIAL PRIMARY KEY,
    dna_sequence dna,
    kmer_sequence kmer,
    qkmer_sequence qkmer
);

-- INSERTION
    INSERT INTO dna_kmer_test (dna_sequence, kmer_sequence, qkmer_sequence)
    VALUES
        ('AGCTAGCTAGCTAGCT', 'AGCTAGCT', 'AGCTAGCT'), 
        ('CGTACGTACGTA', 'CGTACGTA', 'CGTACGTA'),      
        ('TTTTTTTTTTTTTTTT', 'TTTTTTTT', 'TTTTTTTT'), 
        ('AGTAGC', 'AGTAGC', 'AGTAGC');                

-- INSERTION with wrong values
    INSERT INTO dna_kmer_test (dna_sequence, kmer_sequence, qkmer_sequence)
    VALUES 
        ('AGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCT', 'AGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGC', 'AGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGC'),  -- Too long
        ('GATTACA', 'GATTACAX', 'GATTACAX');  -- Invalid character in kmer and qkmer

-- DELETION
    DELETE FROM dna_kmer_test WHERE dna_sequence = 'CGTACGTACGTA';

-- SEARCH without index
    SELECT * FROM dna_kmer_test WHERE kmer_sequence = 'AGCTAGCT';

-- INDEX
    CREATE INDEX kmer_index ON dna_kmer_test USING spgist (kmer_sequence);

-- SEARCH with index
    SELECT * FROM dna_kmer_test WHERE kmer_sequence = 'AGCTAGCT';

-- ########################################################################




-- ############################# Data Types #############################

-- DNA 
-- Valid values
    SELECT 'AAAACCCCGGGGTTTT'::dna;   
    SELECT 'ACGTTGCA'::dna;           
-- Invalid values
    SELECT 'ACGTN'::dna; -- Contains invalid character 'N'

-- KMER 
-- Valid values
    SELECT 'AAAACCCCGGGGTTTTAAAACCCCGGGGTTTT'::kmer; -- Exactly 32 nucleotides
    SELECT 'GATTACA'::kmer;                      
-- Invalid values
    SELECT 'AAAAAAAACCCCCCCCGGGGGGGGTTTTTTTTT'::kmer; -- Exceeds 32 nucleotides
    SELECT 'AGTCN'::kmer; -- Contains invalid character 'N'

-- QKMER
-- Valid values
    SELECT 'ACGT'::qkmer;                        
    SELECT 'AAAAAAAACCCCCCCCGGGGGGGGTTTTTTTT'::qkmer; -- Exactly 32 nucleotides
    SELECT 'ACGTNX'::qkmer; -- Contains 'N' and 'X', valid in qkmer

-- Invalid values
    SELECT 'AAAAAAAACCCCCCCCGGGGGGGGTTTTTTTTT'::qkmer; -- Exceeds 32 nucleotides
    SELECT 'ACGT123'::qkmer;                           -- Contains numbers

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

-- Cartesian Product: Compute the cartesian product between two generated kmers
-- It should return 25 rows 
    SELECT 
            a.kmer, 
            b.kmer 
    FROM 
        generate_kmers('ACGTACGT'::dna, 4) AS a(kmer), 
        generate_kmers('GTACGTAC'::dna, 4) AS b(kmer); 

-- Inner Join: Compute the inner join fo two different generated kmers
-- It should return 6 rows: ACGT, CGTA, GTAC, TACG, TACGT, GTAC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    INNER JOIN generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) ON a.kmer = b.kmer; 

-- Left Join
-- It should return 5 rows, 2 non null for ACGT and 3 null for the CGTA, GTAC, TAGC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    LEFT JOIN generate_kmers('AGACGTTG'::dna, 4) AS b(kmer) ON a.kmer = b.kmer; 

-- Right Join
-- It should return 6 rows, 2 non null for ACGT and 3 null for the AGAC, GACG, CGTT, GTTG
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    RIGHT JOIN generate_kmers('AGACGTTG'::dna, 4) AS b(kmer) ON a.kmer = b.kmer; 

-- Implicit join
-- It should return 6 rows: ACGT, CGTA, GTAC, TACG, TACGT, GTAC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer),  
        generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) 
    WHERE a.kmer = b.kmer; 

-- ########################################################################




-- ################################ equals ################################
-- Functionality Test: Test whether the funciton works as expected or not
    SELECT equals('ACGTACGT'::kmer, 'ACGTACGT'::kmer), -- Return True

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

-- Inner Join: Compute the inner join fo two different generated kmers
-- It should return 6 rows: ACGT, CGTA, GTAC, TACG, TACGT, GTAC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    INNER JOIN generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) ON equals(a.kmer, b.kmer); 

-- Left Join
-- It should return 5 rows, 2 non null for ACGT and 3 null for the CGTA, GTAC, TAGC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    LEFT JOIN generate_kmers('AGACGTTG'::dna, 4) AS b(kmer) ON equals(a.kmer, b.kmer); 

-- Right Join
-- It should return 6 rows, 2 non null for ACGT and 4 null for the AGAC, GACG, CGTT, GTTG
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    RIGHT JOIN generate_kmers('AGACGTTG'::dna, 4) AS b(kmer) ON equals(a.kmer, b.kmer); 

-- Implicit join
-- It should return 6 rows: ACGT, CGTA, GTAC, TACG, TACGT, GTAC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer),  
        generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) 
    WHERE equals(a.kmer, b.kmer); 

-- ########################################################################




-- ############################# starts_with ##############################

-- Functionality Test: Test whether the funciton works as expected or not
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

-- Inner Join: Compute the inner join fo two different generated kmers
-- It should return 6 rows: ACGT, CGTA, GTAC, TACG, TACGT, GTAC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    INNER JOIN generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) ON starts_with(a.kmer, b.kmer); 

-- Left Join
-- It should return 5 rows, 2 non null for ACGT and 3 null for the CGTA, GTAC, TAGC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    LEFT JOIN generate_kmers('AGACGTTG'::dna, 4) AS b(kmer) ON starts_with(a.kmer, b.kmer); 

-- Right Join
-- It should return 6 rows, 2 non null for ACGT and 3 null for the AGAC, GACG, CGTT, GTTG
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    RIGHT JOIN generate_kmers('AGACGTTG'::dna, 4) AS b(kmer) ON starts_with(a.kmer, b.kmer); 

-- Implicit join
-- It should return 6 rows: ACGT, CGTA, GTAC, TACG, TACGT, GTAC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer),  
        generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) 
    WHERE starts_with(a.kmer, b.kmer); 

-- ########################################################################




-- ############################## ˆ@ Operator #############################

-- Functionality Test: Test whether the operator works as expected or not
    SELECT 'ACG'::kmer  ˆ@ 'ACGTACGT'::kmer; -- Return True

-- ˆ@ Operator Functionality: Test wether the operator works as expected
    SELECT 'ACGT'::kmer ˆ@ 'AC'; -- Return True


-- Null values
    SELECT NULL::kmer ˆ@ 'ACGT'::kmer, -- return null
            'ACGT'::kmer ˆ@ NULL::kmer; -- return null

-- Empty values
    SELECT ''::kmer ˆ@ 'AGT'::kmer; -- Return True

-- Search substring with length greater than the initial sequence
    SELECT 'ACGTACGT'::kmer ˆ@ 'AC'::kmer; -- Return false

-- Data type mismatch.
    SELECT 'RCGT'::qkmer ˆ@ 'ACGT'::dna; -- Error: Data type mismatch
    SELECT 'ACGT'::qkmer ˆ@ 'ACGT'::dna; -- Error: Data type mismatch


-- Inner Join: Compute the inner join fo two different generated kmers
-- It should return 6 rows: ACGT, CGTA, GTAC, TACG, TACGT, GTAC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    INNER JOIN generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) ON a.kmer ˆ@ b.kmer; 

-- Left Join
-- It should return 5 rows, 2 non null for ACGT and 3 null for the CGTA, GTAC, TAGC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    LEFT JOIN generate_kmers('AGACGTTG'::dna, 4) AS b(kmer) ON a.kmer ˆ@ b.kmer; 

-- Right Join
-- It should return 6 rows, 2 non null for ACGT and 3 null for the AGAC, GACG, CGTT, GTTG
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    RIGHT JOIN generate_kmers('AGACGTTG'::dna, 4) AS b(kmer) ON a.kmer ˆ@ b.kmer; 

-- Implicit join
-- It should return 6 rows: ACGT, CGTA, GTAC, TACG, TACGT, GTAC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer),  
        generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) 
    WHERE a.kmer ˆ@ b.kmer; 

-- ########################################################################




-- ############################### contains ###############################

-- Functionality Test: Test whether the funciton works as expected or not
    SELECT contains('ACG'::kmer, 'ACGTACGT'::kmer); -- Return True

-- Null values
    SELECT contains(NULL::kmer, 'ACGT'::kmer), -- return null
            contains('ACGT'::kmer, NULL::kmer); -- return null

-- Empty values
    SELECT contains(''::kmer, 'AGT'::kmer); -- Return True

-- Search substring with length greater than the initial sequence
    SELECT starts_with('ACGTACGT'::kmer, 'AC'::kmer); -- Return false

-- Data type mismatch.
    SELECT contains('RCGT'::qkmer, 'ACGT'::dna); -- Error: Data type mismatch
    SELECT contains('ACGT'::qkmer, 'ACGT'::dna); -- Error: Data type mismatch

-- Inner Join: Compute the inner join fo two different generated kmers
-- It should return 6 rows: ACGT, CGTA, GTAC, TACG, TACGT, GTAC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    INNER JOIN generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) ON contains(a.kmer, b.kmer); 

-- Left Join
-- It should return 5 rows, 2 non null for ACGT and 3 null for the CGTA, GTAC, TAGC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    LEFT JOIN generate_kmers('AGACGTTG'::dna, 4) AS b(kmer) ON contains(a.kmer, b.kmer); 

-- Right Join
-- It should return 6 rows, 2 non null for ACGT and 3 null for the AGAC, GACG, CGTT, GTTG
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    RIGHT JOIN generate_kmers('AGACGTTG'::dna, 4) AS b(kmer) ON contains(a.kmer, b.kmer); 

-- Implicit join
-- It should return 6 rows: ACGT, CGTA, GTAC, TACG, TACGT, GTAC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer),  
        generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) 
    WHERE contains(a.kmer, b.kmer); 

-- ########################################################################




-- ############################## @> Operator #############################

-- Functionality Test: Test whether the operator works as expected or not
    SELECT 'ACG'::kmer @> 'ACGTACGT'::kmer; -- Return True

-- @> Operator Functionality: Test wether the operator works as expected
    SELECT 'ACGT'::kmer @> 'AC'; -- Return True

-- Null values
    SELECT NULL::kmer @> 'ACGT'::kmer, -- return null
            'ACGT'::kmer @> NULL::kmer; -- return null

-- Empty values
    SELECT ''::kmer @> 'AGT'::kmer; -- Return True

-- Search substring with length greater than the initial sequence
    SELECT 'ACGTACGT'::kmer @> 'AC'::kmer; -- Return false

-- Data type mismatch.
    SELECT 'RCGT'::qkmer @> 'ACGT'::dna; -- Error: Data type mismatch
    SELECT 'ACGT'::qkmer @> 'ACGT'::dna; -- Error: Data type mismatch


-- Inner Join: Compute the inner join fo two different generated kmers
-- It should return 6 rows: ACGT, CGTA, GTAC, TACG, TACGT, GTAC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    INNER JOIN generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) ON a.kmer @> b.kmer; 

-- Left Join
-- It should return 5 rows, 2 non null for ACGT and 3 null for the CGTA, GTAC, TAGC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    LEFT JOIN generate_kmers('AGACGTTG'::dna, 4) AS b(kmer) ON a.kmer @> b.kmer; 

-- Right Join
-- It should return 6 rows, 2 non null for ACGT and 3 null for the AGAC, GACG, CGTT, GTTG
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    RIGHT JOIN generate_kmers('AGACGTTG'::dna, 4) AS b(kmer) ON a.kmer @> b.kmer; 

-- Implicit join
-- It should return 6 rows: ACGT, CGTA, GTAC, TACG, TACGT, GTAC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer),  
        generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) 
    WHERE a.kmer @> b.kmer; 

-- ########################################################################




-- ############################### GROUP BY ###############################

-- COUNT 
-- Return 5
    SELECT COUNT(k.kmer) 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS k(kmer); 

-- COUNT DISTINCT -- ##
    SELECT COUNT(DISTINCT k.kmer) 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS k(kmer);

-- GROUP BY Using column name and number in the clause
-- Return 5 rows with 1 in each count, but for ACGT, which should be 2

    SELECT k.kmer, COUNT(*) as kmer_count 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS k(kmer) 
    GROUP BY 1;

    SELECT k.kmer, COUNT(*) as kmer_count 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS k(kmer) 
    GROUP BY k.kmer;

-- ########################################################################