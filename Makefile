# contrib/locus/Makefile
#

# Override DIFF to ignore trailing whitespace
# (diff in $(CURDIR) should be symlinked to diff-ignore-trailing-whitespace)
override PATH := $(CURDIR):$(PATH)

USE_PGXS = 1
MODULE_big = locus
OBJS = locus.o locus_parse.o strnatcmp.o $(WIN32RES)

EXTENSION = locus
DATA = locus--0.0.1.sql locus--0.0.2.sql
PGFILEDESC = "locus - genomic locus [contig:pos-pos]"

REGRESS = create-ext io accessors comparator functions operators tiling create-table load-table index queries join

EXTRA_CLEAN = y.tab.c y.tab.h

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

# locus_scan is compiled as part of locus_parse
locus_parse.o: locus_scan.c

distprep: locus_parse.c locus_scan.c

maintainer-clean:
	rm -f locus_parse.c locus_scan.c
