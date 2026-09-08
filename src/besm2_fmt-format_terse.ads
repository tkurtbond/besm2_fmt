--  BESM2_Fmt.Format_Terse - the terse output format used in BESM 1E
--  and 2E products. Ada port of besm2-rst.scm's process-entity-terse
--  and its helpers.

with BESM2_Fmt.Entities;

package BESM2_Fmt.Format_Terse is

   procedure Process_Entity (E : Entities.Entity; Entity_No : Positive);
   --  Writes E to Ada.Text_IO.Current_Output (redirect with
   --  Ada.Text_IO.Set_Output for -o/--output, matching besm2-rst.scm's
   --  with-output-to-file). Entity_No is 1 for the first entity in a
   --  file, 2 for the second, etc. -- it selects between Underliner
   --  and Subunderliner for the header underline.

end BESM2_Fmt.Format_Terse;
