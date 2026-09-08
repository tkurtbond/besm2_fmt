with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with BESM2_Fmt.Config;
with BESM2_Fmt.Text_Layout;

package body BESM2_Fmt.Format_Grid is

   package Config renames BESM2_Fmt.Config;
   package IO renames Ada.Text_IO;
   package TL renames BESM2_Fmt.Text_Layout;

   -----------------------------------------------------------------
   --  row2/row3/sep2/sep3/headsep2/headsep3 -- thin wrappers over
   --  Text_Layout.Put_Row/Separator_Line matching besm2-rst.scm's own
   --  same-named helpers 1:1, so this body reads next to
   --  besm2-rst.scm's process-entity with the least translation.
   -----------------------------------------------------------------

   procedure Row2 (Col1, Col2 : String) is
      Cols : TL.Line_Vectors.Vector;
   begin
      Cols.Append (To_Unbounded_String (Col1));
      Cols.Append (To_Unbounded_String (Col2));
      TL.Put_Row (Cols);
   end Row2;

   procedure Row3 (Col1, Col2, Col3 : String) is
      Cols : TL.Line_Vectors.Vector;
   begin
      Cols.Append (To_Unbounded_String (Col1));
      Cols.Append (To_Unbounded_String (Col2));
      Cols.Append (To_Unbounded_String (Col3));
      TL.Put_Row (Cols);
   end Row3;

   procedure Sep2 is
   begin
      TL.Separator_Line (2);
   end Sep2;

   procedure Sep3 is
   begin
      TL.Separator_Line (3);
   end Sep3;

   procedure Headsep2 is
   begin
      TL.Separator_Line (2, Config.Head_Sep);
   end Headsep2;

   procedure Headsep3 is
   begin
      TL.Separator_Line (3, Config.Head_Sep);
   end Headsep3;

   procedure Empty_Or_Blank_Line is
   begin
      if Config.One_Table then
         TL.Empty_Row;
      else
         IO.New_Line;
      end if;
   end Empty_Or_Blank_Line;

   -----------------------------------------------------------------
   --  Cell text assembly -- besm2-rst.scm's process-stat/
   --  process-derived/process-attribute/process-defect/process-skill,
   --  minus the row3/row2/sum-of-points parts (those are inlined into
   --  Process_Entity below, driven off Entities.Entity's
   --  already-summed *_Total fields instead of re-summing here).
   -----------------------------------------------------------------

   function Points_Image (N : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (N), Ada.Strings.Left));

   function Defect_Points_Image (N : Integer) return String is
     ("\" & TL.Minus_Glyph & Points_Image (abs N));
   --  Defect points are always negative (a besm2-rst.scm design
   --  decision -- see its header comment); reST would otherwise read
   --  the leading "-" as starting a bullet list, so it's
   --  backslash-quoted. besm2-rst.scm's process-defect does this
   --  unconditionally (string-append "\\" ...), not just when
   --  negative, so this ports that as-is rather than special-casing
   --  the sign. The sign glyph itself goes through TL.Minus_Glyph
   --  (ASCII hyphen-minus, or Unicode MINUS SIGN under
   --  -n/--unicode-minus) rather than Integer'Image's own built-in
   --  "-", matching besm2-rst.scm's negative-number->string.

   function Signed_Points_Image (N : Integer) return String is
     (if N < 0 then TL.Minus_Glyph & Points_Image (abs N) else Points_Image (N));
   --  For a total that might be positive, negative, or zero --
   --  Defects_Total (always <= 0, a sum of always-negative defect
   --  points) and Entity_Total (can go negative if defects outweigh
   --  stats+attributes). Stats_Total/Attributes_Total/Skills_Total
   --  are never negative, so they keep using plain Points_Image --
   --  matches besm2-rst.scm's points->string, added upstream in
   --  besm-tools commit 5cb3d92 after the same bug (DEFECTS TOTAL
   --  ignoring -n/--unicode-minus) turned up there first.

   function Expand_Derived_Name (Name : String) return String is
     (if Name = "ACV" then "Attack Combat Value"
      elsif Name = "DCV" then "Defence Combat Value"
      elsif Name = "DM" then "Damage Multiplier"
      elsif Name = "HP" then "Health Points"
      elsif Name = "EP" then "Energy Points"
      elsif Name = "SV" then "Shock Value"
      elsif Name = "AR" then "Armour Rating"
      else Name);
   --  besm2-rst.scm's derived-abbreviations alist. Grid mode is the
   --  only one of the four output formats that expands these --
   --  Format_Terse's golden output keeps "ACV"/"DCV"/... as-is (its
   --  process-entity-terse counterpart never consults the alist), so
   --  this stays local to Format_Grid rather than moving to
   --  BESM2_Fmt.Entities.

   function Format_Derived_Description (D : Entities.Derived_Value) return String is
      Name : constant String := Expand_Derived_Name (To_String (D.Name));
   begin
      if D.Alternatives.Is_Empty then
         return Name;
      else
         return Name & " (" & Entities.Join (D.Alternatives, ", ") & ")";
      end if;
   end Format_Derived_Description;

   function Format_Attribute_Description (A : Entities.Attribute) return String is
     (if Length (A.Details) > 0 then To_String (A.Name) & " (" & To_String (A.Details) & ")"
      else To_String (A.Name));

   function Format_Defect_Description (D : Entities.Defect) return String is
     (if Length (D.Details) > 0 then To_String (D.Name) & " (" & To_String (D.Details) & ")"
      else To_String (D.Name));

   function Format_Skill_Description (S : Entities.Skill) return String is
     (if S.Specialisations.Is_Empty then To_String (S.Name)
      else To_String (S.Name) & " (" & Entities.Join (S.Specialisations, ", ") & ")");

   -----------------------------------------------------------------
   --  Process_Entity
   -----------------------------------------------------------------

   procedure Process_Entity (E : Entities.Entity; Entity_No : Positive) is
   begin
      if E.Has_Name then
         declare
            Name           : constant String := To_String (E.Name);
            Underline_Char : constant Character :=
              (if Entity_No > 1 and then Config.Subunderliner /= ASCII.NUL
               then Config.Subunderliner
               else Config.Underliner);
         begin
            IO.Put_Line (Name);
            IO.Put_Line (String'(1 .. Name'Length => Underline_Char));
            IO.New_Line;
         end;
      end if;

      if E.Has_Tagline then
         IO.Put_Line (TL.Italics (To_String (E.Tagline)));
         IO.New_Line;
      end if;

      if not Config.Omit_Entity_Description and then E.Has_Description then
         IO.Put_Line (To_String (E.Description));
         IO.New_Line;
      end if;

      if E.Has_Size then
         IO.Put_Line (TL.Bold ("Size:") & " " & To_String (E.Size));
         IO.New_Line;
      end if;

      if not E.Stats.Is_Empty then
         Sep3;
         Row3 (TL.Hbolding ("VALUE"), TL.Hbolding ("POINTS"), TL.Hbolding ("STAT"));
         Headsep3;
         for S of E.Stats loop
            Row3 (To_String (S.Value), Points_Image (S.Points), To_String (S.Name));
            Sep3;
         end loop;
         if Config.Show_Subtotals then
            Row3
              ("", TL.Hbolding (Points_Image (E.Stats_Total)),
               TL.Hbolding ("STATS TOTAL"));
            Sep3;
         end if;
         Empty_Or_Blank_Line;
      end if;

      if not E.Derived.Is_Empty then
         Sep2;
         Row2 (TL.Hbolding ("VALUE"), TL.Hbolding ("DERIVED VALUE"));
         Headsep2;
         for D of E.Derived loop
            Row2 (To_String (D.Value), Format_Derived_Description (D));
            Sep2;
         end loop;
         Empty_Or_Blank_Line;
      end if;

      if not E.Attributes.Is_Empty then
         Sep3;
         Row3 (TL.Hbolding ("LEVEL"), TL.Hbolding ("POINTS"), TL.Hbolding ("ATTRIBUTE"));
         Headsep3;
         for A of E.Attributes loop
            Row3
              (To_String (A.Level), Points_Image (A.Points),
               Format_Attribute_Description (A));
            Sep3;
         end loop;
         if Config.Show_Subtotals then
            Row3
              ("", TL.Hbolding (Points_Image (E.Attributes_Total)),
               TL.Hbolding ("ATTRIBUTES TOTAL"));
            Sep3;
         end if;
         Empty_Or_Blank_Line;
      end if;

      if not E.Defects.Is_Empty then
         Sep3;
         Row3 ("", TL.Hbolding ("POINTS"), TL.Hbolding ("DEFECT"));
         Headsep3;
         for D of E.Defects loop
            Row3 ("", Defect_Points_Image (D.Points), Format_Defect_Description (D));
            Sep3;
         end loop;
         if Config.Show_Subtotals then
            Row3
              ("", TL.Hbolding (Signed_Points_Image (E.Defects_Total)),
               TL.Hbolding ("DEFECTS TOTAL"));
            Sep3;
         end if;
         Empty_Or_Blank_Line;
      end if;

      if not E.Skills.Is_Empty then
         Sep3;
         Row3 (TL.Hbolding ("LEVEL"), TL.Hbolding ("POINTS"), TL.Hbolding ("SKILL"));
         Headsep3;
         for S of E.Skills loop
            Row3 (To_String (S.Level), Points_Image (S.Points), Format_Skill_Description (S));
            Sep3;
         end loop;
         --  Unlike stats/attributes/defects, the skill-points total row
         --  is unconditional -- besm2-rst.scm's process-entity never
         --  guards it with *show-subtotals*.
         Row3
           ("", TL.Hbolding (Points_Image (E.Skills_Total)),
            TL.Hbolding ("SKILL POINTS TOTAL"));
         Sep3;
         Empty_Or_Blank_Line;
      end if;

      --  Grand total: always shown, regardless of -s/--subtotals, and
      --  never wrapped in Empty_Or_Blank_Line -- besm2-rst.scm ends
      --  process-entity with a plain trailing blank line here even
      --  under -1/--one-table.
      Sep3;
      Row3 ("", TL.Hbolding (Signed_Points_Image (E.Entity_Total)), TL.Hbolding ("TOTAL"));
      Sep3;
      IO.New_Line;
   end Process_Entity;

end BESM2_Fmt.Format_Grid;
