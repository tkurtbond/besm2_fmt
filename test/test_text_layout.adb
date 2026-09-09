--  Exercises BESM2_Fmt.Text_Layout in isolation (no YAML/Entities
--  involved) -- PLAN.md section 8, build-order step 1: "Text_Layout in
--  isolation (unit-testable without any YAML at all)."

with Ada.Containers; use Ada.Containers;
with Ada.Text_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with BESM2_Fmt.Config;
with BESM2_Fmt.Text_Layout;

procedure Test_Text_Layout is

   package TL renames BESM2_Fmt.Text_Layout;

   Failures : Natural := 0;

   procedure Check (Label : String; Condition : Boolean) is
   begin
      if Condition then
         Ada.Text_IO.Put_Line ("ok   - " & Label);
      else
         Ada.Text_IO.Put_Line ("FAIL - " & Label);
         Failures := Failures + 1;
      end if;
   end Check;

   function Vec3 (A, B, C : String) return TL.Line_Vectors.Vector is
      Result : TL.Line_Vectors.Vector;
   begin
      Result.Append (To_Unbounded_String (A));
      Result.Append (To_Unbounded_String (B));
      Result.Append (To_Unbounded_String (C));
      return Result;
   end Vec3;

   function Joined (V : TL.Line_Vectors.Vector; Sep : String := "|") return String is
      Result : Unbounded_String;
   begin
      for I in V.First_Index .. V.Last_Index loop
         if I > V.First_Index then
            Append (Result, Sep);
         end if;
         Append (Result, V (I));
      end loop;
      return To_String (Result);
   end Joined;

begin
   -----------------------------------------------------------------
   --  Display_Length: codepoints, not bytes -- the UTF-8 multi-byte
   --  characters actually present in test-data (curly quote, em dash,
   --  multiplication sign).
   -----------------------------------------------------------------
   Check ("Display_Length of plain ASCII", TL.Display_Length ("Body") = 4);
   Check ("Display_Length of a 3-byte UTF-8 char (curly quote)",
          TL.Display_Length (Character'Val (16#E2#) & Character'Val (16#80#) &
                              Character'Val (16#9C#)) = 1);
   Check ("Display_Length of a 2-byte UTF-8 char (multiplication sign) in context",
          TL.Display_Length ("Shots " & Character'Val (16#C3#) & Character'Val (16#97#) & "2") = 8);

   -----------------------------------------------------------------
   --  Pad
   -----------------------------------------------------------------
   Check ("Pad left-aligns and fills with spaces",
          TL.Pad ("8", 10) = "8         ");
   Check ("Pad right-aligns on request",
          TL.Pad ("8", 10, TL.Right_Align) = "         8");
   Check ("Pad passes through unchanged text already at Width",
          TL.Pad ("POINTS", 6) = "POINTS");
   Check ("Pad never truncates text already over Width",
          TL.Pad ("ATTRIBUTES TOTAL", 6) = "ATTRIBUTES TOTAL");
   Check ("Pad counts UTF-8 codepoints, not bytes, toward Width",
          TL.Pad (Character'Val (16#E2#) & Character'Val (16#80#) &
                  Character'Val (16#9C#) & "ok", 4) =
          Character'Val (16#E2#) & Character'Val (16#80#) &
          Character'Val (16#9C#) & "ok ");

   -----------------------------------------------------------------
   --  Word_Wrap
   -----------------------------------------------------------------
   Check ("Word_Wrap of an empty string yields one empty line",
          TL.Word_Wrap ("", 10).Length = 1 and then
          Length (TL.Word_Wrap ("", 10).First_Element) = 0);
   Check ("Word_Wrap of short text yields one line unchanged",
          Joined (TL.Word_Wrap ("Body", 36)) = "Body");
   Check
     ("Word_Wrap greedily fills lines on space boundaries -- matches the " &
      "golden ""Weapon: Rocket Pod"" attribute wrap at width 36",
      Joined (TL.Word_Wrap
                ("Weapon: Rocket Pod (Damage 45, Auto-fire, Area Effect, " &
                 "Limited Shots " & Character'Val (16#C3#) & Character'Val (16#97#) &
                 "2 [3 shots], Stoppable)", 36),
              Sep => "" & ASCII.LF) =
      "Weapon: Rocket Pod (Damage 45," & ASCII.LF &
      "Auto-fire, Area Effect, Limited" & ASCII.LF &
      "Shots " & Character'Val (16#C3#) & Character'Val (16#97#) &
      "2 [3 shots], Stoppable)");
   Check
     ("Word_Wrap treats an embedded newline (from a ""details: |"" YAML " &
      "block scalar) as a word break, not literal content -- a real bug " &
      "found against FV2021-Coleopteran-2e.yaml's ""Weapon: Rocket Pod"" " &
      "attribute, whose details field is a two-line block scalar that " &
      "re-fills as one continuous phrase in the golden grid-table output",
      Joined (TL.Word_Wrap
                ("Weapon: Rocket Pod (Damage 45, Auto-fire, Area Effect, " &
                 "Limited Shots " & Character'Val (16#C3#) & Character'Val (16#97#) &
                 "2 [3 shots]," & ASCII.LF & "Stoppable)", 36),
              Sep => "" & ASCII.LF) =
      "Weapon: Rocket Pod (Damage 45," & ASCII.LF &
      "Auto-fire, Area Effect, Limited" & ASCII.LF &
      "Shots " & Character'Val (16#C3#) & Character'Val (16#97#) &
      "2 [3 shots], Stoppable)");
   Check ("Word_Wrap never breaks a single word longer than Width",
          Joined (TL.Word_Wrap ("Supercalifragilisticexpialidocious", 5)) =
          "Supercalifragilisticexpialidocious");

   -----------------------------------------------------------------
   --  Bold / Italics / Bolding / Italicizing / Emphasizing / Hbolding
   -----------------------------------------------------------------
   Check ("Bold always wraps in **", TL.Bold ("STAT") = "**STAT**");
   Check ("Italics always wraps in *", TL.Italics ("tagline") = "*tagline*");

   Check ("Bolding off by default leaves text unchanged",
          not BESM2_Fmt.Config.Bolding and then TL.Bolding ("x") = "x");
   BESM2_Fmt.Config.Bolding := True;
   Check ("Bolding wraps in ** once -b/--bold is set",
          TL.Bolding ("x") = "**x**");
   Check ("Emphasizing prefers Bolding over Italicizing",
          TL.Emphasizing ("x") = "**x**");
   BESM2_Fmt.Config.Bolding := False;

   Check ("Italicizing off by default leaves text unchanged",
          not BESM2_Fmt.Config.Italicizing and then TL.Italicizing ("x") = "x");
   BESM2_Fmt.Config.Italicizing := True;
   Check ("Italicizing wraps in * once -i/--italics is set",
          TL.Italicizing ("x") = "*x*");
   Check ("Emphasizing falls back to Italicizing when Bolding is off",
          TL.Emphasizing ("x") = "*x*");
   BESM2_Fmt.Config.Italicizing := False;
   Check ("Emphasizing leaves text unchanged when neither flag is set",
          TL.Emphasizing ("x") = "x");

   Check ("Hbolding is on by default (-B/--no-bold-head not given)",
          BESM2_Fmt.Config.Bold_Head and then TL.Hbolding ("VALUE") = "**VALUE**");
   BESM2_Fmt.Config.Bold_Head := False;
   Check ("Hbolding leaves text unchanged once -B/--no-bold-head is set",
          TL.Hbolding ("VALUE") = "VALUE");
   BESM2_Fmt.Config.Bold_Head := True;

   -----------------------------------------------------------------
   --  Minus_Glyph -- besm2-rst.scm's minus-glyph, with this program's
   --  own default polarity (see PLAN.md): Unicode MINUS SIGN (U+2212,
   --  UTF-8 E2 88 92) by default, or ASCII hyphen-minus once
   --  -n/--no-unicode-minus (Config.Unicode_Minus) is cleared.
   -----------------------------------------------------------------
   Check ("Minus_Glyph is Unicode MINUS SIGN (U+2212) by default (-n not given)",
          BESM2_Fmt.Config.Unicode_Minus and then TL.Minus_Glyph =
          Character'Val (16#E2#) & Character'Val (16#88#) & Character'Val (16#92#));
   BESM2_Fmt.Config.Unicode_Minus := False;
   Check ("Minus_Glyph is ASCII hyphen-minus once -n/--no-unicode-minus is set",
          TL.Minus_Glyph = "-");
   BESM2_Fmt.Config.Unicode_Minus := True;

   -----------------------------------------------------------------
   --  Put_Row / Separator_Line, against the real golden grid-table
   --  fragment (enyon-boase-2e.gen.rst's STAT table, table-width 60,
   --  num-width 10):
   --
   --    +----------+----------+------------------------------------+
   --    |**VALUE** |**POINTS**|**STAT**                            |
   --    +==========+==========+====================================+
   --    |8         |8         |Body                                |
   --    +----------+----------+------------------------------------+
   -----------------------------------------------------------------
   declare
      Path : constant String := "/tmp/test_text_layout_capture.txt";
      F    : Ada.Text_IO.File_Type;
      In_F : Ada.Text_IO.File_Type;

      Data_Sep, Header_Sep, Header_Line, Data_Line : Unbounded_String;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Set_Output (F);
      TL.Separator_Line (3);
      TL.Separator_Line (3, '=');
      TL.Put_Row (Vec3 (TL.Hbolding ("VALUE"), TL.Hbolding ("POINTS"),
                        TL.Hbolding ("STAT")));
      TL.Put_Row (Vec3 ("8", "8", "Body"));
      Ada.Text_IO.Set_Output (Ada.Text_IO.Standard_Output);
      Ada.Text_IO.Close (F);

      Ada.Text_IO.Open (In_F, Ada.Text_IO.In_File, Path);
      Data_Sep := To_Unbounded_String (Ada.Text_IO.Get_Line (In_F));
      Header_Sep := To_Unbounded_String (Ada.Text_IO.Get_Line (In_F));
      Header_Line := To_Unbounded_String (Ada.Text_IO.Get_Line (In_F));
      Data_Line := To_Unbounded_String (Ada.Text_IO.Get_Line (In_F));
      Ada.Text_IO.Close (In_F);

      Check ("Separator_Line(3) matches the golden STAT table's '-' border",
             To_String (Data_Sep) =
             "+----------+----------+------------------------------------+");

      Check ("Separator_Line(3, '=') matches the golden STAT table's header border",
             To_String (Header_Sep) =
             "+==========+==========+====================================+");

      Check ("Put_Row of the hbolded header matches the golden STAT header row",
             To_String (Header_Line) = "|**VALUE** |**POINTS**|**STAT**" &
             "                            |");

      Check ("Put_Row of a data row matches the golden STAT data row",
             To_String (Data_Line) = "|8         |8         |Body" &
             "                                |");
   end;

   Ada.Text_IO.New_Line;
   if Failures = 0 then
      Ada.Text_IO.Put_Line ("All checks passed.");
   else
      Ada.Text_IO.Put_Line (Natural'Image (Failures) & " check(s) failed.");
   end if;
end Test_Text_Layout;
