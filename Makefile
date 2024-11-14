MODULE_big	= kmer
OBJS = \
	$(WIN32RES) \
	kmer.o \
	kmer_spgist.o

EXTENSION   = kmer
DATA        = kmer--1.0.0.sql
HEADERS_kmer = kmer.h

PG_CONFIG ?= pg_config
PGXS = $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
