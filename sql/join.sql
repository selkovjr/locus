--
--  Locus datatype test
--
SELECT count(*) FROM test_locus t1 JOIN test_locus t2 ON t1.p = t2.p;
SELECT count(*) FROM test_locus t1 JOIN test_locus t2 ON t1.p && t2.p;
