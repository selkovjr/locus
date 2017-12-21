/*
 * contrib/locus/locusdata.h
 */
#include "utils/varlena.h"

typedef struct LOCUS
{
  int32 l_len_; /* varlena header (do not touch directly!) */
  int32 start;
  int32 end;
  char  contig[FLEXIBLE_ARRAY_MEMBER];
} LOCUS;

#define LOCUS_SIZE(str) (offsetof(LOCUS, contig) + sizeof(str))

