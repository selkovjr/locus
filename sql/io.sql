--
--  Locus datatype test
--
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
