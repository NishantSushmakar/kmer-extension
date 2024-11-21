MODULE_big	= kmer
OBJS = kmer.o 

EXTENSION   = kmer
DATA        = kmer--1.0.0.sql
HEADERS_kmer = kmer.h

PG_CONFIG ?= pg_config
PGXS = $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
