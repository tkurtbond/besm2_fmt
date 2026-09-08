--  BESM2_Fmt.Format_Raw_Ms - the raw groff `tbl` output format
--  (-m/--raw-ms-tables): a single `.TS`/`.TE` table per entity, one
--  `.. raw:: ms` reST block, groff `tbl` markup (`\fB`/`\fI` bold/
--  italics, `T{`/`T}` text blocks) instead of reST syntax. Ada port
--  of besm2-rst.scm's process-entity-raw-ms and its
--  process-stat-raw-ms/process-derived-raw-ms/process-attribute-raw-ms/
--  process-defect-raw-ms/process-skill-raw-ms.

with BESM2_Fmt.Entities;

package BESM2_Fmt.Format_Raw_Ms is

   procedure Process_Entity (E : Entities.Entity; Entity_No : Positive);
   --  Writes E to Ada.Text_IO.Current_Output (redirect with
   --  Ada.Text_IO.Set_Output for -o/--output, matching besm2-rst.scm's
   --  with-output-to-file). Entity_No is 1 for the first entity in a
   --  file, 2 for the second, etc. -- it selects between Underliner
   --  and Subunderliner for the header underline, same as
   --  BESM2_Fmt.Format_Grid/Format_Terse.
   --
   --  Unlike Format_Grid, this needs no BESM2_Fmt.Text_Layout column
   --  layout at all beyond Bold/Italics for the plain-reST portion
   --  before the table (entity name/tagline/description/size) --
   --  `tbl` itself handles column widths and text wrapping at render
   --  time via the "x" (expand) column modifier and "T{...T}" text
   --  blocks, so there is nothing here for a fixed-width renderer to
   --  do.

end BESM2_Fmt.Format_Raw_Ms;
