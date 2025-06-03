%{
/*
 * A scanner for genomic ranges
 */

#include "postgres.h"

/* No reason to constrain the amount of data slurped */
#define YY_READ_BUF_SIZE 16777216

/* Avoid exit() on fatal scanner errors (a bit ugly -- see yy_fatal_error) */
#undef fprintf
#define fprintf(file, fmt, msg)  fprintf_to_ereport(fmt, msg)

static void
fprintf_to_ereport(const char *fmt, const char *msg)
{
	ereport(ERROR, (errmsg_internal("%s", msg)));
}

/* Handles to the buffer that the lexer uses internally */
static YY_BUFFER_STATE scanbufhandle;
static char *scanbuf;
static int  scanbuflen;

/* flex 2.5.4 doesn't bother with a decl for this */
int locus_yylex(void);

void locus_scanner_init(const char *str);
void locus_scanner_finish(void);
%}

%option 8bit
%option never-interactive
%option nodefault
%option noinput
%option nounput
%option noyywrap
%option warn
%option prefix="locus_yy"


dash                    -
colon                   :
position                [0-9]+
position_with_commas    [0-9]{1,3},[0-9]{3}(,[0-9]{3})*
chr_contig              chr[^: \t\n]{1,11}
contig                  ^[ \t\n]*[^: \t\n]{1,14}
contig_long             ^[ \t\n]*[^: \t\n]{14,}

%%

<<EOF>>                 return END_OF_INPUT;
{dash}                  yylval.text = yytext; return DASH;
{colon}                 yylval.text = yytext; return COLON;
{position_with_commas}  yylval.text = yytext; return POSITION_WITH_COMMAS;
{chr_contig}            yylval.text = strdup(yytext); return CHR_CONTIG;
{contig}                yylval.text = strdup(yytext); return CONTIG;
{contig_long}           yylval.text = strdup(yytext); return CONTIG_LONG;
{position}              yylval.text = yytext; return POSITION;
[ \t\n]+                /* discard spaces */
.                       ereport(ERROR, (errcode(ERRCODE_SYNTAX_ERROR), errmsg("locus syntax error"), errdetail(" bad character %s", yytext)));

%%
// .            return yytext[0]; /* alert parser of garbage -- this can't be done because pretty much everying can go into contig name */

void __attribute__((noreturn))
yyerror(LOCUS *result, const char *message)
{
  if (*yytext == YY_END_OF_BUFFER_CHAR)
  {
    ereport(ERROR,
        (errcode(ERRCODE_SYNTAX_ERROR),
         errmsg("bad locus representation"),
         /* translator: %s is typically "syntax error" */
         errdetail("%s at end of input", message)));
  }
  else
  {
    ereport(ERROR,
        (errcode(ERRCODE_SYNTAX_ERROR),
         errmsg("bad locus representation"),
         /* translator: first %s is typically "syntax error" */
         errdetail("%s at or near \"%s\"", message, yytext)));
  }
}


/*
 * Called before any actual parsing is done
 */
void
locus_scanner_init(const char *str)
{
  Size  slen = strlen(str);

  /*
   * Might be left over after ereport()
   */
  if (YY_CURRENT_BUFFER)
    yy_delete_buffer(YY_CURRENT_BUFFER);

  /*
   * Make a scan buffer with special termination needed by flex.
   */
  scanbuflen = slen;
  scanbuf = palloc(slen + 2);
  memcpy(scanbuf, str, slen);
  scanbuf[slen] = scanbuf[slen + 1] = YY_END_OF_BUFFER_CHAR;
  scanbufhandle = yy_scan_buffer(scanbuf, slen + 2);

  BEGIN(INITIAL);
}


/*
 * Called after parsing is done to clean up after locus_scanner_init()
 */
void
locus_scanner_finish(void)
{
  yy_delete_buffer(scanbufhandle);
  pfree(scanbuf);
}
