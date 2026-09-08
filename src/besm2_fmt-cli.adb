package body BESM2_Fmt.Cli is

   package Config renames BESM2_Fmt.Config;

   function Do_One return Boolean is
   begin
      Config.One_Table := True;
      --  Having multiple header-separator lines doesn't bother
      --  pandoc, but it makes the first one look like a header in
      --  HTML output when there's actually only one table.
      Config.Head_Sep := '-';
      return True;
   end Do_One;

   function Do_Hmm return Boolean is
   begin
      Config.Format := Config.Hmm;
      Config.Hmm_Output := True;
      return True;
   end Do_Hmm;

   function Do_Raw_Ms return Boolean is
   begin
      Config.Format := Config.Raw_Ms;
      return True;
   end Do_Raw_Ms;

   function Do_Terse return Boolean is
   begin
      Config.Format := Config.Terse;
      return True;
   end Do_Terse;

   function Do_Help return Boolean is
   begin
      Arg_Parser.Usage (The_Parser);
      raise Help_Requested;
      return False;
   end Do_Help;

   function Do_Subunderliner (Arg : String) return Boolean is
   begin
      if Arg'Length /= 1 then
         raise Arg_Parser.Invalid_Option_Argument with
           "-U/--subunderliner takes exactly one character, got """ &
           Arg & '"';
      end if;
      Config.Subunderliner := Arg (Arg'First);
      return True;
   end Do_Subunderliner;

   function Do_Underliner (Arg : String) return Boolean is
   begin
      if Arg'Length /= 1 then
         raise Arg_Parser.Invalid_Option_Argument with
           "-u/--underliner takes exactly one character, got """ &
           Arg & '"';
      end if;
      Config.Underliner := Arg (Arg'First);
      return True;
   end Do_Underliner;

   function Do_Argument (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      Filenames.Append (Ada.Strings.Unbounded.To_Unbounded_String (Arg));
      return True;
   end Do_Argument;

   procedure Parse is
   begin
      Arg_Parser.Parse_Arguments (The_Parser);
   end Parse;

end BESM2_Fmt.Cli;
