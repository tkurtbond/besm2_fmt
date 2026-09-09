--  BESM2_Fmt.Config - CLI-settable global configuration.
--
--  A direct port of besm2-rst.scm's top-level `*star*` specials
--  (design.md's "was the *star* specials"). Populated by
--  BESM2_Fmt.Cli.Parse from the command line; consumed by the (not
--  yet implemented) format backends.
--
--  Fields are `aliased` so BESM2_Fmt.Cli can point Arg_Parser options
--  at them via `'Access`, per Arg_Parser's Make_Set_*_Option family
--  (see its README and examples/src/simple2_args.ads for the pattern
--  this follows).

with Arg_Parser;

package BESM2_Fmt.Config is

   type Output_Format is (Grid, Terse, Hmm, Raw_Ms);
   --  Grid (the default: reST grid tables, process-entity in the
   --  Scheme) plus the three CLI-selectable alternates: -t/--terse,
   --  -H/--hmm, -m/--raw-ms-tables. Whichever flag was given last on
   --  the command line wins, matching the Scheme's own repeated
   --  "(set! *output-formatter* ...)" semantics.

   Format : aliased Output_Format := Grid;

   -----------------------------------------------------------------
   --  Plain boolean flags (Arg_Parser sets these directly, via
   --  Make_Set_Boolean_True_Option / _False_Option -- no handler
   --  function needed for any of these).
   -----------------------------------------------------------------

   One_Table                : aliased Boolean := False;  -- -1/--one
   Bold_Head                 : aliased Boolean := True;   -- -B/--no-bold-head clears this
   Bolding                   : aliased Boolean := False;  -- -b/--bold
   Omit_Entity_Description   : aliased Boolean := False;  -- -D/--omit-description
   Debugging                  : aliased Boolean := False;  -- -d/--debug
   Hmm_Output                 : aliased Boolean := False;  -- also set by -H (see BESM2_Fmt.Cli)
   Hmm_Separate                : aliased Boolean := False;  -- -S/--hmm-separate
   Italicizing                 : aliased Boolean := False;  -- -i/--italics
   Level                       : aliased Boolean := False;  -- -l/--level
   Em_Dash                     : aliased Boolean := False;  -- -M/--em-dash
   Page_After_Description      : aliased Boolean := False;  -- -p/--page
   Show_Subtotals               : aliased Boolean := False;  -- -s/--subtotals
   Unicode_Minus                : aliased Boolean := True;  -- -n/--no-unicode-minus clears this

   -----------------------------------------------------------------
   --  Required-argument options.
   -----------------------------------------------------------------

   Hmm_Depth   : aliased Natural := 0;    -- -L/--hmm-depth
   Table_Width : aliased Positive := 60;  -- -w/--width

   Hmm_Root    : aliased Arg_Parser.String_Reference;  -- -R/--hmm-root; null = unset
   Output_File : aliased Arg_Parser.String_Reference;  -- -o/--output; null = unset (stdout)

   Underliner    : aliased Character := '-';        -- -u/--underliner
   Subunderliner : aliased Character := ASCII.NUL;  -- -U/--subunderliner; NUL = unset

   -----------------------------------------------------------------
   --  Derived from -1/--one, not independently settable (see the -1
   --  handler in BESM2_Fmt.Cli): a single header-separator line looks
   --  like a real header in HTML output when there's only one table,
   --  a repeated one doesn't.
   -----------------------------------------------------------------

   Head_Sep : aliased Character := '=';

end BESM2_Fmt.Config;
