/*
 * contrib/locus/locus.c
 *
 ******************************************************************************
  This file contains routines that can be bound to a Postgres backend and
  called by the backend in the process of processing queries.  The calling
  format for these routines is dictated by Postgres architecture.
******************************************************************************/

#include "postgres.h"

#include <string.h>
#include <math.h>

#include "access/gist.h"
#include "access/stratnum.h"
#include "fmgr.h"

#include "locusdata.h"
#include "strnatcmp.h"

#define DatumGetSegP(X) ((LOCUS *) DatumGetPointer(X))
#define PG_GETARG_LOCUS_P(n) DatumGetSegP(PG_GETARG_POINTER(n))


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
  float        center;
  OffsetNumber index;
  LOCUS        *data;
} glocus_picksplit_item;

/*
** Input/Output routines
*/
PG_FUNCTION_INFO_V1(locus_in);
PG_FUNCTION_INFO_V1(locus_out);
PG_FUNCTION_INFO_V1(locus_size);
PG_FUNCTION_INFO_V1(locus_start);
PG_FUNCTION_INFO_V1(locus_start_pos);
PG_FUNCTION_INFO_V1(locus_end);
PG_FUNCTION_INFO_V1(locus_end_pos);
PG_FUNCTION_INFO_V1(locus_center);

/*
** GiST support methods
*/
PG_FUNCTION_INFO_V1(glocus_consistent);
PG_FUNCTION_INFO_V1(glocus_compress);
PG_FUNCTION_INFO_V1(glocus_decompress);
PG_FUNCTION_INFO_V1(glocus_picksplit);
PG_FUNCTION_INFO_V1(glocus_penalty);
PG_FUNCTION_INFO_V1(glocus_union);
PG_FUNCTION_INFO_V1(glocus_same);
static Datum glocus_leaf_consistent(Datum key, Datum query, StrategyNumber strategy);
static Datum glocus_internal_consistent(Datum key, Datum query, StrategyNumber strategy);
static Datum glocus_binary_union(Datum r1, Datum r2, int *sizep);


/*
** R-tree support functions
*/
PG_FUNCTION_INFO_V1(locus_same);
PG_FUNCTION_INFO_V1(locus_coord_cmp);
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


/*****************************************************************************
 * Input/Output functions
 *****************************************************************************/

Datum
locus_in(PG_FUNCTION_ARGS)
{
  char   *str = PG_GETARG_CSTRING(0);
  char   *str_copy = pstrdup(str);
  LOCUS  *result = palloc(sizeof(LOCUS));
  char   *contig;
  char   *start_pos, *end_pos, *dash_ptr;
  int32  start, end;
  int    size, n;

  contig = strtok(str_copy, ":");
  if (!contig) {
    ereport (
      ERROR,
      (errcode(ERRCODE_SYNTAX_ERROR),
       errmsg("(1) invalid input syntax for genomic locus \"%s\"; expecting contig name followed by a ':'", str))
    );
  }

  start_pos = strtok(NULL, "-");
  if (!start_pos) {
    ereport (
      ERROR,
      (errcode(ERRCODE_SYNTAX_ERROR),
       errmsg("(2) invalid input syntax for genomic locus \"%s\"; expecting ':' followed by an integer", str))
    );
  }
  n = sscanf(start_pos, "%d", &start);
  if (n == 0) {
    ereport (
      ERROR,
      (errcode(ERRCODE_SYNTAX_ERROR),
       errmsg("(3) invalid input syntax for genomic locus \"%s\"; expecting ':' followed by an integer", str))
    );
  }

  dash_ptr = strchr(str, '-');
  if (dash_ptr == NULL) { // we're done
    end = start;
  }
  else {
    end_pos = strtok(NULL, "-");
    if (!end_pos) {
      ereport (
        ERROR,
        (errcode(ERRCODE_SYNTAX_ERROR),
         errmsg("(4) invalid input syntax for genomic locus \"%s\"; expecting an integer", str))
      );
    }
    n = sscanf(end_pos, "%d", &end);
    if (n == 0) {
      ereport (
        ERROR,
        (errcode(ERRCODE_SYNTAX_ERROR),
         errmsg("(5) invalid input syntax for genomic locus \"%s\"; expecting an integer after '-'", str))
      );
    }

    if (end < start) {
      ereport (
        ERROR,
        (errcode(ERRCODE_SYNTAX_ERROR),
         errmsg("(6) start position in genomic locus \"%s\" is greater than end position (%d > %d)", str, start, end))
      );
    }
  }


  // Write the data into the new LOCUS object
  size = LOCUS_SIZE(contig);
  result = (LOCUS *) palloc0(size);
  SET_VARSIZE(result, size);
  for (n = 0; n < sizeof(contig); n++) {
    result->contig[n] = contig[n];
  }
  result->start = start;
  result->end = end;

  PG_RETURN_POINTER(result);
}

Datum
locus_out(PG_FUNCTION_ARGS)
{
  LOCUS *locus = PG_GETARG_LOCUS_P(0);
  char  *result;

  result = (char *) palloc(100);

  if (locus->start == locus->end )
  {
    /*
     * indicates that this interval was built by locus_in off a single point
     */
    sprintf(result, "%s:%d", locus->contig, locus->start);
  }
  else
  {
    sprintf(result, "%s:%d-%d", locus->contig, locus->start, locus->end);
  }

  PG_RETURN_CSTRING(result);
}

Datum
locus_center(PG_FUNCTION_ARGS)
{
  LOCUS  *locus = PG_GETARG_LOCUS_P(0);
  LOCUS  *new_locus;
  char   *contig = pstrdup(locus->contig); // need this to determine the length of contig name at runtime
  int    size;
  int32  c = (locus->start + locus->end) / 2;


  size = LOCUS_SIZE(contig);
  new_locus = (LOCUS *) palloc0(size);
  SET_VARSIZE(new_locus, size);
  strcpy(new_locus->contig, locus->contig);

  new_locus->start = c;;
  new_locus->end = c;
  if ((locus->end - locus->start) % 2) {
    new_locus->end++;
  }

  PG_RETURN_POINTER(new_locus);
}

Datum
locus_start(PG_FUNCTION_ARGS)
{
  LOCUS  *locus = PG_GETARG_LOCUS_P(0);
  char   *contig = pstrdup(locus->contig); // need this to determine the length of contig name at runtime
  LOCUS  *new_locus;
  int    size;

  size = LOCUS_SIZE(contig);
  new_locus = (LOCUS *) palloc0(size);
  SET_VARSIZE(new_locus, size);
  strcpy(new_locus->contig, locus->contig);
  new_locus->start = locus->start;
  new_locus->end = locus->start;

  PG_RETURN_POINTER(new_locus);
}

Datum
locus_start_pos(PG_FUNCTION_ARGS)
{
  LOCUS      *locus = PG_GETARG_LOCUS_P(0);
  PG_RETURN_INT32(locus->start);
}

Datum
locus_end(PG_FUNCTION_ARGS)
{
  LOCUS  *locus = PG_GETARG_LOCUS_P(0);
  char   *contig = pstrdup(locus->contig); // need this to determine the length of contig name at runtime
  LOCUS  *new_locus;
  int    size;

  size = LOCUS_SIZE(contig);
  new_locus = (LOCUS *) palloc0(size);
  SET_VARSIZE(new_locus, size);
  strcpy(new_locus->contig, locus->contig);
  new_locus->start = locus->end;
  new_locus->end = locus->end;

  PG_RETURN_POINTER(new_locus);
}

Datum
locus_end_pos(PG_FUNCTION_ARGS)
{
  LOCUS      *locus = PG_GETARG_LOCUS_P(0);
  PG_RETURN_INT32(locus->end);
}


/*****************************************************************************
 *               GiST functions
 *****************************************************************************/

/*
** The GiST Consistent method for loci
** Should return false if for all data items x below entry,
** the predicate x op query == FALSE, where op is the oper
** corresponding to strategy in the pg_amop table.
*/
Datum
glocus_consistent(PG_FUNCTION_ARGS)
{
  GISTENTRY       *entry = (GISTENTRY *) PG_GETARG_POINTER(0);
  Datum           query = PG_GETARG_DATUM(1);
  StrategyNumber  strategy = (StrategyNumber) PG_GETARG_UINT16(2);

  /* Oid  subtype = PG_GETARG_OID(3); */
  bool            *recheck = (bool *) PG_GETARG_POINTER(4);

  /* All cases served by this function are exact */
  *recheck = false;

  /*
   * if entry is not leaf, use glocus_internal_consistent, else use
   * glocus_leaf_consistent
   */
  if (GIST_LEAF(entry))
    return glocus_leaf_consistent(entry->key, query, strategy);
  else
    return glocus_internal_consistent(entry->key, query, strategy);
}

/*
** The GiST Union method for loci
** returns the minimal bounding locus that encloses all the entries in entryvec
*/
Datum
glocus_union(PG_FUNCTION_ARGS)
{
  GistEntryVector *entryvec = (GistEntryVector *) PG_GETARG_POINTER(0);
  int             *sizep = (int *) PG_GETARG_POINTER(1);
  int             numranges, i;
  Datum           out = 0;
  Datum           tmp;

#ifdef GIST_DEBUG
  fprintf(stderr, "union\n");
#endif

  numranges = entryvec->n;
  tmp = entryvec->vector[0].key;
  *sizep = sizeof(LOCUS);

  for (i = 1; i < numranges; i++)
  {
    out = glocus_binary_union(tmp, entryvec->vector[i].key, sizep);
    tmp = out;
  }

  PG_RETURN_DATUM(out);
}

/*
** GiST Compress and Decompress methods for loci
** do not do anything.
*/
Datum
glocus_compress(PG_FUNCTION_ARGS)
{
  PG_RETURN_POINTER(PG_GETARG_POINTER(0));
}

Datum
glocus_decompress(PG_FUNCTION_ARGS)
{
  PG_RETURN_POINTER(PG_GETARG_POINTER(0));
}

/*
** The GiST Penalty method for loci
** As in the R-tree paper, we use change in area as our penalty metric
*/
Datum
glocus_penalty(PG_FUNCTION_ARGS)
{
  GISTENTRY  *origentry = (GISTENTRY *) PG_GETARG_POINTER(0);
  GISTENTRY  *newentry = (GISTENTRY *) PG_GETARG_POINTER(1);
  float      *result = (float *) PG_GETARG_POINTER(2);
  LOCUS      *ud;
  float      tmp1, tmp2;

  ud = DatumGetSegP(
    DirectFunctionCall2(locus_union, origentry->key, newentry->key)
  );
  rt_locus_size(ud, &tmp1);
  rt_locus_size(DatumGetSegP(origentry->key), &tmp2);
  *result = tmp1 - tmp2;

#ifdef GIST_DEBUG
  fprintf(stderr, "penalty\n");
  fprintf(stderr, "\t%g\n", *result);
#endif

  PG_RETURN_POINTER(result);
}

/*
 * Comparator function for glocus_picksplit_item: sort by center.
 */
static int
glocus_picksplit_item_cmp(const void *a, const void *b)
{
  const glocus_picksplit_item *i1 = (const glocus_picksplit_item *) a;
  const glocus_picksplit_item *i2 = (const glocus_picksplit_item *) b;

  if (i1->center < i2->center)
    return -1;
  else if (i1->center == i2->center)
    return 0;
  else
    return 1;
}

/*
 * The GiST PickSplit method for loci
 *
 * We used to use Guttman's split algorithm here, but since the data is 1-D
 * it's easier and more robust to just sort the loci by center-point and
 * split at the middle.
 */
Datum
glocus_picksplit(PG_FUNCTION_ARGS)
{
  GistEntryVector *entryvec = (GistEntryVector *) PG_GETARG_POINTER(0);
  GIST_SPLITVEC   *v = (GIST_SPLITVEC *) PG_GETARG_POINTER(1);
  int    i;
  LOCUS  *locus, *locus_l, *locus_r;
  glocus_picksplit_item  *sort_items;
  OffsetNumber           *left, *right;
  OffsetNumber           maxoff;
  OffsetNumber           firstright;

#ifdef GIST_DEBUG
  fprintf(stderr, "picksplit\n");
#endif

  /* Valid items in entryvec->vector[] are indexed 1..maxoff */
  maxoff = entryvec->n - 1;

  /*
   * Prepare the auxiliary array and sort it.
   */
  sort_items = (glocus_picksplit_item *)
    palloc(maxoff * sizeof(glocus_picksplit_item));
  for (i = 1; i <= maxoff; i++)
  {
    locus = DatumGetSegP(entryvec->vector[i].key);
    /* center calculation is done this way to avoid possible overflow */
    sort_items[i - 1].center = locus->start * 0.5f + locus->end * 0.5f;
    sort_items[i - 1].index = i;
    sort_items[i - 1].data = locus;
  }
  qsort(sort_items, maxoff, sizeof(glocus_picksplit_item),
      glocus_picksplit_item_cmp);

  /* sort items below "firstright" will go into the left side */
  firstright = maxoff / 2;

  v->spl_left = (OffsetNumber *) palloc(maxoff * sizeof(OffsetNumber));
  v->spl_right = (OffsetNumber *) palloc(maxoff * sizeof(OffsetNumber));
  left = v->spl_left;
  v->spl_nleft = 0;
  right = v->spl_right;
  v->spl_nright = 0;

  /*
   * Emit loci to the left output page, and compute its bounding box.
   */
  locus_l = (LOCUS *) palloc(sizeof(LOCUS));
  memcpy(locus_l, sort_items[0].data, sizeof(LOCUS));
  *left++ = sort_items[0].index;
  v->spl_nleft++;
  for (i = 1; i < firstright; i++)
  {
    Datum   sortitem = PointerGetDatum(sort_items[i].data);

    locus_l = DatumGetSegP(DirectFunctionCall2(locus_union,
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

    locus_r = DatumGetSegP(DirectFunctionCall2(locus_union,
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
locus_cmp(PG_FUNCTION_ARGS)
{
  LOCUS  *a = PG_GETARG_LOCUS_P(0);
  LOCUS  *b = PG_GETARG_LOCUS_P(1);
  int    cmp = strnatcasecmp(a->contig, b->contig);

  if (cmp) {
    PG_RETURN_INT32(cmp);
  }
  if (a->start < b->start)
    PG_RETURN_INT32(-1);
  if (a->start > b->start)
    PG_RETURN_INT32(1);

  if (a->end < b->end)
    PG_RETURN_INT32(-1);
  if (a->end > b->end)
    PG_RETURN_INT32(1);

  PG_RETURN_INT32(0);
}

/*
 * This function simply compares contig co-ordinates, disregarding contig name
 */
Datum
locus_coord_cmp(PG_FUNCTION_ARGS)
{
  LOCUS  *a = PG_GETARG_LOCUS_P(0);
  LOCUS  *b = PG_GETARG_LOCUS_P(1);

  if (a->start < b->start)
    PG_RETURN_INT32(-1);
  if (a->start > b->start)
    PG_RETURN_INT32(1);

  if (a->end < b->end)
    PG_RETURN_INT32(-1);
  if (a->end > b->end)
    PG_RETURN_INT32(1);

  PG_RETURN_INT32(0);
}

Datum
glocus_same(PG_FUNCTION_ARGS)
{
  bool *result = (bool *) PG_GETARG_POINTER(2);

  if (DirectFunctionCall2(locus_same, PG_GETARG_DATUM(0), PG_GETARG_DATUM(1)))
    *result = TRUE;
  else
    *result = FALSE;

#ifdef GIST_DEBUG
  fprintf(stderr, "same: %s\n", (*result ? "TRUE" : "FALSE"));
#endif

  PG_RETURN_POINTER(result);
}

/*
** SUPPORT ROUTINES
*/
static Datum
glocus_leaf_consistent(Datum key, Datum query, StrategyNumber strategy)
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
      retval = FALSE;
  }

  PG_RETURN_DATUM(retval);
}

static Datum
glocus_internal_consistent(Datum key, Datum query, StrategyNumber strategy)
{
  bool retval;

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
      retval = FALSE;
  }

  PG_RETURN_BOOL(retval);
}

static Datum
glocus_binary_union(Datum r1, Datum r2, int *sizep)
{
  Datum   retval;

  retval = DirectFunctionCall2(locus_union, r1, r2);
  *sizep = sizeof(LOCUS);

  return (retval);
}


Datum
locus_contains(PG_FUNCTION_ARGS)
{
  LOCUS  *a = PG_GETARG_LOCUS_P(0);
  LOCUS  *b = PG_GETARG_LOCUS_P(1);
  int    same_contig = !strcmp(a->contig, b->contig);

  PG_RETURN_BOOL(same_contig && (a->start <= b->start) && (a->end >= b->end));
}

Datum
locus_contained(PG_FUNCTION_ARGS)
{
  Datum  a = PG_GETARG_DATUM(0);
  Datum  b = PG_GETARG_DATUM(1);

  PG_RETURN_DATUM(DirectFunctionCall2(locus_contains, b, a));
}

/*****************************************************************************
 * Operator class for R-tree indexing
 *****************************************************************************/

Datum
locus_same(PG_FUNCTION_ARGS)
{
  int cmp = DatumGetInt32(
    DirectFunctionCall2(locus_coord_cmp, PG_GETARG_DATUM(0), PG_GETARG_DATUM(1))
  );

  PG_RETURN_BOOL(cmp == 0);
}

/*  locus_overlap -- does a overlap b?
 */
Datum
locus_overlap(PG_FUNCTION_ARGS)
{
  LOCUS  *a = PG_GETARG_LOCUS_P(0);
  LOCUS  *b = PG_GETARG_LOCUS_P(1);
  int    same_contig = !strcmp(a->contig, b->contig);

  PG_RETURN_BOOL(
    same_contig && (
      ((a->end >= b->end) && (a->start <= b->end)) ||
      ((b->end >= a->end) && (b->start <= a->end))
    )
  );
}

/*
 * locus_over_left -- is the right edge of (a) located within (b)?
 */
Datum
locus_over_left(PG_FUNCTION_ARGS)
{
  LOCUS  *a = PG_GETARG_LOCUS_P(0);
  LOCUS  *b = PG_GETARG_LOCUS_P(1);
  int    same_contig = !strcmp(a->contig, b->contig);

  PG_RETURN_BOOL(same_contig && a->end <= b->end && a->end >= b->start);
}

/*
 * locus_left -- is (a) entirely on the left of (b)?
 */
Datum
locus_left(PG_FUNCTION_ARGS)
{
  LOCUS  *a = PG_GETARG_LOCUS_P(0);
  LOCUS  *b = PG_GETARG_LOCUS_P(1);
  int    same_contig = !strcmp(a->contig, b->contig);

  PG_RETURN_BOOL(same_contig && a->end < b->start);
}

/*
 * locus_right -- is (a) entirely on the right of (b)?
 */
Datum
locus_right(PG_FUNCTION_ARGS)
{
  LOCUS  *a = PG_GETARG_LOCUS_P(0);
  LOCUS  *b = PG_GETARG_LOCUS_P(1);
  int    same_contig = !strcmp(a->contig, b->contig);

  PG_RETURN_BOOL(same_contig && a->start > b->end);
}

/*  locus_over_right -- is the left edge of (a) located within (b)?
 */
Datum
locus_over_right(PG_FUNCTION_ARGS)
{
  LOCUS  *a = PG_GETARG_LOCUS_P(0);
  LOCUS  *b = PG_GETARG_LOCUS_P(1);
  int    same_contig = !strcmp(a->contig, b->contig);

  PG_RETURN_BOOL(same_contig && a->start >= b->start && a->start <= b->end);
}

Datum
locus_union(PG_FUNCTION_ARGS)
{
  LOCUS  *a = PG_GETARG_LOCUS_P(0);
  LOCUS  *b = PG_GETARG_LOCUS_P(1);
  LOCUS  *n;
  int    same_contig = !strcmp(a->contig, b->contig);

  n = (LOCUS *) palloc0(sizeof(*n));

  if (same_contig) {
    /* take max of endpoints */
    if (a->end > b->end)
    {
      n->end = a->end;
    }
    else
    {
      n->end = b->end;
    }

    /* take min of start positions */
    if (a->start < b->start)
    {
      n->start = a->start;
    }
    else
    {
      n->start = b->start;
    }
  }

  PG_RETURN_POINTER(n);
}

Datum
locus_inter(PG_FUNCTION_ARGS)
{
  LOCUS  *a = PG_GETARG_LOCUS_P(0);
  LOCUS  *b = PG_GETARG_LOCUS_P(1);
  LOCUS  *n;
  int    same_contig = !strcmp(a->contig, b->contig);

  n = (LOCUS *) palloc0(sizeof(*n));

  if (same_contig) {
    /* take min of endpoints */
    if (a->end < b->end)
    {
      n->end = a->end;
    }
    else
    {
      n->end = b->end;
    }

    /* take max of start positions */
    if (a->start > b->start)
    {
      n->start = a->start;
    }
    else
    {
      n->start = b->start;
    }
  }

  PG_RETURN_POINTER(n);
}

static void
rt_locus_size(LOCUS *a, float *size)
{
  if (a == (LOCUS *) NULL || a->start <= a->end)
    *size = 0.0;
  else
    *size = (float) Abs(a->end - a->start);

  return;
}

Datum
locus_size(PG_FUNCTION_ARGS)
{
  LOCUS *locus = PG_GETARG_LOCUS_P(0);

  PG_RETURN_INT32(Abs(locus->end - locus->start));
}


/*****************************************************************************
 *           Miscellaneous operators
 *****************************************************************************/
Datum
locus_lt(PG_FUNCTION_ARGS)
{
  int cmp = DatumGetInt32(
    DirectFunctionCall2(locus_cmp, PG_GETARG_DATUM(0), PG_GETARG_DATUM(1))
  );

  PG_RETURN_BOOL(cmp < 0);
}

Datum
locus_le(PG_FUNCTION_ARGS)
{
  int cmp = DatumGetInt32(
    DirectFunctionCall2(locus_cmp, PG_GETARG_DATUM(0), PG_GETARG_DATUM(1))
  );

  PG_RETURN_BOOL(cmp <= 0);
}

Datum
locus_gt(PG_FUNCTION_ARGS)
{
  int cmp = DatumGetInt32(
    DirectFunctionCall2(locus_cmp, PG_GETARG_DATUM(0), PG_GETARG_DATUM(1))
  );

  PG_RETURN_BOOL(cmp > 0);
}

Datum
locus_ge(PG_FUNCTION_ARGS)
{
  int cmp = DatumGetInt32(
    DirectFunctionCall2(locus_cmp, PG_GETARG_DATUM(0), PG_GETARG_DATUM(1))
  );

  PG_RETURN_BOOL(cmp >= 0);
}


Datum
locus_different(PG_FUNCTION_ARGS)
{
  int cmp = DatumGetInt32(
    DirectFunctionCall2(locus_cmp, PG_GETARG_DATUM(0), PG_GETARG_DATUM(1))
  );

  PG_RETURN_BOOL(cmp != 0);
}

