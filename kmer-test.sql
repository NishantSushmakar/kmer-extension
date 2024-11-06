-- Tests for length function
--------------------------------
-- Empty sequences
SELECT length(''::dna), length(''::kmer), length(''::qkmer);

-- Null sequences
SELECT length(NULL::dna), length(NULL::kmer), length(NULL::qkmer);

-- Sequences with unsupported characters (should fail or throw an error if invalid)
SELECT length('ACGT%'::dna), length('ACGT%'::kmer), length('ACGT%'::qkmer);


-- Tests for generate_kmers function
------------------------------------
-- Unsupported characters (should fail or throw an error)
SELECT * FROM generate_kmers('ACGTX'::dna, 3);

-- For 0 characters (should return empty or error)
SELECT * FROM generate_kmers('ACGT'::dna, 0);

-- For unmatching length of the sequence and length of final kmers (less and more)
SELECT * FROM generate_kmers('AC'::dna, 5); -- length less than k
SELECT * FROM generate_kmers('ACGTACGT'::dna, 3); -- valid length greater than k
SELECT * FROM generate_kmers('ACGTACGT'::dna, 8); -- valid length equal than k

-- Cartesian Product 
SELECT a.kmer, b.kmer 
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer), generate_kmers('GTACGTAC'::dna, 4) AS b(kmer);

-- Alias for a different data type (Should throw an error)
SELECT k.kmer FROM generate_kmers('ACGTACGT'::kmer, 4) AS k(dna);

-- Inner/Left/Right Join
SELECT a.kmer, b.kmer 
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
INNER JOIN generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) ON a.kmer = b.kmer;

SELECT a.kmer, b.kmer 
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
LEFT JOIN generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) ON a.kmer = b.kmer;

SELECT a.kmer, b.kmer 
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
RIGHT JOIN generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) ON a.kmer = b.kmer;


-- Implicit join
SELECT a.kmer, b.kmer 
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer),  generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) 
WHERE a.kmer = b.kmer;


-- Tests for equals function
--------------------------------
-- Different data types (should fail if types don’t match)
SELECT equals('ACGTA'::dna, 'ACGTA'::kmer);

-- Using = and != 
SELECT 'ACGTA'::kmer = 'ACGTA'::kmer, 'ACGTA'::kmer != 'CGTAC'::kmer;

-- Null values
SELECT equals(NULL::kmer, 'ACGTA'::kmer), equals('ACGTA'::kmer, NULL::kmer);

-- Empty values
SELECT equals(''::kmer, ''::kmer);

-- Inner/Left/Right Join
SELECT a.kmer, b.kmer 
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
INNER JOIN generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) ON equals(a.kmer, b.kmer);

SELECT a.kmer, b.kmer 
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
LEFT JOIN generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) ON equals(a.kmer, b.kmer);

SELECT a.kmer, b.kmer 
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
RIGHT JOIN generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) ON equals(a.kmer, b.kmer);

-- Implicit join
SELECT a.kmer, b.kmer
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer), generate_kmers('GTACGTAC'::dna, 4) AS b(kmer)
WHERE equals(a.kmer, b.kmer);


-- Tests for starts_with function
------------------------------------
-- Inner/Left/Right Join
SELECT a.kmer, b.kmer 
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
INNER JOIN generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) ON starts_with(a.kmer, b.kmer);

SELECT a.kmer, b.kmer 
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
LEFT JOIN generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) ON starts_with(a.kmer, b.kmer);

SELECT a.kmer, b.kmer 
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
RIGHT JOIN generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) ON starts_with(a.kmer, b.kmer);

-- Implicit join
SELECT a.kmer, b.kmer
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer), generate_kmers('GTACGTAC'::dna, 4) AS b(kmer)
WHERE starts_with(a.kmer, b.kmer);

SELECT a.kmer, b.kmer
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer), generate_kmers('GTACGTAC'::dna, 4) AS b(kmer)
WHERE starts_with(b.kmer, a.kmer);

-- Null values
SELECT starts_with(NULL::kmer, 'ACGT'::kmer), starts_with('ACGT'::kmer, NULL::kmer);

-- Empty values
SELECT starts_with(''::kmer, ''::kmer);

-- Searched substring has length greater than the initial sequence
SELECT starts_with('AC'::kmer, 'ACGTACGT'::kmer);

-- Search for unsupported characters (should fail or throw an error)
SELECT starts_with('ACGTX'::kmer, 'ACGT'::kmer);

-- Works with ˆ@ and NOT ˆ@
SELECT 'ACGT'::kmer ˆ@ 'AC', 'ACGT'::kmer NOT ˆ@ 'TG';


-- Tests for contains function
--------------------------------
-- Inner/Left/Right Join
SELECT a.kmer, b.kmer 
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
INNER JOIN generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) ON contains(a.kmer, b.kmer);

SELECT a.kmer, b.kmer 
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
LEFT JOIN generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) ON contains(a.kmer, b.kmer);

SELECT a.kmer, b.kmer 
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer)
RIGHT JOIN generate_kmers('GTACGTAC'::dna, 4) AS b(kmer) ON contains(a.kmer, b.kmer);

-- Implicit join
SELECT * 
FROM generate_kmers('ACGTACGT'::dna, 4), generate_kmers('GTACGTAC'::dna, 4)
WHERE contains('ANGTA'::qkmer, 'GATTA'::kmer);

-- Null values
SELECT contains(NULL::qkmer, 'ACGT'::kmer), contains('ACGT'::qkmer, NULL::kmer);

-- Empty values
SELECT contains(''::qkmer, ''::kmer);

-- Searched substring has length greater than the initial sequence
SELECT contains('AC'::qkmer, 'ACGTACGT'::kmer);

-- Search for unsupported characters (should fail or throw an error)
SELECT contains('ACGTX'::qkmer, 'ACGT'::kmer);

-- Works with @> and NOT @>
SELECT 'ANGTA'::qkmer @> 'GATTA'::kmer, 'ANGTA'::qkmer NOT @> 'TGCTA'::kmer;


-- Tests for GROUP BY on k-mers
--------------------------------
-- COUNT 
SELECT COUNT(k.kmer) 
FROM generate_kmers('ACGTACGT'::dna, 4) AS k(kmer);

-- COUNT DISTINCT
SELECT COUNT(DISTINCT k.kmer) 
FROM generate_kmers('ACGTACGT'::dna, 4) AS k(kmer);

-- WINDOW FUNCTIONS
SELECT a.kmer, COUNT(b.kmer) OVER (PARTITION BY a.kmer) AS kmer_count
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer), generate_kmers('GTACGTAC'::dna, 4) AS b(kmer)
GROUP BY a.kmer;

-- Column name and number
SELECT k.kmer, COUNT(*) as kmer_count 
FROM generate_kmers('ACGTACGT'::dna, 4) AS k(kmer) 
GROUP BY 1;

SELECT k.kmer, COUNT(*) as kmer_count 
FROM generate_kmers('ACGTACGT'::dna, 4) AS k(kmer) 
GROUP BY k.kmer;

-- Commutativity of the grouping
SELECT a.kmer, b.kmer, COUNT(*) 
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer), generate_kmers('ACGTACGT'::dna, 4) AS b(kmer) 
GROUP BY a.kmer, b.kmer ;

SELECT a.kmer, b.kmer, COUNT(*) 
FROM generate_kmers('ACGTACGT'::dna, 4) AS a(kmer), generate_kmers('ACGTACGT'::dna, 4) AS b(kmer) 
GROUP BY b.kmer, a.kmer ;

