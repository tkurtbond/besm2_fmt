--  BESM2_Fmt.Cli - command-line argument parsing, built on Arg_Parser
--  (https://github.com/tkurtbond/arg_parser). See PLAN.md section 5.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Arg_Parser;
with BESM2_Fmt.Config;

package BESM2_Fmt.Cli is

   package Filename_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Ada.Strings.Unbounded.Unbounded_String,
      "="          => Ada.Strings.Unbounded."=");

   Filenames : Filename_Vectors.Vector;
   --  Populated by Parse below, in command-line order: the operand
   --  filenames to process. Empty means "read from stdin", matching
   --  besm2-rst.scm's main.

   Help_Requested : exception;
   --  Raised by Parse after printing the usage message. Matches
   --  besm2-rst.scm's `usage`, which always calls `(exit 1)` -- even
   --  when it's -h/--help that asked for it, not a parse error -- so
   --  callers should exit with status 1 on this exception, not 0.

   procedure Parse;
   --  Parse Ada.Command_Line's arguments, populating BESM2_Fmt.Config
   --  and Filenames.

private

   --  Handler specs live here (bodies in the package body) rather than
   --  entirely in the body, specifically so Do_Help's body can name
   --  The_Parser below: package bodies see their whole spec regardless
   --  of intra-spec order, but a name used in one body-level
   --  declaration's initializer must already be declared earlier in
   --  that same declarative part -- and Do_Help (needed by Options,
   --  which The_Parser is built from) needs to name The_Parser itself.
   --  Follows Arg_Parser's own examples/src/simple2_args.ads, which
   --  has exactly this same shape for the same reason.

   function Do_One return Boolean;
   function Do_Hmm return Boolean;
   function Do_Raw_Ms return Boolean;
   function Do_Terse return Boolean;
   function Do_Help return Boolean;
   function Do_Subunderliner (Arg : String) return Boolean;
   function Do_Underliner (Arg : String) return Boolean;
   function Do_Argument (Start_With : Positive; Arg : String) return Boolean;

   --  A direct port of besm2-rst.scm's +command-line-options+.
   Options : aliased Arg_Parser.Option_Array :=
     (Arg_Parser.Make_Option
        (Description => "Use only one table.",
         Short_Name  => '1',
         Long_Name   => "one",
         Handler     => Do_One'Access),
      Arg_Parser.Make_Set_Boolean_False_Option
        (Description => "Turns OFF bolding of headers in plain reST output.",
         Short_Name  => 'B',
         Long_Name   => "no-bold-head",
         Variable    => BESM2_Fmt.Config.Bold_Head'Access),
      Arg_Parser.Make_Set_Boolean_True_Option
        (Description => "Turn on bolding of names and levels of attributes, " &
                         "defects, and skills in terse mode. Overrides " &
                         "italicizing (-i/--italics).",
         Short_Name  => 'b',
         Long_Name   => "bold",
         Variable    => BESM2_Fmt.Config.Bolding'Access),
      Arg_Parser.Make_Set_Boolean_True_Option
        (Description => "Omit the entity description.",
         Short_Name  => 'D',
         Long_Name   => "omit-description",
         Variable    => BESM2_Fmt.Config.Omit_Entity_Description'Access),
      Arg_Parser.Make_Set_Boolean_True_Option
        (Description => "Turn on debugging.",
         Short_Name  => 'd',
         Long_Name   => "debug",
         Variable    => BESM2_Fmt.Config.Debugging'Access),
      Arg_Parser.Make_Option
        (Description => "Output in h-m-m format.",
         Short_Name  => 'H',
         Long_Name   => "hmm",
         Handler     => Do_Hmm'Access),
      Arg_Parser.Make_Set_Natural_Option
        (Description => "Depth (Level) of h-m-m output.",
         Short_Name  => 'L',
         Long_Name   => "hmm-depth",
         Variable    => BESM2_Fmt.Config.Hmm_Depth'Access),
      Arg_Parser.Make_Set_String_Option
        (Description => "Text for root node of h-m-m output.",
         Short_Name  => 'R',
         Long_Name   => "hmm-root",
         Variable    => BESM2_Fmt.Config.Hmm_Root'Access),
      Arg_Parser.Make_Set_Boolean_True_Option
        (Description => "Output subitems as separate h-m-m nodes.",
         Short_Name  => 'S',
         Long_Name   => "hmm-separate",
         Variable    => BESM2_Fmt.Config.Hmm_Separate'Access),
      Arg_Parser.Make_Option
        (Description => "Display this text.",
         Short_Name  => 'h',
         Long_Name   => "help",
         Handler     => Do_Help'Access),
      Arg_Parser.Make_Set_Boolean_True_Option
        (Description => "Turn on italicizing of names and levels of " &
                         "attributes and defects in terse mode.",
         Short_Name  => 'i',
         Long_Name   => "italics",
         Variable    => BESM2_Fmt.Config.Italicizing'Access),
      Arg_Parser.Make_Set_Boolean_True_Option
        (Description => "Output the word ""Level"" before the level " &
                         "number in terse mode.",
         Short_Name  => 'l',
         Long_Name   => "level",
         Variable    => BESM2_Fmt.Config.Level'Access),
      Arg_Parser.Make_Set_Boolean_True_Option
        (Description => "Separate the attribute name and the level with " &
                         "an em dash in terse mode.",
         Short_Name  => 'M',
         Long_Name   => "em-dash",
         Variable    => BESM2_Fmt.Config.Em_Dash'Access),
      Arg_Parser.Make_Option
        (Description => "Use groff tbl output in a raw ms block.",
         Short_Name  => 'm',
         Long_Name   => "raw-ms-tables",
         Handler     => Do_Raw_Ms'Access),
      Arg_Parser.Make_Set_Boolean_True_Option
        (Description => "Use Unicode MINUS SIGN (U+2212) instead of ASCII " &
                         "hyphen-minus for negative numbers.",
         Short_Name  => 'n',
         Long_Name   => "unicode-minus",
         Variable    => BESM2_Fmt.Config.Unicode_Minus'Access),
      Arg_Parser.Make_Set_String_Option
        (Description => "Output file.",
         Short_Name  => 'o',
         Long_Name   => "output",
         Variable    => BESM2_Fmt.Config.Output_File'Access),
      Arg_Parser.Make_Set_Boolean_True_Option
        (Description => "Page after description. (Only for ms output!)",
         Short_Name  => 'p',
         Long_Name   => "page",
         Variable    => BESM2_Fmt.Config.Page_After_Description'Access),
      Arg_Parser.Make_Set_Boolean_True_Option
        (Description => "Show subtotals for stats, attributes, and defects.",
         Short_Name  => 's',
         Long_Name   => "subtotals",
         Variable    => BESM2_Fmt.Config.Show_Subtotals'Access),
      Arg_Parser.Make_Option
        (Description => "Use terse output.",
         Short_Name  => 't',
         Long_Name   => "terse",
         Handler     => Do_Terse'Access),
      Arg_Parser.Make_String_Option
        (Description => "Entities after the first are subentities, and " &
                         "use a different character for underlining the " &
                         "subheader.",
         Short_Name  => 'U',
         Long_Name   => "subunderliner",
         Handler     => Do_Subunderliner'Access),
      Arg_Parser.Make_String_Option
        (Description => "Character to use for underlining the header.",
         Short_Name  => 'u',
         Long_Name   => "underliner",
         Handler     => Do_Underliner'Access),
      Arg_Parser.Make_Set_Positive_Option
        (Description => "Width of table in characters.",
         Short_Name  => 'w',
         Long_Name   => "width",
         Variable    => BESM2_Fmt.Config.Table_Width'Access));

   The_Parser : Arg_Parser.Parser :=
     Arg_Parser.Make_Parser
       ("besm2_fmt [options] [files...]", Do_Argument'Access, Options'Access);

end BESM2_Fmt.Cli;
