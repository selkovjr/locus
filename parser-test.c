#include "locus_data.h"
#include <stdio.h>

int main() {
  char  *str = "chr8:10000-10005";
  // LOCUS *result = palloc(sizeof(LOCUS));
  char mem[40];
  LOCUS *result = (LOCUS *) mem;

  locus_scanner_init(str);

  if (locus_yyparse(result) != 0)
    locus_yyerror(result, "bogus input");

  locus_scanner_finish();

  printf("%s : %d - %d\n", result->contig, result->lower, result->upper);
}
