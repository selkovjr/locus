--
--  Test locus datatype
--

CREATE EXTENSION locus;

-- Check whether any of our opclasses fail amvalidate
SELECT amname, opcname
FROM pg_opclass opc LEFT JOIN pg_am am ON am.oid = opcmethod
WHERE opc.oid >= 16384 AND NOT amvalidate(opc.oid);

--
-- testing input and output functions
--

-- Single position
SELECT '1:7980977'::locus AS locus;
SELECT 'chr1:7980977'::locus AS locus;

-- Interval
SELECT 'X:66765034-66765260'::locus AS locus;

-- invalid input
SELECT 'X:66765260-66765034'::locus AS locus;
SELECT '66765260-66765034'::locus AS locus;
SELECT '66765034'::locus AS locus;
SELECT 'chr1:a7980977-7980978'::locus AS locus;
SELECT 'chr1:7980977-a7980978'::locus AS locus;
SELECT 'chr1:7980977a7980978'::locus AS locus;
SELECT 'chr1:7980977-798a0978'::locus AS locus;

--
-- testing the  operators
--

-- equality/inequality:
--
SELECT '5:170827137-170827174'::locus = '5:170827137-170827174'::locus AS bool;
SELECT '5:170827137-170827174'::locus = '5:170827137-170827175'::locus AS bool;
SELECT '5:170827137-170827174'::locus != '5:170827137-170827174'::locus AS bool;
SELECT '5:170827137-170827174'::locus != '5:170827137-170827175'::locus AS bool;
SELECT '5:170827137'::locus = '5:170827137-170827137'::locus AS bool;
SELECT '5:170827137'::locus != '5:170827137-170827137'::locus AS bool;
SELECT '5:170827137'::locus != '5:170827137-170827174'::locus AS bool;

-- overlap
--
SELECT '1:45329242-45340925'::locus && '1:45339670-45343975'::locus AS bool; -- MUTYH, TOE1 (t)
SELECT '1:45343883-45491166'::locus && '1:45339670-45343975'::locus AS bool; -- TESK2, TOE1 (t)
SELECT '1:45343883-45491166'::locus && '1:45344840-45345558'::locus AS bool; -- TESK2, TESK2 exon 2 (t)
SELECT '1:45343883-45491166'::locus && '1:45344840'::locus AS bool; -- TESK2, TESK2 exon 2 start (t)
SELECT '1:45329242-45340925'::locus && '1:45343883-45491166'::locus AS bool; -- MUTYH, TESK2 (f)


-- ** in the following tests, "TERT promoter" is a reagion between -1000 and -500 bp from translation start


-- overlap on the left
--
SELECT '1:45329242-45340925'::locus &< '1:45339670-45343975'::locus AS bool; -- MUTYH, TOE1 (t)
SELECT '5:1252147-1252647'::locus &< '5:1253147-1295069'::locus AS bool; -- TERT promoter, TERT (f)
SELECT '5:1253147-1295069'::locus &< '5:1252147-1252647'::locus AS bool; -- TERT, TERT promoter (f)
SELECT '5:1253147-1295069'::locus &< '5:1253023'::locus AS bool; -- TERT, TERT promoter locus (f)
SELECT '5:1253147-1295069'::locus &< '5:1253147-1295069'::locus AS bool; -- self (t)
SELECT '5:1253147'::locus &< '5:1253147'::locus AS bool; -- self (t)

-- overlap on the right
--
SELECT '1:45343883-45491166'::locus &> '1:45339670-45343975'::locus AS bool; -- TESK2, TOE1 (t)
SELECT '5:1253147-1295069'::locus &> '5:1252147-1252647'::locus AS bool; -- TERT, TERT promoter (f)
SELECT '5:1253147-1295069'::locus &> '5:1253023'::locus AS bool; -- TERT, TERT promoter locus (f)
SELECT '5:1253147-1295069'::locus &> '5:1253147-1295069'::locus AS bool; -- self (t)
SELECT '5:1253147'::locus &> '5:1253147'::locus AS bool; -- self (t)

-- left
--
SELECT '1:45329242-45340925'::locus << '1:45339670-45343975'::locus AS bool; -- MUTYH, TOE1 (f)
SELECT '1:45329242-45340925'::locus << '1:45343883-45491166'::locus AS bool; -- MUTYH, TESK2 (t)
SELECT '5:1252147-1252647'::locus << '5:1253147-1295069'::locus AS bool; -- TERT promoter, TERT (t)
SELECT '5:1253147-1295069'::locus << '5:1252147-1252647'::locus AS bool; -- TERT, TERT promoter (f)
SELECT '5:1253147-1295069'::locus << '5:1253023'::locus AS bool; -- TERT, TERT promoter locus (f)
SELECT '5:1253147-1295069'::locus << '5:1253147-1295069'::locus AS bool; -- self (f)
SELECT '5:1253147'::locus << '5:1253147'::locus AS bool; -- self (f)

-- right
--
SELECT '1:45329242-45340925'::locus >> '1:45339670-45343975'::locus AS bool; -- MUTYH, TOE1 (f)
SELECT '1:45329242-45340925'::locus >> '1:45343883-45491166'::locus AS bool; -- MUTYH, TESK2 (f)
SELECT '1:45343883-45491166'::locus >> '1:45329242-45340925'::locus AS bool; -- TESK2, MUTYH, TESK2 (t)
SELECT '5:1252147-1252647'::locus >> '5:1253147-1295069'::locus AS bool; -- TERT promoter, TERT (f)
SELECT '5:1253147-1295069'::locus >> '5:1252147-1252647'::locus AS bool; -- TERT, TERT promoter (t)
SELECT '5:1253147-1295069'::locus >> '5:1253023'::locus AS bool; -- TERT, TERT promoter locus (t)
SELECT '5:1253147-1295069'::locus >> '5:1253147-1295069'::locus AS bool; -- self (f)
SELECT '5:1253147'::locus >> '5:1253147'::locus AS bool; -- self (f)


-- "contained in" (the left value fits within the interval specified in the right value):
--
SELECT '1:45329242-45340925'::locus <@ '1:45339670-45343975'::locus AS bool; -- MUTYH, TOE1 (f)
SELECT '1:45343883-45491166'::locus <@ '1:45339670-45343975'::locus AS bool; -- TESK2, TOE1 (f)
SELECT '1:45343883-45491166'::locus <@ '1:45344840-45345558'::locus AS bool; -- TESK2, TESK2 exon 2 (f)
SELECT '1:45344840-45345558'::locus <@ '1:45343883-45491166'::locus AS bool; -- TESK2 exon 2, TESK2 (t)
SELECT '1:45343883-45491166'::locus <@ '1:45344840'::locus AS bool; -- TESK2, TESK2 exon 2 start (f)
SELECT '1:45344840'::locus <@ '1:45343883-45491166'::locus AS bool; -- TESK2 exon 2 start, TESK2 (t)
SELECT '5:1253147-1295069'::locus <@ '5:1253147-1295069'::locus AS bool; -- self (t)
SELECT '5:1253147'::locus <@ '5:1253147'::locus AS bool; -- self (t)
SELECT '5:1253147'::locus <@ '5:1253147-1295069'::locus AS bool; -- self boundary (t)
SELECT '5:1295069'::locus <@ '5:1253147-1295069'::locus AS bool; -- self boundary (t)


-- "contains" (the left value contains the interval specified in the right value):
--
SELECT '1:45343883-45491166'::locus @> '1:45344840-45345558'::locus AS bool; -- TESK2, TESK2 exon 2 (t)
SELECT '1:45344840-45345558'::locus @> '1:45343883-45491166'::locus AS bool; -- TESK2 exon 2, TESK2 (f)
SELECT '1:45343883-45491166'::locus @> '1:45344840'::locus AS bool; -- TESK2, TESK2 exon 2 start (t)
SELECT '1:45344840'::locus @> '1:45343883-45491166'::locus AS bool; -- TESK2 exon 2 start, TESK2 (f)
SELECT '5:1253147-1295069'::locus @> '5:1253147-1295069'::locus AS bool; -- self (t)
SELECT '5:1253147'::locus @> '5:1253147'::locus AS bool; -- self (t)
SELECT '5:1253147-1295069'::locus @> '5:1253147'::locus AS bool; -- self boundary (t)
SELECT '5:1253147-1295069'::locus @> '5:1295069'::locus AS bool; -- self boundary (t)


-- Load some example data and build the index
--
CREATE TABLE test_locus (
  pos locus,
  ref text,
  alt text,
  id text
);

\copy test_locus from data/oncomine.hotspot.tab

-- CREATE INDEX test_locus_ix ON test_locus USING gist (pos);
SELECT count(*) FROM test_locus WHERE pos <@ 'chr3:138665254-178920634';

-- Test sorting
SELECT pos, count(*) FROM test_locus WHERE pos <@ 'chr3:178916934-178917409' GROUP BY pos;

-- Test functions
SELECT pos, locus_start(pos), locus_center(pos), locus_end(pos) FROM test_locus WHERE length(ref) > 1 limit 6;
