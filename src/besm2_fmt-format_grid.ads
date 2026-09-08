--  BESM2_Fmt.Format_Grid - the reST grid-table output format, and
--  besm2_fmt's default (no -t/-H/-m flag needed). Ada port of
--  besm2-rst.scm's process-entity and its process-stat/process-derived/
--  process-attribute/process-defect/process-skill helpers.

with BESM2_Fmt.Entities;

package BESM2_Fmt.Format_Grid is

   procedure Process_Entity (E : Entities.Entity; Entity_No : Positive);
   --  Writes E to Ada.Text_IO.Current_Output (redirect with
   --  Ada.Text_IO.Set_Output for -o/--output, matching besm2-rst.scm's
   --  with-output-to-file). Entity_No is 1 for the first entity in a
   --  file, 2 for the second, etc. -- it selects between Underliner
   --  and Subunderliner for the header underline, same as
   --  BESM2_Fmt.Format_Terse.

end BESM2_Fmt.Format_Grid;
