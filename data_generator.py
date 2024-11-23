import random
import pandas as pd

def generate_sequence(chars, max_length=32):
    length = random.randint(1, max_length)
    return ''.join(random.choices(chars, k=length))


def generate_dataset(n, chars, max_length=32, max_duplicates=20):
    unique_values = []
    final_values = []

    for _ in range(n // 2): 
        unique_values.append(generate_sequence(chars, max_length))

    for value in unique_values:
        num_duplicates = random.randint(1, max_duplicates)
        final_values.extend([value] * num_duplicates)

    random.shuffle(final_values)

    return final_values[:n]

dna_chars = ['A', 'C', 'G', 'T']
kmer_chars = ['A', 'C', 'G', 'T']
qkmer_chars = ['A', 'C', 'G', 'T', 'R', 'Y', 'K', 'M', 'S', 'W', 'B', 'D', 'H', 'V']

n = 100000
dna = pd.DataFrame(generate_dataset(n, dna_chars, max_length=100), columns = ["dna"])
kmer = pd.DataFrame(generate_dataset(n, kmer_chars), columns = ["kmer"])
qkmer = pd.DataFrame(generate_dataset(n, qkmer_chars), columns = ["qkmer"])
data = pd.concat([dna, kmer, qkmer], axis = 1)
data