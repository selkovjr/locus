--
--  Locus datatype test
--
-- Testing the comparator
--
select locus_cmp('chr6', 'chr21');
select locus_cmp('chr6:29474946-29475446'::locus, 'chr21:29474869-29475900');
select locus_cmp('chr6:29474946-29475446'::locus, 'chr6:28474869-29475900');
