/* contrib/locus/locus--0.0.1.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION locus" to load this file. \quit

-- Create the user-defined type for 1-D floating point intervals (locus)

CREATE FUNCTION locus_in(cstring)
RETURNS locus
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION locus_out(locus)
RETURNS cstring
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE TYPE locus (
  INTERNALLENGTH = 32,
  INPUT = locus_in,
  OUTPUT = locus_out
);

COMMENT ON TYPE locus IS
'genomic locus ''contig:begin-end'', ''contig:pos'', or just ''contig''';

--
-- External C-functions for R-tree methods
--

-- Left/Right methods

CREATE FUNCTION locus_over_left(locus, locus)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION locus_over_left(locus, locus) IS
'none of (a) is above the upper bound of (b)';

CREATE FUNCTION locus_over_right(locus, locus)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION locus_over_right(locus, locus) IS
'none of (a) is below the lower bound of (b)';

CREATE FUNCTION locus_left(locus, locus)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION locus_left(locus, locus) IS
'strictly left';

CREATE FUNCTION locus_right(locus, locus)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION locus_right(locus, locus) IS
'strictly right';


-- Scalar comparison methods

CREATE FUNCTION locus_lt(locus, locus)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION locus_lt(locus, locus) IS
'less than';

CREATE FUNCTION locus_le(locus, locus)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION locus_le(locus, locus) IS
'less than or equal';

CREATE FUNCTION locus_gt(locus, locus)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION locus_gt(locus, locus) IS
'greater than';

CREATE FUNCTION locus_ge(locus, locus)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION locus_ge(locus, locus) IS
'greater than or equal';

CREATE FUNCTION locus_contains(locus, locus)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION locus_contains(locus, locus) IS
'contains';

CREATE FUNCTION locus_contained(locus, locus)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION locus_contained(locus, locus) IS
'contained in';

CREATE FUNCTION locus_overlap(locus, locus)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION locus_overlap(locus, locus) IS
'overlaps';

CREATE FUNCTION locus_same(locus, locus)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION locus_same(locus, locus) IS
'same as';

CREATE FUNCTION locus_different(locus, locus)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION locus_different(locus, locus) IS
'different';

-- support routines for indexing

CREATE FUNCTION locus_cmp(locus, locus)
RETURNS int4
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION locus_cmp(locus, locus) IS 'btree comparison function';

CREATE FUNCTION locus_union(locus, locus)
RETURNS locus
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION locus_inter(locus, locus)
RETURNS locus
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION length(locus)
RETURNS int
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

-- miscellaneous

CREATE FUNCTION contig(locus)
RETURNS text
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION range(locus)
RETURNS int8range
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION center(locus)
RETURNS float4
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION upper(locus)
RETURNS int
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION lower(locus)
RETURNS int
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;


--
-- OPERATORS
--

CREATE OPERATOR < (
  LEFTARG = locus,
  RIGHTARG = locus,
  PROCEDURE = locus_lt,
  COMMUTATOR = '>',
  NEGATOR = '>=',
  RESTRICT = scalarltsel,
  JOIN = scalarltjoinsel
);

CREATE OPERATOR <= (
  LEFTARG = locus,
  RIGHTARG = locus,
  PROCEDURE = locus_le,
  COMMUTATOR = '>=',
  NEGATOR = '>',
  RESTRICT = scalarltsel,
  JOIN = scalarltjoinsel
);

CREATE OPERATOR > (
  LEFTARG = locus,
  RIGHTARG = locus,
  PROCEDURE = locus_gt,
  COMMUTATOR = '<',
  NEGATOR = '<=',
  RESTRICT = scalargtsel,
  JOIN = scalargtjoinsel
);

CREATE OPERATOR >= (
  LEFTARG = locus,
  RIGHTARG = locus,
  PROCEDURE = locus_ge,
  COMMUTATOR = '<=',
  NEGATOR = '<',
  RESTRICT = scalargtsel,
  JOIN = scalargtjoinsel
);

CREATE OPERATOR << (
  LEFTARG = locus,
  RIGHTARG = locus,
  PROCEDURE = locus_left,
  COMMUTATOR = '>>',
  RESTRICT = positionsel,
  JOIN = positionjoinsel
);

CREATE OPERATOR <& (
  LEFTARG = locus,
  RIGHTARG = locus,
  PROCEDURE = locus_over_left,
  RESTRICT = positionsel,
  JOIN = positionjoinsel
);

CREATE OPERATOR && (
  LEFTARG = locus,
  RIGHTARG = locus,
  PROCEDURE = locus_overlap,
  COMMUTATOR = '&&',
  RESTRICT = areasel,
  JOIN = areajoinsel
);

CREATE OPERATOR &> (
  LEFTARG = locus,
  RIGHTARG = locus,
  PROCEDURE = locus_over_right,
  RESTRICT = positionsel,
  JOIN = positionjoinsel
);

CREATE OPERATOR >> (
  LEFTARG = locus,
  RIGHTARG = locus,
  PROCEDURE = locus_right,
  COMMUTATOR = '<<',
  RESTRICT = positionsel,
  JOIN = positionjoinsel
);

CREATE OPERATOR = (
  LEFTARG = locus,
  RIGHTARG = locus,
  PROCEDURE = locus_same,
  COMMUTATOR = '=',
  NEGATOR = '<>',
  RESTRICT = eqsel,
  JOIN = eqjoinsel,
  MERGES
);

CREATE OPERATOR <> (
  LEFTARG = locus,
  RIGHTARG = locus,
  PROCEDURE = locus_different,
  COMMUTATOR = '<>',
  NEGATOR = '=',
  RESTRICT = neqsel,
  JOIN = neqjoinsel
);

CREATE OPERATOR @> (
  LEFTARG = locus,
  RIGHTARG = locus,
  PROCEDURE = locus_contains,
  COMMUTATOR = '<@',
  RESTRICT = contsel,
  JOIN = contjoinsel
);

CREATE OPERATOR <@ (
  LEFTARG = locus,
  RIGHTARG = locus,
  PROCEDURE = locus_contained,
  COMMUTATOR = '@>',
  RESTRICT = contsel,
  JOIN = contjoinsel
);

-- obsolete (but linked to GiST strategies):
CREATE OPERATOR @ (
  LEFTARG = locus,
  RIGHTARG = locus,
  PROCEDURE = locus_contains,
  COMMUTATOR = '~',
  RESTRICT = contsel,
  JOIN = contjoinsel
);

CREATE OPERATOR ~ (
  LEFTARG = locus,
  RIGHTARG = locus,
  PROCEDURE = locus_contained,
  COMMUTATOR = '@',
  RESTRICT = contsel,
  JOIN = contjoinsel
);

-- define GiST support methods
CREATE FUNCTION gist_locus_consistent(internal,locus,smallint,oid,internal)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION gist_locus_compress(internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION gist_locus_decompress(internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION gist_locus_penalty(internal,internal,internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION gist_locus_picksplit(internal, internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION gist_locus_union(internal, internal)
RETURNS locus
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION gist_locus_same(locus, locus, internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;


-- Create operator classes for indexing

CREATE OPERATOR CLASS locus_ops
    DEFAULT FOR TYPE locus USING btree AS
        OPERATOR        1       < ,
        OPERATOR        2       <= ,
        OPERATOR        3       = ,
        OPERATOR        4       >= ,
        OPERATOR        5       > ,
        FUNCTION        1       locus_cmp(locus, locus);

CREATE OPERATOR CLASS gist_locus_ops
DEFAULT FOR TYPE locus USING gist
AS
  OPERATOR   1 << ,
  OPERATOR   2 <& ,
  OPERATOR   3 && ,
  OPERATOR   4 &> ,
  OPERATOR   5 >> ,
  OPERATOR   6  = ,
  OPERATOR   7 @> ,
  OPERATOR   8 <@ ,
  OPERATOR  13  @ ,
  OPERATOR  14  ~ ,
  FUNCTION  1 gist_locus_consistent (internal, locus, smallint, oid, internal),
  FUNCTION  2 gist_locus_union (internal, internal),
  FUNCTION  3 gist_locus_compress (internal),
  FUNCTION  4 gist_locus_decompress (internal),
  FUNCTION  5 gist_locus_penalty (internal, internal, internal),
  FUNCTION  6 gist_locus_picksplit (internal, internal),
  FUNCTION  7 gist_locus_same (locus, locus, internal);
