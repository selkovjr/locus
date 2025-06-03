/*
 * contrib/locus/locus_data.h
 */

typedef struct LOCUS
{
  int    lower;
  int    upper;
  char   contig[15];
  bool   chr;
} LOCUS;

/* in locus_scan.l */
extern int locus_yylex(void);
// extern void locus_yyerror(LOCUS *result, const char *message) pg_attribute_noreturn();
extern void locus_yyerror(LOCUS *result, const char *message);
extern void locus_scanner_init(const char *str);
extern void locus_scanner_finish(void);

/* in locus_parse.y */
extern int locus_yyparse(LOCUS *result);

