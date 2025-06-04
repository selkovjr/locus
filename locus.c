/*
 * contrib/locus/locus.c
 *
 ******************************************************************************
 This file contains routines that can be bound to a Postgres backend and called
 by the backend while processing queries.  The calling format for these
 routines is dictated by Postgres architecture.
 ******************************************************************************/


#include <float.h>
#include <limits.h>  /* for INT_MAX */

#include "postgres.h"
#include "access/gist.h"
#include "access/stratnum.h"
#include "utils/builtins.h"
#include "utils/typcache.h"
#include "utils/rangetypes.h"
#include "fmgr.h"

#include "locus_data.h"
#include "strnatcmp.h"


#define DatumGetLocusP(X) ((LOCUS *) DatumGetPointer(X))
#define PG_GETARG_LOCUS_P(n) DatumGetLocusP(PG_GETARG_POINTER(n))


/*
#define GIST_DEBUG
#define GIST_QUERY_DEBUG
*/

PG_MODULE_MAGIC;

/*
 * Auxiliary data structure for the picksplit method.
 */
typedef struct
{
  float   center;
  OffsetNumber index;
  LOCUS      *data;
} gist_locus_picksplit_item;

/*
** Input/Output routines
*/
PG_FUNCTION_INFO_V1(locus_in);
PG_FUNCTION_INFO_V1(locus_out);
PG_FUNCTION_INFO_V1(contig);
PG_FUNCTION_INFO_V1(range);
PG_FUNCTION_INFO_V1(length);
PG_FUNCTION_INFO_V1(lower);
PG_FUNCTION_INFO_V1(upper);
PG_FUNCTION_INFO_V1(center);

/*
** GiST support methods
*/
PG_FUNCTION_INFO_V1(gist_locus_consistent);
PG_FUNCTION_INFO_V1(gist_locus_compress);
PG_FUNCTION_INFO_V1(gist_locus_decompress);
PG_FUNCTION_INFO_V1(gist_locus_picksplit);
PG_FUNCTION_INFO_V1(gist_locus_penalty);
PG_FUNCTION_INFO_V1(gist_locus_union);
PG_FUNCTION_INFO_V1(gist_locus_same);

static Datum gist_locus_leaf_consistent(Datum key, Datum query, StrategyNumber strategy);
static Datum gist_locus_internal_consistent(Datum key, Datum query, StrategyNumber strategy);
static Datum gist_locus_binary_union(Datum r1, Datum r2, int *sizep);

/*
** R-tree support functions
**
** The R-tree access method is no longer available but its functions
** are used to embody the GiST abstraction.
*/
PG_FUNCTION_INFO_V1(locus_same);
PG_FUNCTION_INFO_V1(locus_contains);
PG_FUNCTION_INFO_V1(locus_contained);
PG_FUNCTION_INFO_V1(locus_overlap);
PG_FUNCTION_INFO_V1(locus_left);
PG_FUNCTION_INFO_V1(locus_over_left);
PG_FUNCTION_INFO_V1(locus_right);
PG_FUNCTION_INFO_V1(locus_over_right);
PG_FUNCTION_INFO_V1(locus_union);
PG_FUNCTION_INFO_V1(locus_inter);
static void rt_locus_size(LOCUS *a, float *size);
/*
** Various operators
*/
PG_FUNCTION_INFO_V1(locus_cmp);
PG_FUNCTION_INFO_V1(locus_lt);
PG_FUNCTION_INFO_V1(locus_le);
PG_FUNCTION_INFO_V1(locus_gt);
PG_FUNCTION_INFO_V1(locus_ge);
PG_FUNCTION_INFO_V1(locus_different);

/*
** Experimental tiling function to support performance benchmarks
*/
PG_FUNCTION_INFO_V1(locus_tile_id);


/*****************************************************************************
 * Input/Output functions
 *****************************************************************************/

Datum
locus_in(PG_FUNCTION_ARGS)
{
  char     *str = PG_GETARG_CSTRING(0);
  LOCUS    *result = palloc(sizeof(LOCUS));

  locus_scanner_init(str);

  if (locus_yyparse(result) != 0)
    locus_yyerror(result, "bogus input");

  locus_scanner_finish();

  PG_RETURN_POINTER(result);
}

// ------------------------- locus_out ---------------------------
Datum
locus_out(PG_FUNCTION_ARGS)
{
  LOCUS    *locus = PG_GETARG_LOCUS_P(0);
  char     *result;

  result = (char *) palloc(40);   // max 14 chars of contig + two delimiters + max 20 digits


  if (locus == (LOCUS *) NULL) {
    sprintf(result, "NULL");
  }
  else if (locus->lower == locus->upper) {
  /*
   * indicates that this interval was built by locus_in() off a single point
   */
    sprintf(result, locus->chr ? "chr%s:%d" : "%s:%d", locus->contig, locus->lower);
  }
  else if (locus->lower > 0 && locus->upper == INT_MAX) {
    sprintf(result, locus->chr ? "chr%s:%d-" : "%s:%d-", locus->contig, locus->lower);
  }
  else if (locus->lower == 0 && locus->upper < INT_MAX) {
    sprintf(result, locus->chr ? "chr%s:-%d" : "%s:-%d", locus->contig, locus->upper);
  }
  else if (locus->lower == 0 && locus->upper == INT_MAX) {
    sprintf(result, locus->chr ? "chr%s" : "%s", locus->contig);
  }
  else{
    sprintf(result, locus->chr ? "chr%s:%d-%d" : "%s:%d-%d", locus->contig, locus->lower, locus->upper);
  }

  PG_RETURN_CSTRING(result);
}

// ------------------------- contig ---------------------------
Datum
contig(PG_FUNCTION_ARGS)
{
  LOCUS      *locus = PG_GETARG_LOCUS_P(0);

  PG_RETURN_TEXT_P(cstring_to_text(locus->contig));
}

// ------------------------- range ---------------------------
Datum
range(PG_FUNCTION_ARGS)
{
  LOCUS      *locus = PG_GETARG_LOCUS_P(0);

  // The oid and type data are delived from the int8range return in  CREATE FUNCTION
  Oid     rngtypid = get_fn_expr_rettype(fcinfo->flinfo);
  TypeCacheEntry *typcache = range_get_typcache(fcinfo, rngtypid);

  RangeBound  lower;
  RangeBound  upper;

  // lower.val = locus->lower == 0 ? (Datum) 0 : locus->lower;  /* this will be useful if ever get to define infinite intervals
  lower.val = locus->lower;
  // lower.infinite = locus->lower == 0;
  lower.infinite = false;
  lower.inclusive = true;
  lower.lower = true;

  // upper.val = locus->upper == INT_MAX ? (Datum) 0 : locus->upper;
  upper.val = locus->upper;
  // upper.infinite = locus->upper == INT_MAX;
  upper.infinite = false;
  upper.inclusive = true;
  upper.lower = false;

  PG_RETURN_RANGE_P(range_serialize(typcache, &lower, &upper, false));
}

// ------------------------- center ---------------------------
Datum
center(PG_FUNCTION_ARGS)
{
  LOCUS      *locus = PG_GETARG_LOCUS_P(0);

  PG_RETURN_INT32( (locus->lower + locus->upper) / 2 );
}

// ------------------------- lower ---------------------------
Datum
lower(PG_FUNCTION_ARGS)
{
  LOCUS      *locus = PG_GETARG_LOCUS_P(0);

  PG_RETURN_INT32(locus->lower);
}

// ------------------------- upper ---------------------------
Datum
upper(PG_FUNCTION_ARGS)
{
  LOCUS      *locus = PG_GETARG_LOCUS_P(0);

  PG_RETURN_INT32(locus->upper);
}


/*****************************************************************************
 *               GiST functions
 *****************************************************************************/

/*
** The GiST Consistent method for genomic loci
** Should return false if for all data items x below entry,
** the predicate x op query == false, where op is the oper
** corresponding to strategy in the pg_amop table.
*/
Datum
gist_locus_consistent(PG_FUNCTION_ARGS)
{
  GISTENTRY  *entry = (GISTENTRY *) PG_GETARG_POINTER(0);
  Datum   query = PG_GETARG_DATUM(1);
  StrategyNumber strategy = (StrategyNumber) PG_GETARG_UINT16(2);

  /* Oid    subtype = PG_GETARG_OID(3); */
  bool     *recheck = (bool *) PG_GETARG_POINTER(4);

  /* All cases served by this function are exact */
  *recheck = false;

  /*
   * if entry is not leaf, use gist_locus_internal_consistent, else use
   * gist_locus_leaf_consistent
   */
  if (GIST_LEAF(entry))
    return gist_locus_leaf_consistent(entry->key, query, strategy);
  else
    return gist_locus_internal_consistent(entry->key, query, strategy);
}

/*
** The GiST Union method for genomic loci
** returns the minimal bounding locus that encloses all the entries in entryvec
*/
Datum
gist_locus_union(PG_FUNCTION_ARGS)
{
  GistEntryVector *entryvec = (GistEntryVector *) PG_GETARG_POINTER(0);
  int      *sizep = (int *) PG_GETARG_POINTER(1);
  int     numranges,
        i;
  Datum   out = 0;
  Datum   tmp;

#ifdef GIST_DEBUG
  fprintf(stderr, "union\n");
#endif

  numranges = entryvec->n;
  tmp = entryvec->vector[0].key;
  *sizep = sizeof(LOCUS);

  for (i = 1; i < numranges; i++)
  {
    out = gist_locus_binary_union(tmp, entryvec->vector[i].key, sizep);
    tmp = out;
  }

  PG_RETURN_DATUM(out);
}

/*
** GiST Compress and Decompress methods for genomic loci
** do not do anything.
*/
Datum
gist_locus_compress(PG_FUNCTION_ARGS)
{
  PG_RETURN_POINTER(PG_GETARG_POINTER(0));
}

Datum
gist_locus_decompress(PG_FUNCTION_ARGS)
{
  PG_RETURN_POINTER(PG_GETARG_POINTER(0));
}

/*
** The GiST Penalty method for genomic loci
** As in the R-tree paper, we use change in area as our penalty metric
*/
Datum
gist_locus_penalty(PG_FUNCTION_ARGS)
{
  GISTENTRY  *origentry = (GISTENTRY *) PG_GETARG_POINTER(0);
  GISTENTRY  *newentry = (GISTENTRY *) PG_GETARG_POINTER(1);
  float    *result = (float *) PG_GETARG_POINTER(2);
  LOCUS      *ud;
  float   tmp1,
        tmp2;

  ud = DatumGetLocusP(DirectFunctionCall2(locus_union,
                      origentry->key,
                      newentry->key));
  rt_locus_size(ud, &tmp1);
  rt_locus_size(DatumGetLocusP(origentry->key), &tmp2);
  *result = tmp1 - tmp2;

#ifdef GIST_DEBUG
  fprintf(stderr, "penalty\n");
  fprintf(stderr, "\t%g\n", *result);
#endif

  PG_RETURN_POINTER(result);
}

/*
 * Compare function for gist_locus_picksplit_item: sort by center.
 */
static int
gist_locus_picksplit_item_cmp(const void *a, const void *b)
{
  const gist_locus_picksplit_item *i1 = (const gist_locus_picksplit_item *) a;
  const gist_locus_picksplit_item *i2 = (const gist_locus_picksplit_item *) b;

  if (i1->center < i2->center)
    return -1;
  else if (i1->center == i2->center)
    return 0;
  else
    return 1;
}

/*
 * The GiST PickSplit method for genomic loci
 *
 * We used to use Guttman's split algorithm here, but since the data is 1-D
 * it's easier and more robust to just sort the genomic loci by center-point and
 * split at the middle.
 */
Datum
gist_locus_picksplit(PG_FUNCTION_ARGS)
{
  GistEntryVector *entryvec = (GistEntryVector *) PG_GETARG_POINTER(0);
  GIST_SPLITVEC *v = (GIST_SPLITVEC *) PG_GETARG_POINTER(1);
  int     i;
  LOCUS      *locus,
         *locus_l,
         *locus_r;
  gist_locus_picksplit_item *sort_items;
  OffsetNumber *left,
         *right;
  OffsetNumber maxoff;
  OffsetNumber firstright;

#ifdef GIST_DEBUG
  fprintf(stderr, "picksplit\n");
#endif

  /* Valid items in entryvec->vector[] are indexed 1..maxoff */
  maxoff = entryvec->n - 1;

  /*
   * Prepare the auxiliary array and sort it.
   */
  sort_items = (gist_locus_picksplit_item *)
    palloc(maxoff * sizeof(gist_locus_picksplit_item));
  for (i = 1; i <= maxoff; i++)
  {
    locus = DatumGetLocusP(entryvec->vector[i].key);
    /* center calculation is done this way to avoid possible overflow */
    sort_items[i - 1].center = locus->lower * 0.5f + locus->upper * 0.5f;
    sort_items[i - 1].index = i;
    sort_items[i - 1].data = locus;
  }
  qsort(sort_items, maxoff, sizeof(gist_locus_picksplit_item),
      gist_locus_picksplit_item_cmp);

  /* sort items below "firstright" will go into the left side */
  firstright = maxoff / 2;

  v->spl_left = (OffsetNumber *) palloc(maxoff * sizeof(OffsetNumber));
  v->spl_right = (OffsetNumber *) palloc(maxoff * sizeof(OffsetNumber));
  left = v->spl_left;
  v->spl_nleft = 0;
  right = v->spl_right;
  v->spl_nright = 0;

  /*
   * Emit genomic loci to the left output page, and compute its bounding box.
   */
  locus_l = (LOCUS *) palloc(sizeof(LOCUS));
  memcpy(locus_l, sort_items[0].data, sizeof(LOCUS));
  *left++ = sort_items[0].index;
  v->spl_nleft++;
  for (i = 1; i < firstright; i++)
  {
    Datum   sortitem = PointerGetDatum(sort_items[i].data);

    locus_l = DatumGetLocusP(DirectFunctionCall2(locus_union,
                         PointerGetDatum(locus_l),
                         sortitem));
    *left++ = sort_items[i].index;
    v->spl_nleft++;
  }

  /*
   * Likewise for the right page.
   */
  locus_r = (LOCUS *) palloc(sizeof(LOCUS));
  memcpy(locus_r, sort_items[firstright].data, sizeof(LOCUS));
  *right++ = sort_items[firstright].index;
  v->spl_nright++;
  for (i = firstright + 1; i < maxoff; i++)
  {
    Datum   sortitem = PointerGetDatum(sort_items[i].data);

    locus_r = DatumGetLocusP(DirectFunctionCall2(locus_union,
                         PointerGetDatum(locus_r),
                         sortitem));
    *right++ = sort_items[i].index;
    v->spl_nright++;
  }

  v->spl_ldatum = PointerGetDatum(locus_l);
  v->spl_rdatum = PointerGetDatum(locus_r);

  PG_RETURN_POINTER(v);
}

/*
** Equality methods
*/
Datum
gist_locus_same(PG_FUNCTION_ARGS)
{
  bool     *result = (bool *) PG_GETARG_POINTER(2);

  if (DirectFunctionCall2(locus_same, PG_GETARG_DATUM(0), PG_GETARG_DATUM(1)))
    *result = true;
  else
    *result = false;

#ifdef GIST_DEBUG
  fprintf(stderr, "same: %s\n", (*result ? "true" : "false"));
#endif

  PG_RETURN_POINTER(result);
}

/*
** SUPPORT ROUTINES
*/
static Datum
gist_locus_leaf_consistent(Datum key, Datum query, StrategyNumber strategy)
{
  Datum   retval;

#ifdef GIST_QUERY_DEBUG
  fprintf(stderr, "leaf_consistent, %d\n", strategy);
#endif

  switch (strategy)
  {
    case RTLeftStrategyNumber:
      retval = DirectFunctionCall2(locus_left, key, query);
      break;
    case RTOverLeftStrategyNumber:
      retval = DirectFunctionCall2(locus_over_left, key, query);
      break;
    case RTOverlapStrategyNumber:
      retval = DirectFunctionCall2(locus_overlap, key, query);
      break;
    case RTOverRightStrategyNumber:
      retval = DirectFunctionCall2(locus_over_right, key, query);
      break;
    case RTRightStrategyNumber:
      retval = DirectFunctionCall2(locus_right, key, query);
      break;
    case RTSameStrategyNumber:
      retval = DirectFunctionCall2(locus_same, key, query);
      break;
    case RTContainsStrategyNumber:
    case RTOldContainsStrategyNumber:
      retval = DirectFunctionCall2(locus_contains, key, query);
      break;
    case RTContainedByStrategyNumber:
    case RTOldContainedByStrategyNumber:
      retval = DirectFunctionCall2(locus_contained, key, query);
      break;
    default:
      retval = false;
  }

  PG_RETURN_DATUM(retval);
}

static Datum
gist_locus_internal_consistent(Datum key, Datum query, StrategyNumber strategy)
{
  bool    retval;

#ifdef GIST_QUERY_DEBUG
  fprintf(stderr, "internal_consistent, %d\n", strategy);
#endif

  switch (strategy)
  {
    case RTLeftStrategyNumber:
      retval =
        !DatumGetBool(DirectFunctionCall2(locus_over_right, key, query));
      break;
    case RTOverLeftStrategyNumber:
      retval =
        !DatumGetBool(DirectFunctionCall2(locus_right, key, query));
      break;
    case RTOverlapStrategyNumber:
      retval =
        DatumGetBool(DirectFunctionCall2(locus_overlap, key, query));
      break;
    case RTOverRightStrategyNumber:
      retval =
        !DatumGetBool(DirectFunctionCall2(locus_left, key, query));
      break;
    case RTRightStrategyNumber:
      retval =
        !DatumGetBool(DirectFunctionCall2(locus_over_left, key, query));
      break;
    case RTSameStrategyNumber:
    case RTContainsStrategyNumber:
    case RTOldContainsStrategyNumber:
      retval =
        DatumGetBool(DirectFunctionCall2(locus_contains, key, query));
      break;
    case RTContainedByStrategyNumber:
    case RTOldContainedByStrategyNumber:
      retval =
        DatumGetBool(DirectFunctionCall2(locus_overlap, key, query));
      break;
    default:
      retval = false;
  }

  PG_RETURN_BOOL(retval);
}

static Datum
gist_locus_binary_union(Datum r1, Datum r2, int *sizep)
{
  Datum   retval;

  retval = DirectFunctionCall2(locus_union, r1, r2);
  *sizep = sizeof(LOCUS);

  return (retval);
}


Datum
locus_contains(PG_FUNCTION_ARGS)
{
  LOCUS      *a = PG_GETARG_LOCUS_P(0);
  LOCUS      *b = PG_GETARG_LOCUS_P(1);
  PG_RETURN_BOOL(
    (strcmp(a->contig, "<all>") == 0 || strnatcmp(a->contig, b->contig) == 0) &&
    (a->lower <= b->lower) && (a->upper >= b->upper)
  );
}

Datum
locus_contained(PG_FUNCTION_ARGS)
{
  Datum   a = PG_GETARG_DATUM(0);
  Datum   b = PG_GETARG_DATUM(1);

  PG_RETURN_DATUM(DirectFunctionCall2(locus_contains, b, a));
}


/*****************************************************************************
 * Operator class for R-tree indexing
 *****************************************************************************/

Datum
locus_same(PG_FUNCTION_ARGS)
{
  int     cmp = DatumGetInt32(
                  DirectFunctionCall2(locus_cmp, PG_GETARG_DATUM(0), PG_GETARG_DATUM(1)));

  PG_RETURN_BOOL(cmp == 0);
}

/*  locus_overlap -- does a overlap b?
 */
Datum
locus_overlap(PG_FUNCTION_ARGS)
{
  LOCUS      *a = PG_GETARG_LOCUS_P(0);
  LOCUS      *b = PG_GETARG_LOCUS_P(1);

  PG_RETURN_BOOL(
    (strcmp(a->contig, "<all>") == 0 || strcmp(a->contig, "<all>") == 0 || strnatcmp(a->contig, b->contig) == 0)
    &&
    (
      ((a->upper >= b->upper) && (a->lower <= b->upper)) ||
      ((b->upper >= a->upper) && (b->lower <= a->upper))
    )
  );
}

/*  locus_over_left -- (a) is not beyond the right boundary of (b)
 */
Datum
locus_over_left(PG_FUNCTION_ARGS)
{
  LOCUS      *a = PG_GETARG_LOCUS_P(0);
  LOCUS      *b = PG_GETARG_LOCUS_P(1);

  PG_RETURN_BOOL(
    (strcmp(a->contig, "<all>") == 0 || strnatcmp(a->contig, b->contig) <= 0)
    &&
    a->upper <= b->upper
  );
}

/*  locus_left -- (a) entirely to the left of (b)
 */
Datum
locus_left(PG_FUNCTION_ARGS)
{
  LOCUS      *a = PG_GETARG_LOCUS_P(0);
  LOCUS      *b = PG_GETARG_LOCUS_P(1);

  if (strcmp(a->contig, "<all>") == 0 || strcmp(b->contig, "<all>") == 0) PG_RETURN_BOOL(false);
  if (strnatcmp(a->contig, b->contig) > 0) PG_RETURN_BOOL(false);
  if (strnatcmp(a->contig, b->contig) < 0) PG_RETURN_BOOL(true);

  PG_RETURN_BOOL(a->upper < b->lower);
}

/*  locus_right -- (a) entirely to the right of (b)
 */
Datum
locus_right(PG_FUNCTION_ARGS)
{
  LOCUS      *a = PG_GETARG_LOCUS_P(0);
  LOCUS      *b = PG_GETARG_LOCUS_P(1);

  if (strcmp(a->contig, "<all>") == 0 || strcmp(b->contig, "<all>") == 0) PG_RETURN_BOOL(false);
  if (strnatcmp(a->contig, b->contig) < 0) PG_RETURN_BOOL(false);
  if (strnatcmp(a->contig, b->contig) > 0) PG_RETURN_BOOL(true);
  PG_RETURN_BOOL(a->lower > b->upper);
}

/*  locus_over_right -- (a) is not beyond the left boundary of (b)
 */
Datum
locus_over_right(PG_FUNCTION_ARGS)
{
  LOCUS      *a = PG_GETARG_LOCUS_P(0);
  LOCUS      *b = PG_GETARG_LOCUS_P(1);

  PG_RETURN_BOOL(
    (strcmp(a->contig, "<all>") == 0 || strnatcmp(a->contig, b->contig) >= 0)
    &&
    a->lower >= b->lower
  );
}

Datum
locus_union(PG_FUNCTION_ARGS)
{
  LOCUS      *a = PG_GETARG_LOCUS_P(0);
  LOCUS      *b = PG_GETARG_LOCUS_P(1);
  LOCUS      *n;

  n = (LOCUS *) palloc(sizeof(*n));

  if (strcmp(a->contig, b->contig) == 0) {
    strcpy(n->contig, a->contig);
    n->chr = a->chr;
  }
  else {
    sprintf(n->contig, "<all>");
    n->chr = false;
  }

  /* take max of upper endpoints */
  if (a->upper > b->upper) {
    n->upper = a->upper;
  }
  else {
    n->upper = b->upper;
  }

  /* take min of lower endpoints */
  if (a->lower < b->lower) {
    n->lower = a->lower;
  }
  else {
    n->lower = b->lower;
  }

  PG_RETURN_POINTER(n);
}

Datum
locus_inter(PG_FUNCTION_ARGS)
{
  LOCUS      *a = PG_GETARG_LOCUS_P(0);
  LOCUS      *b = PG_GETARG_LOCUS_P(1);
  LOCUS      *n;

  n = (LOCUS *) palloc(sizeof(*n));

  if (strnatcmp(a->contig, b->contig) == 0) {
    strcpy(n->contig, a->contig);
    n->chr = a->chr;
  }
  else {
    sprintf(n->contig, "<all>");
    n->chr = false;
  }

  /* take min of upper endpoints */
  if (a->upper < b->upper)
  {
    n->upper = a->upper;
  }
  else
  {
    n->upper = b->upper;
  }

  /* take max of lower endpoints */
  if (a->lower > b->lower)
  {
    n->lower = a->lower;
  }
  else
  {
    n->lower = b->lower;
  }

  PG_RETURN_POINTER(n);
}

static void
rt_locus_size(LOCUS *a, float *size)
{
  if (a == (LOCUS *) NULL)
    *size = 0.0;
  else
    *size = (float) a->upper - a->lower;

  return;
}

Datum
length(PG_FUNCTION_ARGS)
{
  LOCUS      *locus = PG_GETARG_LOCUS_P(0);

  PG_RETURN_INT32(locus->upper - locus->lower);
}


/*****************************************************************************
 *           Miscellaneous operators
 *****************************************************************************/
Datum
locus_cmp(PG_FUNCTION_ARGS)
{
  LOCUS      *a = PG_GETARG_LOCUS_P(0);
  LOCUS      *b = PG_GETARG_LOCUS_P(1);

  /*
   * First compare on contig
   */
  int32 contig_comparison = strnatcmp(a->contig, b->contig);
  if (contig_comparison != 0) {
    PG_RETURN_INT32(contig_comparison);
  }

  /*
   * First compare on lower boundary position
   */
  if (a->lower < b->lower)
    PG_RETURN_INT32(-1);
  if (a->lower > b->lower)
    PG_RETURN_INT32(1);


  /*
   * a->lower == b->lower, so compare the upper boundaries
   */
  if (a->upper < b->upper)
    PG_RETURN_INT32(-1);
  if (a->upper > b->upper)
    PG_RETURN_INT32(1);

  /*
   * a->upper == b->upper
   */
  PG_RETURN_INT32(0);
}

Datum
locus_lt(PG_FUNCTION_ARGS)
{
  int     cmp = DatumGetInt32(
                  DirectFunctionCall2(locus_cmp, PG_GETARG_DATUM(0), PG_GETARG_DATUM(1)));

  PG_RETURN_BOOL(cmp < 0);
}

Datum
locus_le(PG_FUNCTION_ARGS)
{
  int     cmp = DatumGetInt32(
                  DirectFunctionCall2(locus_cmp, PG_GETARG_DATUM(0), PG_GETARG_DATUM(1)));

  PG_RETURN_BOOL(cmp <= 0);
}

Datum
locus_gt(PG_FUNCTION_ARGS)
{
  int     cmp = DatumGetInt32(
                  DirectFunctionCall2(locus_cmp, PG_GETARG_DATUM(0), PG_GETARG_DATUM(1)));

  PG_RETURN_BOOL(cmp > 0);
}

Datum
locus_ge(PG_FUNCTION_ARGS)
{
  int     cmp = DatumGetInt32(
                  DirectFunctionCall2(locus_cmp, PG_GETARG_DATUM(0), PG_GETARG_DATUM(1)));

  PG_RETURN_BOOL(cmp >= 0);
}


Datum
locus_different(PG_FUNCTION_ARGS)
{
  int     cmp = DatumGetInt32(
                  DirectFunctionCall2(locus_cmp, PG_GETARG_DATUM(0), PG_GETARG_DATUM(1)));

  PG_RETURN_BOOL(cmp != 0);
}


// This function was suggested by ChatGPT as a benchmarking tool to evaluate
// GIST performance with JOINs over large genomic datasets. The region tiling approach
// is used by bedtools and other tools, so it can be a relatable benchmark.
Datum
locus_tile_id(PG_FUNCTION_ARGS)
{
    LOCUS *loc = (LOCUS *) PG_GETARG_POINTER(0);
    int64 tile_width = 1000000;
    int64 start;
    int64 tile_id;
    char buf[64];
    text *result;

    if (PG_NARGS() == 2 && !PG_ARGISNULL(1)) {
        tile_width = PG_GETARG_INT64(1);
        if (tile_width <= 0)
            ereport(ERROR,
                    (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
                     errmsg("tile width must be positive")));
    }

    start = (int64) loc->lower;
    tile_id = start / tile_width;

    snprintf(buf, sizeof(buf), "%s:%lld", loc->contig, (long long) tile_id);
    result = cstring_to_text(buf);

    PG_RETURN_TEXT_P(result);
}

