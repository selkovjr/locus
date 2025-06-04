--
--  Locus datatype test
--
-- Testing general-purpose functions
--
select locus_inter('1:152280770-152280782', '1:152280773-152280785');
select locus_union('1:152280781-152280782', '1:152280773-152280785');
