--
--  Locus datatype test
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
SELECT DISTINCT p, lower(p), center(p), upper(p) FROM test_locus WHERE length(p) > 10000 AND contig(p) IN ('13', '21', 'X') ORDER BY p;
