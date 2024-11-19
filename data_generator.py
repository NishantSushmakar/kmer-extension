import random

# Define possible characters for each sequence type
dna_chars = ['A', 'C', 'G', 'T']
kmer_chars = ['A', 'C', 'G', 'T']
qkmer_chars = ['A', 'C', 'G', 'T', 'R', 'Y', 'K', 'M', 'S', 'W', 'B', 'D', 'H', 'V']

# Function to generate a random sequence
def generate_sequence(chars, max_length):
    length = random.randint(1, max_length)
    return ''.join(random.choices(chars, k=length))

# Generate 1000 rows of SQL values
values = []
dna_length = random.randint(1, 50)
for _ in range(1000):
    dna_sequence = generate_sequence(dna_chars, dna_length)
    kmer_sequence = generate_sequence(kmer_chars, 32)
    qkmer_sequence = generate_sequence(qkmer_chars, 32)
    values.append(f"('{dna_sequence}', '{kmer_sequence}', '{qkmer_sequence}')")

# Print the SQL
print("INSERT INTO dna_kmer_test (dna_sequence, kmer_sequence, qkmer_sequence) VALUES")
print(",\n".join(values) + ";")