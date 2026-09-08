--  besm2_fmt - convert a YAML BESM 2E character/template/item file
--  into reStructuredText. Ada port of besm2-rst.scm.
--
--  CLI parsing is implemented (BESM2_Fmt.Cli, on Arg_Parser); the
--  YAML-reading and format-backend pieces (PLAN.md sections 2-4) are
--  not yet, so this just reports the parsed configuration as a
--  placeholder for the real pipeline described in besm2-rst.scm's own
--  main (adjust the table-width bold-markup allowance, print
--  Config.Hmm_Root when in hmm mode, then process each of
--  BESM2_Fmt.Cli.Filenames -- or standard input if there are none --
--  through the selected BESM2_Fmt.Config.Format backend).

with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO;
with Ada.Strings.Unbounded;
with Arg_Parser;
with BESM2_Fmt.Cli;
with BESM2_Fmt.Config;

procedure BESM2_Fmt_Main is

   package Config renames BESM2_Fmt.Config;

   use type Arg_Parser.String_Reference;

   function Image (Ref : Arg_Parser.String_Reference) return String is
     (if Ref = null then "(unset)" else '"' & Ref.all & '"');

   function Image (C : Character) return String is
     (if C = ASCII.NUL then "(unset)" else "'" & C & "'");

begin
   BESM2_Fmt.Cli.Parse;

   Ada.Text_IO.Put_Line ("Parsed configuration:");
   Ada.Text_IO.Put_Line ("  Format                   = " & Config.Format'Image);
   Ada.Text_IO.Put_Line ("  One_Table                = " & Config.One_Table'Image);
   Ada.Text_IO.Put_Line ("  Head_Sep                 = '" & Config.Head_Sep & "'");
   Ada.Text_IO.Put_Line ("  Bold_Head                = " & Config.Bold_Head'Image);
   Ada.Text_IO.Put_Line ("  Bolding                  = " & Config.Bolding'Image);
   Ada.Text_IO.Put_Line ("  Italicizing              = " & Config.Italicizing'Image);
   Ada.Text_IO.Put_Line ("  Em_Dash                  = " & Config.Em_Dash'Image);
   Ada.Text_IO.Put_Line ("  Level                    = " & Config.Level'Image);
   Ada.Text_IO.Put_Line ("  Omit_Entity_Description  = " &
                         Config.Omit_Entity_Description'Image);
   Ada.Text_IO.Put_Line ("  Page_After_Description   = " &
                         Config.Page_After_Description'Image);
   Ada.Text_IO.Put_Line ("  Show_Subtotals           = " & Config.Show_Subtotals'Image);
   Ada.Text_IO.Put_Line ("  Debugging                = " & Config.Debugging'Image);
   Ada.Text_IO.Put_Line ("  Table_Width              = " & Config.Table_Width'Image);
   Ada.Text_IO.Put_Line ("  Underliner               = " & Image (Config.Underliner));
   Ada.Text_IO.Put_Line ("  Subunderliner            = " & Image (Config.Subunderliner));
   Ada.Text_IO.Put_Line ("  Hmm_Output               = " & Config.Hmm_Output'Image);
   Ada.Text_IO.Put_Line ("  Hmm_Depth                = " & Config.Hmm_Depth'Image);
   Ada.Text_IO.Put_Line ("  Hmm_Root                 = " & Image (Config.Hmm_Root));
   Ada.Text_IO.Put_Line ("  Hmm_Separate             = " & Config.Hmm_Separate'Image);
   Ada.Text_IO.Put_Line ("  Output_File              = " & Image (Config.Output_File));

   if BESM2_Fmt.Cli.Filenames.Is_Empty then
      Ada.Text_IO.Put_Line ("  Filenames                = (none -- would read stdin)");
   else
      for F of BESM2_Fmt.Cli.Filenames loop
         Ada.Text_IO.Put_Line
           ("  Filename                 : " & Ada.Strings.Unbounded.To_String (F));
      end loop;
   end if;

exception
   when BESM2_Fmt.Cli.Help_Requested =>
      --  Matches besm2-rst.scm's `usage`, which always exits 1.
      Ada.Command_Line.Set_Exit_Status (1);

   when E : Arg_Parser.Unknown_Option | Arg_Parser.Unknown_Argument |
            Arg_Parser.Argument_Required | Arg_Parser.Invalid_Option_Argument =>
      --  Arg_Parser prints its own diagnostic for these before
      --  propagating (see e.g. "Unknown option --bogus" above); this
      --  just gives a clean exit instead of an unhandled-exception
      --  trace. Matches besm2-rst.scm's `die` convention of exiting 2
      --  on a user-input error.
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "besm2_fmt: " & Ada.Exceptions.Exception_Message (E));
      Ada.Command_Line.Set_Exit_Status (2);

   when Constraint_Error =>
      --  From Arg_Parser's numeric options (Make_Set_Natural_Option,
      --  Make_Set_Positive_Option) when the argument isn't a valid
      --  number, or is out of the option's configured range.
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "besm2_fmt: invalid numeric option argument");
      Ada.Command_Line.Set_Exit_Status (2);
end BESM2_Fmt_Main;
