--
--  Locus datatype test
--

CREATE EXTENSION locus;

-- Check whether any of our opclasses fail amvalidate
SELECT amname, opcname
  FROM (SELECT amname, opcname, opc.oid
          FROM pg_opclass opc
               LEFT JOIN pg_am am ON am.oid = opcmethod
         WHERE opc.oid >= 16384
         ORDER BY 1, 2 OFFSET 0) ss
 WHERE NOT amvalidate(oid);
--
-- Testing the input and output functions
--

-- Whole contig
SELECT '1'::locus AS locus;
SELECT 'chr1'::locus AS locus;
SELECT 'GL383557.1'::locus AS locus;

-- Point position
SELECT '16:89831249'::locus AS locus;
SELECT ' 16 : 89831249 '::locus AS locus;
SELECT ' 16	:	89831249 '::locus AS locus;
SELECT '16:89,831,249'::locus AS locus;
SELECT ' 16 : 89,831,249 '::locus AS locus;
SELECT ' 16	:	89,831,249 '::locus AS locus;
SELECT 'chr16:89831249'::locus AS locus;
SELECT ' chr16 : 89831249 '::locus AS locus;
SELECT ' chr16	:	89831249 '::locus AS locus;
SELECT 'chr16:89,831,249'::locus AS locus;
SELECT ' chr16 : 89,831,249 '::locus AS locus;
SELECT ' chr16	:	89,831,249 '::locus AS locus;

-- Ranges
SELECT 'GL383557.1:100-500'::locus AS locus;
SELECT '16:89831249-89831439'::locus AS locus;
SELECT ' 16 : 89831249 - 89831439 '::locus AS locus;
SELECT ' 16 : 89831249	-	89831439 '::locus AS locus;
SELECT '16:89,831,249-89,831,439'::locus AS locus;
SELECT 'chr16:89831249-89831439'::locus AS locus;
SELECT 'chr16:89,831,249-89,831,439'::locus AS locus;

-- Open intervals
SELECT '16:1000000-'::locus AS locus;
SELECT 'chr16:1000000-'::locus AS locus;
SELECT 'chr16:1,000,000-'::locus AS locus;
SELECT '16:-89831249'::locus AS locus;
SELECT 'chr16:-89831249'::locus AS locus;
SELECT 'chr16:-89,831,249'::locus AS locus;

-- invalid input
SELECT 'ENST00000378344.2|ENSG00000158109.10'::locus AS locus;
SELECT 'ENST00000378344.2|ENSG00000158109.10:340'::locus AS locus;
SELECT 'chr16:89831249000000000000000000'::locus AS locus;
SELECT 'chr16:89831249000000'::locus AS locus;
SELECT '16:8983 1249-89831439'::locus AS locus;
SELECT '16:89831249-898 31439'::locus AS locus;
SELECT '16:89831249-89831,439'::locus AS locus;
SELECT 'chr16:garbage-89831249'::locus AS locus;

-- Testng accessors
SELECT contig('7:10000-20000'::locus);
SELECT contig('chr7:10000-20000'::locus);
SELECT lower('7:10000-20000'::locus);
SELECT upper('7:10000-20000'::locus);
SELECT length('7:10000-20000'::locus);
SELECT range('7:10000-20000'::locus);
SELECT center('7:10000-20000'::locus);

SELECT lower('7:10000'::locus);
SELECT upper('7:10000'::locus);
SELECT length('7:10000'::locus);
SELECT range('7:10000'::locus);
SELECT center('7:10000'::locus);

SELECT lower('7'::locus);
SELECT upper('7'::locus);
SELECT length('7'::locus);
SELECT range('7'::locus);
SELECT center('7'::locus);

-- Teting the comparator
--
select locus_cmp('chr6', 'chr21');
select locus_cmp('chr6:29474946-29475446'::locus, 'chr21:29474869-29475900');
select locus_cmp('chr6:29474946-29475446'::locus, 'chr6:28474869-29475900');

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


-- Load some example data and build the index
--
CREATE TABLE test_locus (p locus);
\copy test_locus from 'data/test_locus.data'
CREATE INDEX test_locus_ix ON test_locus USING gist (p);
--
-- Test operators on the table
SELECT count(*) FROM test_locus WHERE p && '21';
SELECT count(*) FROM test_locus WHERE p && 'chr21:10600000-12608058';
SELECT count(*) FROM test_locus WHERE p <& 'chr21:28800000-30000000';
SELECT count(*) FROM test_locus WHERE p << 'chr21:28800000-30000000';
SELECT count(*) FROM test_locus WHERE p >> 'chr21:28800000-30000000';
SELECT count(*) FROM test_locus WHERE p &> 'chr21:28800000-30000000';
SELECT count(*) FROM test_locus WHERE p <@ 'chr21:28800000-30000000';
SELECT count(*) FROM test_locus WHERE p <@ '<all>:28800000-30000000';

-- Test sorting
SELECT * FROM test_locus WHERE range(p) && '[29475000, 29475000]' ORDER by p;

-- Test lower, upper, and center functions
SELECT p, lower(p), center(p), upper(p) FROM test_locus WHERE length(p) > 100 limit 6;
