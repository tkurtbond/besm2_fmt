--  besm2_fmt - convert a YAML BESM 2E character/template/item file
--  into reStructuredText. Ada port of besm2-rst.scm.
--
--  All four output formats are implemented: grid (the default), terse
--  (-t/--terse), h-m-m (-H/--hmm), and raw-ms (-m/--raw-ms-tables).

with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Arg_Parser;
with Libfyaml;
with Libfyaml.Documents;
with Libfyaml.Documents.Streams;
with Libfyaml.Nodes;
with BESM2_Fmt.Cli;
with BESM2_Fmt.Config;
with BESM2_Fmt.Entities;
with BESM2_Fmt.Format_Grid;
with BESM2_Fmt.Format_Hmm;
with BESM2_Fmt.Format_Raw_Ms;
with BESM2_Fmt.Format_Terse;

procedure BESM2_Fmt_Main is

   package Config renames BESM2_Fmt.Config;
   package Doc renames Libfyaml.Documents;
   package Streams renames Libfyaml.Documents.Streams;
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

   --  Count is threaded across every document in the file (not reset
   --  per document): Entity_No is 1 for the first entity in a *file*,
   --  2 for the second, etc., regardless of how many "---"-separated
   --  YAML documents that file is split into.
   procedure Process_Entities
     (D : Doc.Document; Source : String; Count : in out Natural)
   is
      Root : constant Nod.Node := D.Root;

      procedure Visit (Item : Nod.Node) is
         E : constant BESM2_Fmt.Entities.Entity :=
           BESM2_Fmt.Entities.Load_Entity (Item);
      begin
         Count := Count + 1;
         case Config.Format is
            when Config.Terse   => BESM2_Fmt.Format_Terse.Process_Entity (E, Count);
            when Config.Grid    => BESM2_Fmt.Format_Grid.Process_Entity (E, Count);
            when Config.Hmm     => BESM2_Fmt.Format_Hmm.Process_Entity (E, Count);
            when Config.Raw_Ms  => BESM2_Fmt.Format_Raw_Ms.Process_Entity (E, Count);
         end case;
      end Visit;
   begin
      if not Root.Is_Valid or else not Root.Is_Sequence then
         raise Program_Error with
           "expected a top-level YAML sequence of entities in " & Source;
      end if;
      Root.Iterate (Visit'Access);
   end Process_Entities;

   --  It is a file of possibly multiple entities, possibly spread
   --  across multiple "---"-separated YAML documents. Matches
   --  besm2-rst.scm's process-file: on error, report it and move on
   --  to the next file rather than aborting the whole run.
   procedure Process_One (Filename : String; Use_Stdin : Boolean) is
      Source : constant String := (if Use_Stdin then "(stdin)" else Filename);
      Count  : Natural := 0;
   begin
      declare
         Stream : Streams.Document_Stream :=
           (if Use_Stdin
            then Streams.Open_String (Read_All_Standard_Input)
            else Streams.Open_File (Filename));
      begin
         while Streams.Has_Next (Stream) loop
            Process_Entities (Streams.Next (Stream), Source, Count);
         end loop;
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

   --  besm2-rst.scm's `main`: "(when (and *hmm-output* *hmm-root*) (show
   --  #t (indent) *hmm-root* nl))", run once per program invocation (not
   --  once per entity -- BESM2_Fmt.Format_Hmm.Process_Entity never sees
   --  this), and -- because it runs before the -o/--output redirection
   --  below, exactly like the Scheme's own ordering -- always to
   --  standard output, even when -o sends everything else to a file.
   --  Confirmed against the real besm2-rst binary: this is faithfully
   --  ported as-is, not a bug to route around.
   if Config.Hmm_Output and then Config.Hmm_Root /= null then
      Ada.Text_IO.Put_Line
        (String'(1 .. Config.Hmm_Depth => ASCII.HT) & Config.Hmm_Root.all);
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
