--  besm2_fmt - convert a YAML BESM 2E character/template/item file
--  into reStructuredText. Ada port of besm2-rst.scm.
--
--  Only terse output (-t/--terse) is implemented so far (PLAN.md's
--  build order puts it first: it needs no column-layout code). Grid,
--  h-m-m, and raw-ms output are not yet -- selecting them reports
--  "not yet implemented" and exits, rather than silently falling back
--  to terse.

with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Arg_Parser;
with Libfyaml;
with Libfyaml.Documents;
with Libfyaml.Nodes;
with BESM2_Fmt.Cli;
with BESM2_Fmt.Config;
with BESM2_Fmt.Entities;
with BESM2_Fmt.Format_Terse;

procedure BESM2_Fmt_Main is

   package Config renames BESM2_Fmt.Config;
   package Doc renames Libfyaml.Documents;
   package Nod renames Libfyaml.Nodes;

   use type Arg_Parser.String_Reference;
   use type Config.Output_Format;

   function Read_All_Standard_Input return String is
      Buffer : Unbounded_String;
   begin
      while not Ada.Text_IO.End_Of_File loop
         Append (Buffer, Ada.Text_IO.Get_Line);
         Append (Buffer, ASCII.LF);
      end loop;
      return To_String (Buffer);
   end Read_All_Standard_Input;

   procedure Process_Entities (D : Doc.Document; Source : String) is
      Root  : constant Nod.Node := D.Root;
      Count : Natural := 0;

      procedure Visit (Item : Nod.Node) is
         E : constant BESM2_Fmt.Entities.Entity :=
           BESM2_Fmt.Entities.Load_Entity (Item);
      begin
         Count := Count + 1;
         BESM2_Fmt.Format_Terse.Process_Entity (E, Count);
      end Visit;
   begin
      if not Root.Is_Valid or else not Root.Is_Sequence then
         raise Program_Error with
           "expected a top-level YAML sequence of entities in " & Source;
      end if;
      Root.Iterate (Visit'Access);
   end Process_Entities;

   --  It is a file of possibly multiple entities. Matches
   --  besm2-rst.scm's process-file: on error, report it and move on
   --  to the next file rather than aborting the whole run.
   procedure Process_One (Filename : String; Use_Stdin : Boolean) is
      Source : constant String := (if Use_Stdin then "(stdin)" else Filename);
   begin
      declare
         D : constant Doc.Document :=
           (if Use_Stdin
            then Doc.Parse_String (Read_All_Standard_Input)
            else Doc.Parse_File (Filename));
      begin
         Process_Entities (D, Source);
      end;
   exception
      when E : Libfyaml.Parse_Error | Libfyaml.Missing_Key | Libfyaml.Data_Error |
               Program_Error =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "besm2_fmt: error processing " & Source & ": " &
            Ada.Exceptions.Exception_Message (E));
   end Process_One;

   procedure Process_All is
   begin
      if BESM2_Fmt.Cli.Filenames.Is_Empty then
         Process_One ("", True);
      else
         for F of BESM2_Fmt.Cli.Filenames loop
            Process_One (To_String (F), False);
         end loop;
      end if;
   end Process_All;

begin
   BESM2_Fmt.Cli.Parse;

   if Config.Format /= Config.Terse then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "besm2_fmt: only terse output (-t/--terse) is implemented so far");
      Ada.Command_Line.Set_Exit_Status (1);
      return;
   end if;

   if Config.Output_File /= null then
      declare
         Output_File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create
           (Output_File, Ada.Text_IO.Out_File, Config.Output_File.all);
         Ada.Text_IO.Set_Output (Output_File);
         Process_All;
         Ada.Text_IO.Set_Output (Ada.Text_IO.Standard_Output);
         Ada.Text_IO.Close (Output_File);
      end;
   else
      Process_All;
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
