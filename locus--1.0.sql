/* contrib/locus/locus--1.1.sql */

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
  INTERNALLENGTH = variable,
  INPUT = locus_in,
  OUTPUT = locus_out
);

COMMENT ON TYPE locus IS
'genomic locus, e.g., ''1:78432658'', ''chr1:78432658'', ''X:66765034-66765260''';

--
-- External C-functions for R-tree methods
--

-- Left/Right methods

CREATE FUNCTION locus_over_left(locus, locus)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION locus_over_left(locus, locus) IS
'overlaps or is left of';

CREATE FUNCTION locus_over_right(locus, locus)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION locus_over_right(locus, locus) IS
'overlaps or is right of';

CREATE FUNCTION locus_left(locus, locus)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION locus_left(locus, locus) IS
'is left of';

CREATE FUNCTION locus_right(locus, locus)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION locus_right(locus, locus) IS
'is right of';


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

CREATE FUNCTION locus_coord_cmp(locus, locus)
RETURNS int4
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION locus_coord_cmp(locus, locus) IS 'r-tree comparison function';

CREATE FUNCTION locus_union(locus, locus)
RETURNS locus
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION locus_inter(locus, locus)
RETURNS locus
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION locus_size(locus)
RETURNS int4
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

-- miscellaneous

CREATE FUNCTION locus_start(locus)
RETURNS locus
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION locus_start_pos(locus)
RETURNS int4
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;


CREATE FUNCTION locus_center(locus)
RETURNS locus
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;


CREATE FUNCTION locus_end(locus)
RETURNS locus
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE PARALLEL SAFE;

CREATE FUNCTION locus_end_pos(locus)
RETURNS int4
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

CREATE OPERATOR &< (
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

-- obsolete:
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


-- define the GiST support methods
CREATE FUNCTION glocus_consistent(internal,locus,smallint,oid,internal)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION glocus_compress(internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION glocus_decompress(internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION glocus_penalty(internal,internal,internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION glocus_picksplit(internal, internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION glocus_union(internal, internal)
RETURNS locus
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION glocus_same(locus, locus, internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;


-- Create the operator classes for indexing

CREATE OPERATOR CLASS locus_ops
    DEFAULT FOR TYPE locus USING btree AS
        OPERATOR        1       < ,
        OPERATOR        2       <= ,
        OPERATOR        3       = ,
        OPERATOR        4       >= ,
        OPERATOR        5       > ,
        FUNCTION        1       locus_coord_cmp(locus, locus);

CREATE OPERATOR CLASS gist_locus_ops
DEFAULT FOR TYPE locus USING gist
AS
  OPERATOR  1 << ,
  OPERATOR  2 &< ,
  OPERATOR  3 && ,
  OPERATOR  4 &> ,
  OPERATOR  5 >> ,
  OPERATOR  6 = ,
  OPERATOR  7 @> ,
  OPERATOR  8 <@ ,
  OPERATOR  13  @ ,
  OPERATOR  14  ~ ,
  FUNCTION  1 glocus_consistent (internal, locus, smallint, oid, internal),
  FUNCTION  2 glocus_union (internal, internal),
  FUNCTION  3 glocus_compress (internal),
  FUNCTION  4 glocus_decompress (internal),
  FUNCTION  5 glocus_penalty (internal, internal, internal),
  FUNCTION  6 glocus_picksplit (internal, internal),
  FUNCTION  7 glocus_same (locus, locus, internal);
