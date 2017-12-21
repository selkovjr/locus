# contrib/locus/Makefile

MODULE_big = locus
OBJS = locus.o strnatcmp.o $(WIN32RES)

EXTENSION = locus
DATA = locus--1.0.sql
PGFILEDESC = "locus - genomic locus type"

REGRESS = locus

ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
else
subdir = contrib/locus
top_builddir = ../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif

