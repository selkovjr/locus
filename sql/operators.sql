--
--  Locus datatype test
--
-- Testing operators
--

-- equality/inequality:
--
SELECT '2:100000-100000'::locus = 'chr20:100000'::locus AS bool;
SELECT '20:100000-100000'::locus = 'chr20:100000'::locus AS bool;
SELECT '20:100000-200000'::locus = 'chr20:100000-200000'::locus AS bool;
SELECT '20:100000-199999'::locus = '20:100000-200000'::locus AS bool;
SELECT '20:100000-199999'::locus != '20:100000-200000'::locus AS bool;
SELECT '20:100000-100000'::locus != 'chr20'::locus AS bool;
SELECT '20:100000-100000'::locus <> 'chr20'::locus AS bool;

-- overlap
--
SELECT '1'::locus && '2'::locus AS bool;
SELECT '1'::locus && 'chr1'::locus AS bool;
SELECT 'chr1'::locus && '1:10000000'::locus AS bool;
SELECT 'chr1:10000000-'::locus && '1:15000000'::locus AS bool;
SELECT 'chr1:-10000000'::locus && '1:10000000-'::locus AS bool; -- inclusive
SELECT 'chr1:-9999999'::locus && '1:10000000-'::locus AS bool; -- inclusive
SELECT 'chr1:-10000000'::locus && '1:15000000-'::locus AS bool;

-- none of A is above the upper bound of B
--
SELECT 'chr1'::locus <& 'chr2'::locus AS bool;
SELECT 'chr3'::locus <& 'chr2'::locus AS bool;
SELECT 'chr1:1'::locus <& 'chr1:0'::locus AS bool;
SELECT 'chr1:0'::locus <& 'chr1:1'::locus AS bool;
SELECT 'chr1:0-1'::locus <& 'chr1:1'::locus AS bool;
SELECT 'chr1:0-2'::locus <& 'chr1:1'::locus AS bool;
SELECT 'chr1:0-2'::locus <& 'chr1:5-30'::locus AS bool;
SELECT 'chr1:0-200'::locus <& 'chr1:5-30'::locus AS bool;
SELECT 'chr1'::locus <& 'chr1:10000'::locus AS bool; -- A spans the entire domain
SELECT 'chr1:-1001'::locus <& 'chr1:1000-'::locus AS bool;  -- the upper bound of B is insurpassable

-- none of A is below the lower bound of B
--
SELECT 'chr1'::locus &> 'chr2'::locus AS bool;
SELECT 'chr3'::locus &> 'chr2'::locus AS bool;
SELECT 'chr1:1'::locus &> 'chr1:0'::locus AS bool;
SELECT 'chr1:0'::locus &> 'chr1:1'::locus AS bool;
SELECT 'chr1:0-1'::locus &> 'chr1:1'::locus AS bool;
SELECT 'chr1:2-10'::locus &> 'chr1:1'::locus AS bool;
SELECT 'chr1:5-30'::locus &> 'chr1:1-3'::locus AS bool;
SELECT 'chr1:10000'::locus &> 'chr1'::locus AS bool; -- the lower bound of B is the lowest possible
SELECT 'chr1'::locus &> 'chr1:10000'::locus AS bool; -- Aspans the entire domain

-- left
--
SELECT 'chr1'::locus << 'chr2'::locus AS bool;
SELECT 'chr1'::locus << 'chr1'::locus AS bool;
SELECT '<all>'::locus << 'chr1'::locus AS bool;
SELECT 'chr1'::locus << '<all>'::locus AS bool;
SELECT 'chr1:1'::locus << 'chr2:0'::locus AS bool;
SELECT 'chr1:0'::locus << 'chr1:1'::locus AS bool;
SELECT 'chr1:0-1'::locus << 'chr1:1'::locus AS bool;
SELECT 'chr1:0-1'::locus << 'chr1:2'::locus AS bool;
SELECT 'chr1:0-1'::locus << 'chr1:2-'::locus AS bool;
SELECT 'chr1:0-10'::locus << 'chr1:10-20'::locus AS bool;
SELECT 'chr1:-1000'::locus << 'chr1:2000-'::locus AS bool;

-- right
--
SELECT 'chr2'::locus >> 'chr1'::locus AS bool;
SELECT 'chr1'::locus >> 'chr1'::locus AS bool;
SELECT '<all>'::locus >> 'chr1'::locus AS bool;
SELECT 'chr1'::locus >> '<all>'::locus AS bool;
SELECT 'chr2:0'::locus >> 'chr1:1'::locus AS bool;
SELECT 'chr1:1'::locus >> 'chr1:0'::locus AS bool;
SELECT 'chr1:1-2'::locus >> 'chr1:0-1'::locus AS bool;
SELECT 'chr1:2-'::locus >> 'chr1:0-1'::locus AS bool;
SELECT 'chr1:10-20'::locus >> 'chr1:0-10'::locus AS bool;
SELECT 'chr1:2000-'::locus >> 'chr1:-1000'::locus AS bool;

-- "contained in" (the left value belongs within the interval specified in the right value):

SELECT 'chr1'::locus <@ '<all>'::locus AS bool;
SELECT 'chr1'::locus <@ 'chr1'::locus AS bool;
SELECT 'chr2'::locus <@ 'chr1'::locus AS bool;
SELECT 'chr1:1000-'::locus <@ 'chr1'::locus AS bool;
SELECT 'chr1:-999'::locus <@ 'chr1:1000-'::locus AS bool;
SELECT 'chr1:200-500'::locus <@ 'chr1:100-900'::locus AS bool;
SELECT 'chr7:200-500'::locus <@ 'chr1:100-900'::locus AS bool;
SELECT 'chr1:200-500'::locus <@ '<all>:100-900'::locus AS bool;
SELECT 'chr1:100-900'::locus <@ '<all>:200-500'::locus AS bool;
SELECT '<all>:200-500'::locus <@ 'chr1:100-900'::locus AS bool;

-- "contains" (the left value contains the interval specified in the right value):
--
SELECT '<all>'::locus @> 'chr1'::locus AS bool;
SELECT 'chr1'::locus @> 'chr1'::locus AS bool;
SELECT 'chr2'::locus @> 'chr1'::locus AS bool;
SELECT 'chr1'::locus @> 'chr1:1000-'::locus AS bool;
SELECT 'chr1:-900'::locus @> 'chr1:1000-'::locus AS bool;
SELECT 'chr1:100-900'::locus @> 'chr1:200-500'::locus AS bool;
SELECT 'chr7:100-900'::locus @> 'chr1:200-500'::locus AS bool;
SELECT '<all>:100-900'::locus @> 'chr1:200-500'::locus AS bool;
SELECT '<all>:200-500'::locus @> 'chr1:100-900'::locus AS bool;
SELECT 'chr1:100-900'::locus @> '<all>:200-500'::locus AS bool;
