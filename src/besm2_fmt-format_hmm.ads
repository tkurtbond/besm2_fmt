--  BESM2_Fmt.Format_Hmm - the h-m-m output format (-H/--hmm): a
--  tab-indented outline, one node per line. Ada port of
--  besm2-rst.scm's process-entity-hmm and its process-stat-hmm/
--  process-derived-hmm/process-attribute-hmm/process-defect-hmm/
--  process-skill-hmm.

with BESM2_Fmt.Entities;

package BESM2_Fmt.Format_Hmm is

   procedure Process_Entity (E : Entities.Entity; Entity_No : Positive);
   --  Writes E to Ada.Text_IO.Current_Output (redirect with
   --  Ada.Text_IO.Set_Output for -o/--output, matching besm2-rst.scm's
   --  with-output-to-file). Entity_No is accepted only for signature
   --  parity with BESM2_Fmt.Format_Terse/Format_Grid's dispatch call
   --  site -- unlike those two, besm2-rst.scm's process-entity-hmm
   --  never actually uses its entity-no parameter (no header-underline
   --  concept exists in a tab-indented outline), so it's unreferenced
   --  here too.
   --
   --  Indentation depth starts at Config.Hmm_Depth (-L/--hmm-depth,
   --  default 0) for every entity -- besm2-rst.scm's *hmm-depth* is a
   --  SRFI-39 parameter, and each depth+ increment inside
   --  process-entity-hmm is a `parameterize`, whose dynamic extent
   --  ends (reverting to the Config.Hmm_Depth baseline) before the
   --  next entity is processed. It does not accumulate across
   --  entities in the same file.
   --
   --  The -R/--hmm-root root-node line (besm2-rst.scm's
   --  "(when (and *hmm-output* *hmm-root*) ...)" in `main`) is not
   --  part of this procedure -- it is printed once per program run,
   --  not once per entity, so BESM2_Fmt_Main handles it directly. See
   --  BESM2_Fmt_Main's comment on that for a real, faithfully-ported
   --  quirk: it always goes to standard output, even under
   --  -o/--output.

end BESM2_Fmt.Format_Hmm;
