--
--  Locus datatype test
--
-- Testng accessors
--
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
