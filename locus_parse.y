%{
/* contrib/locus/locus_parse.y */

#include "postgres.h"

#include <stdlib.h>  /* for size_t */
#include <errno.h>   /* for strtol() */
#include <limits.h>  /* for INT_MAX */


#include "fmgr.h"
#include "utils/builtins.h"

#include "locus_data.h"

/*
 * Bison doesn't allocate anything that needs to live across parser calls,
 * so we can easily have it use palloc instead of malloc.  This prevents
 * memory leaks if we error out during parsing.  Note this only works with
 * bison >= 2.0.  However, in bison 1.875 the default is to use alloca()
 * if possible, so there's not really much problem anyhow, at least if
 * you're building with gcc.
 */
#define YYMALLOC palloc
#define YYFREE   pfree
/*
#define LOCUS_YYDEBUG 1
int locus_yydebug = 1;
*/

extern int locus_yylex(void);

extern int  locus_yyparse(LOCUS *result);
extern void locus_yyerror(LOCUS *result, const char *message);

void remove_commas(char *);
%}

/* BISON Declarations */
%parse-param {LOCUS *result}
%expect 0
%define api.prefix {locus_yy}

%union {
  int32 val;
  char* text;
}


%token <text> POSITION
%token <text> POSITION_WITH_COMMAS
%token <text> DASH
%token <text> COLON
%token <text> CONTIG
%token <text> CONTIG_LONG
%token <text> CHR_CONTIG
%type  <val> boundary
%token <text> END_OF_INPUT
%start input

/* Grammar follows */
%%

input: range END_OF_INPUT {
    if ( result->lower > result->upper ) {
      ereport(ERROR,
          (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
           errmsg("swapped boundaries: %d is greater than %d",
              result->lower, result->upper)));

      YYERROR;
    }
    else {
      YYACCEPT;
    }
  }

range:
  CONTIG_LONG
  {
    ereport(ERROR,
        (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
         errmsg("Conting name can't be longer than 15 characters")));

    YYERROR;
  }

  | CHR_CONTIG COLON boundary DASH boundary
  {
    strcpy(result->contig, $1 + 3);
    result->chr = true;
    result->lower = $3;
    result->upper = $5;
  }

  | CONTIG COLON boundary DASH boundary
  {
    strcpy(result->contig, $1);
    result->chr = false;
    result->lower = $3;
    result->upper = $5;
  }

  | CHR_CONTIG COLON boundary DASH
  {
    strcpy(result->contig, $1 + 3);
    result->chr = true;
    result->lower = $3;
    result->upper = INT_MAX;
  }

  | CONTIG COLON boundary DASH
  {
    strcpy(result->contig, $1);
    result->chr = false;
    result->lower = $3;
    result->upper = INT_MAX;
  }

  | CHR_CONTIG COLON DASH boundary
  {
    strcpy(result->contig, $1 + 3);
    result->chr = true;
    result->lower = 0;
    result->upper = $4;
  }

  | CONTIG COLON DASH boundary
  {
    strcpy(result->contig, $1);
    result->chr = false;
    result->lower = 0;
    result->upper = $4;
  }

  | CHR_CONTIG COLON boundary
  {
    strcpy(result->contig, $1 + 3);
    result->chr = true;
    result->lower = $3;
    result->upper = $3;
  }

  | CONTIG COLON boundary
  {
    strcpy(result->contig, $1);
    result->chr = false;
    result->lower = $3;
    result->upper = $3;
  }

  | CHR_CONTIG
  {
    strcpy(result->contig, $1 + 3);
    result->chr = true;
    result->lower = 0;
    result->upper = INT_MAX;
  }

  | CONTIG
  {
    strcpy(result->contig, $1);
    result->chr = false;
    result->lower = 0;
    result->upper = INT_MAX;
  }
  ;

  boundary: POSITION
  {
    char *endptr = NULL;  /* for strtol() */
    long val = 0;
    errno = 0;

    val = strtol ($1, &endptr, 10);
    if (endptr == $1)
      ereport(ERROR, (errcode(ERRCODE_INVALID_PARAMETER_VALUE), errmsg("no digits found")));
    else if (errno == ERANGE && val == LONG_MAX)
      ereport(ERROR, (errcode(ERRCODE_INVALID_PARAMETER_VALUE), errmsg("invalid number %s (long overflow)", $1)));
    else if (val > INT_MAX)
      ereport(ERROR, (errcode(ERRCODE_INVALID_PARAMETER_VALUE), errmsg("invalid number %s (int32 overflow)", $1)));

    $$ = (int32)val;
  }

  | POSITION_WITH_COMMAS
  {
    char *endptr = NULL;  /* for strtol() */
    long val = 0;
    errno = 0;

    remove_commas($1);

    val = strtol ($1, &endptr, 10);
    if (endptr == $1)
      ereport(ERROR, (errcode(ERRCODE_INVALID_PARAMETER_VALUE), errmsg("no digits found")));
    else if (errno == ERANGE && val == LONG_MAX)
      ereport(ERROR, (errcode(ERRCODE_INVALID_PARAMETER_VALUE), errmsg("invalid number %lu (overflow)", val)));
    else if (val > INT_MAX)
      ereport(ERROR, (errcode(ERRCODE_INVALID_PARAMETER_VALUE), errmsg("invalid number %s (int32 overflow)", $1)));
    //     printf (" number : %lu  invalid  (overflow occurred)\n", val);
    // else if (errno == EINVAL)  /* not in all c99 implementations - gcc OK */
    //     printf (" number : %lu  invalid  (base contains unsupported value)\n", val);
    // else if (errno != 0 && val == 0)
    //     printf (" number : %lu  invalid  (unspecified error occurred)\n", val);
    // else if (errno == 0 && nptr && !*endptr)
    //     printf (" number : %lu    valid  (and represents all characters read)\n", val);
    // else if (errno == 0 && nptr && *endptr != 0)
    //     printf (" number : %lu    valid  (but additional characters remain)\n", val);

    $$ = (int32)val;
  }
  ;

%%

void remove_commas (char *number) {
  char *p, *j;
  for (p = j = number; *p; p++) {
    if (*p != ',') *(j++) = *p;
  }
  *j = '\0';
}

#include "locus_scan.c"
