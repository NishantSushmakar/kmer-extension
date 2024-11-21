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
    SELECT 'ACGTNS'::qkmer; -- Contains 'N' and 'S', valid in qkmer

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

-- Inner Join: Compute the inner join fo two different generated kmers
-- It should return 6 rows: ACGT, CGTA, GTAC, TACG, ACGT, GTAC
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

-- Inner Join: Compute the inner join fo two different generated kmers
-- It should return 6 rows: ACGT, CGTA, GTAC, TACG, ACGT, GTAC
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


-- Inner Join: Compute the inner join for two different generated kmers
-- It should return 6 rows: ACGT, CGTA, GTAC, TACG, TACGT, GTAC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    INNER JOIN generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) ON a.kmer ^@ b.kmer; 

-- Left Join
-- It should return 5 rows, 2 non null for ACGT and 3 null for the CGTA, GTAC, TAGC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    LEFT JOIN generate_kmers('AGACGTTG'::dna, 4) AS b(kmer) ON a.kmer ^@ b.kmer; 

-- Right Join
-- It should return 6 rows, 2 non null for ACGT and 3 null for the AGAC, GACG, CGTT, GTTG
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
    RIGHT JOIN generate_kmers('AGACGTTG'::dna, 4) AS b(kmer) ON a.kmer ^@ b.kmer; 

-- Implicit join
-- It should return 6 rows: ACGT, CGTA, GTAC, TACG, TACGT, GTAC
    SELECT a.kmer, b.kmer 
    FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer),  
        generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) 
    WHERE a.kmer ^@ b.kmer; 

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

-- Joins
    WITH qkmer_values AS (
        SELECT * FROM (VALUES 
            ('ANGTA'::qkmer),  --  5-mer starting with A, followed by any other nucleotide and then G, T and A
            ('CYGTT'::qkmer),  --  5-mer starting with C, followed by C or T and then G, T and T
            ('TGNNN'::qkmer),  --  5-mer starting with T, G, and then any 3 of all posible nucleotides
            ('ACGTA'::qkmer)   
        ) AS q(qkmer)
    ),
    kmer_values AS (
        SELECT * FROM (VALUES 
            ('AGGTA'::kmer),  -- Matches ANGTA
            ('CCGTT'::kmer),  -- Matches CYGTT
            ('TGGCA'::kmer),  -- Matches TGNNN
            ('ACGTA'::kmer),  -- Matches  ACGTA
            ('TTTAA'::kmer)   -- Does not match any value
        ) AS k(kmer)
    )

    -- Inner Join: It should return the tuples (ANGTA, AGGTA), (CYGTT, CCGTT), (TGNNN, TGGCA), (ACGTA, ACGTA)
    SELECT q.qkmer, k.kmer
    FROM qkmer_values q
    INNER JOIN kmer_values k ON contains(q.qkmer, k.kmer);

    -- Implicit Join: It should return the tuples (ANGTA, AGGTA), (CYGTT, CCGTT), (TGNNN, TGGCA), (ACGTA, ACGTA)
    SELECT q.qkmer, k.kmer
    FROM qkmer_values q, kmer_values k
    WHERE contains(q.qkmer, k.kmer);

    -- Left Join: It should return the tuples (ANGTA, AGGTA), (CYGTT, CCGTT), (TGNNN, TGGCA), (ACGTA, ACGTA)
    SELECT q.qkmer, k.kmer
    FROM qkmer_values q
    LEFT JOIN kmer_values k ON contains(q.qkmer, k.kmer);

    -- Right Join: It should return the tuples (ANGTA, AGGTA), (CYGTT, CCGTT), (TGNNN, TGGCA), (ACGTA, ACGTA), (NULL, TTTAA)
    SELECT q.qkmer, k.kmer
    FROM qkmer_values q
    RIGHT JOIN kmer_values k ON contains(q.qkmer, k.kmer);

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


-- Joins
    WITH qkmer_values AS (
        SELECT * FROM (VALUES 
            ('ANGTA'::qkmer),  --  5-mer starting with A, followed by any other nucleotide and then G, T and A
            ('CYGTT'::qkmer),  --  5-mer starting with C, followed by C or T and then G, T and T
            ('TGNNN'::qkmer),  --  5-mer starting with T, G, and then any 3 of all posible nucleotides
            ('ACGTA'::qkmer)   
        ) AS q(qkmer)
    ),
    kmer_values AS (
        SELECT * FROM (VALUES 
            ('AGGTA'::kmer),  -- Matches ANGTA
            ('CCGTT'::kmer),  -- Matches CYGTT
            ('TGGCA'::kmer),  -- Matches TGNNN
            ('ACGTA'::kmer),  -- Matches  ACGTA
            ('TTTAA'::kmer)   -- Does not match any value
        ) AS k(kmer)
    )

    -- Inner Join: It should return the tuples (ANGTA, AGGTA), (CYGTT, CCGTT), (TGNNN, TGGCA), (ACGTA, ACGTA)
    SELECT q.qkmer, k.kmer
    FROM qkmer_values q
    INNER JOIN kmer_values k ON q.qkmer @> k.kmer;

    -- Implicit Join: It should return the tuples (ANGTA, AGGTA), (CYGTT, CCGTT), (TGNNN, TGGCA), (ACGTA, ACGTA)
    SELECT q.qkmer, k.kmer
    FROM qkmer_values q, kmer_values k
    WHERE q.qkmer @> k.kmer;

    -- Left Join: It should return the tuples (ANGTA, AGGTA), (CYGTT, CCGTT), (TGNNN, TGGCA), (ACGTA, ACGTA)
    SELECT q.qkmer, k.kmer
    FROM qkmer_values q
    LEFT JOIN kmer_values k ON q.qkmer @> k.kmer;

    -- Right Join: It should return the tuples (ANGTA, AGGTA), (CYGTT, CCGTT), (TGNNN, TGGCA), (ACGTA, ACGTA), (NULL, TTTAA)
    SELECT q.qkmer, k.kmer
    FROM qkmer_values q
    RIGHT JOIN kmer_values k ON q.qkmer @> k.kmer;

-- ########################################################################




-- ############################### GROUP BY ###############################

-- COUNT 
-- Return 5
    SELECT COUNT(k.kmer) 
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


INSERT INTO dna_kmer_test (dna_sequence, kmer_sequence, qkmer_sequence) 
VALUES
('ACGTACGT', 'ACGTA', 'TACGT'),
('TGGCACGT', 'ACGTA', 'TAGT'),
('ACGTCT', 'AGTA', 'ANGTA'),
('CGGATACGT', 'ACGTA', 'CGTA'),
('GCTAGCGA', 'GCTA', 'TACG'),
('ATCGTACG', 'ACGT', 'GTAC'),
('AGTCAGTC', 'GCTA', 'AGCGT'),
('TACGATCG', 'TAGC', 'CAGT'),
('GCTAGCCT', 'CTAG', 'TAGT'),
('TGCATGCG', 'GATC', 'GCTA'),
('ATCGACGT', 'ACGT', 'TACG'),
('TCAGTCAG', 'AGTC', 'ATGT'),
('CGTACGTA', 'ACTG', 'CGAT'),
('GATCGTCA', 'GACG', 'TAGC'),
('TACGATCG', 'ACTG', 'GCTA'),
('AGTCGTAC', 'GTAC', 'TACG'),
('ATCGGCTA', 'CTAG', 'GCTA'),
('TGCGATCG', 'ACGT', 'TGCT'),
('CAGTACGT', 'AGTC', 'ACGT'),
('CTAGGCTA', 'AGTC', 'TACG'),
('TACGCGTA', 'GACT', 'GTAC'),
('GTACGCGT', 'AGTC', 'CTAG'),
('CGAATCGT', 'ACTG', 'GCTA'),
('AGTCACGT', 'ACGT', 'AGTG'),
('CGTAGGCT', 'GATC', 'TAGC'),
('TACGTCAG', 'AGCT', 'TGCA'),
('ATCGACAT', 'GTAC', 'TGCAT'),
('GCTAGTAC', 'AGTA', 'ACTG'),
('TCAGCGTA', 'GTAG', 'TACG'),
('ATCGATCG', 'GCTA', 'AGTC'),
('GATGACGT', 'TAGC', 'GCTA'),
('AGTCAGTG', 'ACTG', 'CTAG'),
('CAGCTGAC', 'AGTC', 'TACG'),
('TACGGCTA', 'ACTG', 'GTAC'),
('CGTATGCA', 'GTCG', 'CAGT'),
('AGTCACAT', 'ACTG', 'CTAG'),
('TACGATGC', 'TAGC', 'ACGT'),
('GCGTACAT', 'GTAC', 'TACG'),
('ATGCGACT', 'ACGT', 'TAGC'),
('GCTACTAG', 'GATC', 'ATGC'),
('AGTGCATG', 'ACTG', 'ACGT'),
('TACGTGCA', 'TAGC', 'GACT'),
('TCAGCGTA', 'ACTG', 'AGTC'),
('GATCGCTA', 'GTAC', 'TACG'),
('AGTCGTAG', 'GCTA', 'TGCA'),
('TACGGTAC', 'ACTG', 'CGTA'),
('ATCAGTGC', 'AGTC', 'TACG'),
('GCTGCGAC', 'ACTG', 'GTAC'),
('GATCGTAC', 'GACT', 'ACGT'),
('ACGTAGCA', 'CTAG', 'ATCG'),
('TCAGGCTA', 'GATC', 'ACTG'),
('AGTCACGT', 'ATGC', 'CTAG'),
('CAGTGACG', 'TAGC', 'ACTG'),
('TACGAGTA', 'ACTG', 'AGTC'),
('GTACGCTA', 'ACGT', 'TACG'),
('ATCGCGTA', 'GATC', 'GTAG'),
('CGTACATG', 'ACTG', 'TGCA'),
('TACGCTAG', 'CTAG', 'GTCG'),
('AGTCATGC', 'GATC', 'ACTG'),
('TACGAGTC', 'CTAG', 'GACT'),
('ACGTATGC', 'GATC', 'AGTC'),
('ATCGGTAC', 'GTAC', 'AGCT'),
('CGTACGTA', 'ACTG', 'TGCG'),
('AGTGTACG', 'GACG', 'TACG'),
('CAGTACGT', 'AGTC', 'ATGC'),
('TACGATCG', 'ACTG', 'GTAC'),
('GCTAGGCA', 'ACGT', 'AGTC'),
('GATCGTAC', 'GACT', 'TGAC'),
('ATGCTGAC', 'ACTG', 'CTAG'),
('AGTCAGTC', 'ACGT', 'ACTG'),
('CGTAGTCG', 'GACT', 'TACG'),
('AGCTGACG', 'GTAC', 'TACG'),
('TACGGTAC', 'ACGT', 'TAGC'),
('GTCAGTAC', 'ACTG', 'CGTA'),
('ACGTAGCT', 'GTAC', 'AGTC'),
('TACGACTG', 'TAGC', 'GTAC'),
('GAGTACGT', 'ACTG', 'CTAG'),
('AGTCAGTG', 'CTAG', 'TACG'),
('GCTAGTGC', 'AGTC', 'GTAC'),
('TCAGCGTA', 'ACGT', 'GCTA'),
('ATCGGTAG', 'GTAC', 'TAGC'),
('CAGTGATC', 'ACTG', 'AGTC'),
('GATCGTAC', 'GACT', 'ACGT'),
('ACGGTGAC', 'ACTG', 'GTAC'),
('AGTCGACT', 'AGTC', 'ATGC'),
('GCTAGGAC', 'GATC', 'TACG'),
('TACGCGAT', 'ACTG', 'GTAC'),
('GCTAGTAC', 'ACTG', 'GTAC'),
('ATGTCGTA', 'GACT', 'AGTC'),
('CGTACGAG', 'GTAC', 'TAGC'),
('AGTCGAGT', 'ACTG', 'ACGT'),
('TACGTAGC', 'GACT', 'AGTC'),
('GTACATCG', 'GATC', 'TACG'),
('GCTAGACG', 'ACGT', 'TACG'),
('AGTCATGC', 'ACTG', 'GTAC'),
('CGTAGGAC', 'TACG', 'GACT'),
('TACGGTAC', 'AGTC', 'GACT'),
('GATCAGTC', 'ACTG', 'TACG'),
('ACGGTACG', 'GTAC', 'GACT'),
( 'AGTCGTAC', 'ACGT', 'TAGC');