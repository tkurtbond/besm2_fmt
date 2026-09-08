with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with BESM2_Fmt.Config;
with BESM2_Fmt.Text_Layout;

package body BESM2_Fmt.Format_Raw_Ms is

   package Config renames BESM2_Fmt.Config;
   package IO renames Ada.Text_IO;
   package TL renames BESM2_Fmt.Text_Layout;

   Raw_Prefix : constant String := "   ";

   function Tbold (S : String) return String is
     (if S'Length = 0 then S else "\fB" & S & "\fP");
   --  Troff bold, for text embedded inside the .TS/.TE table (raw
   --  groff, not reST) -- besm2-rst.scm's `tbold`, the only one of
   --  its table-header-cell markers process-entity-raw-ms actually
   --  calls. (besm2-rst.scm also defines a `titalics` troff-italics
   --  counterpart right next to `tbold`, but never calls it anywhere
   --  in the file -- dead code in the original, so not ported here.)
   --  Distinct from Text_Layout.Bold/Italics (reST "**"/"*"), which
   --  are used below only for the plain-reST portion of the entity
   --  (name/tagline/size) that comes before the ".. raw:: ms" block
   --  starts.

   function Space_To_Newline (S : String) return String is
      Result : String := S;
   begin
      for C of Result loop
         if C = ASCII.LF then
            C := ' ';
         end if;
      end loop;
      return Result;
   end Space_To_Newline;
   --  besm2-rst.scm's space-to-newline -- misleadingly named (it
   --  actually replaces newlines *with* spaces, not the reverse; see
   --  its definition's own "(if (char=? c #\newline) #\space c)").
   --  Byte-for-byte the same operation as Format_Hmm's All_One_Line:
   --  a "details: |" YAML literal block scalar's embedded newline has
   --  to be flattened before landing inside a tbl "T{...T}" text
   --  block, same reasoning as h-m-m's one-node-per-line requirement.

   function Points_Image (N : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (N), Ada.Strings.Left));

   function Defect_Points_Image (N : Integer) return String is
     (TL.Minus_Glyph & Points_Image (abs N));
   --  Defect points are always negative; unlike Format_Grid's
   --  Defect_Points_Image there's no reST backslash-escape needed
   --  here (this is inside a "T{...T}" groff text block, not exposed
   --  to reST list-marker syntax), but the sign glyph itself still
   --  goes through TL.Minus_Glyph rather than Integer'Image's own
   --  built-in "-", same reasoning as Format_Grid.

   function Signed_Points_Image (N : Integer) return String is
     (if N < 0 then TL.Minus_Glyph & Points_Image (abs N) else Points_Image (N));
   --  For a total that might be positive, negative, or zero -- see
   --  Format_Grid.Signed_Points_Image; same besm-tools commit 5cb3d92
   --  fix, ported here.

   function Expand_Derived_Name (Name : String) return String is
     (if Name = "ACV" then "Attack Combat Value"
      elsif Name = "DCV" then "Defence Combat Value"
      elsif Name = "DM" then "Damage Multiplier"
      elsif Name = "HP" then "Health Points"
      elsif Name = "EP" then "Energy Points"
      elsif Name = "SV" then "Shock Value"
      elsif Name = "AR" then "Armour Rating"
      else Name);
   --  besm2-rst.scm's derived-abbreviations alist -- shared between
   --  process-derived (grid) and process-derived-raw-ms in the
   --  Scheme (both consult the same top-level table; Terse/Hmm never
   --  do). Duplicated here rather than exported from Format_Grid to
   --  keep each backend self-contained, the same tradeoff already
   --  made for Format_Stat/Format_Derived/Format_Attribute/
   --  Format_Defect/Format_Skill being near-identically duplicated
   --  between Format_Terse and Format_Hmm.

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
     (if Length (A.Details) > 0
      then To_String (A.Name) & " (" & Space_To_Newline (To_String (A.Details)) & ")"
      else To_String (A.Name));

   function Format_Defect_Description (D : Entities.Defect) return String is
     (if Length (D.Details) > 0
      then To_String (D.Name) & " (" & Space_To_Newline (To_String (D.Details)) & ")"
      else To_String (D.Name));

   function Format_Skill_Description (S : Entities.Skill) return String is
     (if S.Specialisations.Is_Empty then To_String (S.Name)
      else To_String (S.Name) & " (" & Entities.Join (S.Specialisations, ", ") & ")");

   -----------------------------------------------------------------
   --  Process_Entity
   -----------------------------------------------------------------

   procedure Process_Entity (E : Entities.Entity; Entity_No : Positive) is
      Paragraph_Seen     : Boolean := False;
      First_Section_Seen : Boolean := False;
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
         Paragraph_Seen := True;
         IO.Put_Line (TL.Italics (To_String (E.Tagline)));
         IO.New_Line;
      end if;

      if not Config.Omit_Entity_Description and then E.Has_Description then
         Paragraph_Seen := True;
         IO.Put_Line (To_String (E.Description));
         IO.New_Line;
      end if;

      if E.Has_Size then
         Paragraph_Seen := True;
         IO.Put_Line (TL.Bold ("Size:") & " " & To_String (E.Size));
         IO.New_Line;
      end if;

      IO.Put_Line (".. raw:: ms");
      IO.New_Line;

      --  groff output from here to the end of this procedure.

      if not Paragraph_Seen then
         IO.Put_Line (Raw_Prefix & ".LP");
      end if;

      IO.Put_Line (Raw_Prefix & ".TS");
      IO.Put_Line (Raw_Prefix & "tab(#) ;");

      if not E.Stats.Is_Empty then
         --  Stats is always the first field in entity order, so
         --  (unlike Derived/Attributes/Defects/Skills below) it never
         --  needs to check First_Section_Seen -- it always sets it,
         --  unconditionally, matching besm2-rst.scm's own asymmetry
         --  here (its when-in-alist block for stats has no `unless
         --  first-section-seen` guard at all).
         First_Section_Seen := True;
         IO.Put_Line (Raw_Prefix & "c c lx .");
         IO.Put_Line (Raw_Prefix & "=");
         IO.Put_Line
           (Raw_Prefix & Tbold ("VALUE") & "#" & Tbold ("POINTS") & "#" & Tbold ("STAT"));
         for S of E.Stats loop
            IO.Put_Line
              (Raw_Prefix & To_String (S.Value) & "#" & Points_Image (S.Points) &
               "#" & To_String (S.Name));
         end loop;
         if Config.Show_Subtotals then
            IO.Put_Line
              (Raw_Prefix & "#" & Tbold (Points_Image (E.Stats_Total)) & "#" &
               Tbold ("STATS TOTAL"));
         end if;
         IO.Put_Line (Raw_Prefix);
      end if;

      if not E.Derived.Is_Empty then
         if First_Section_Seen then
            IO.Put_Line (Raw_Prefix & ".T&");
         end if;
         IO.Put_Line (Raw_Prefix & "c l sx .");
         if not First_Section_Seen then
            First_Section_Seen := True;
            IO.Put_Line (Raw_Prefix & "=");
         end if;
         IO.Put_Line (Raw_Prefix & Tbold ("VALUE") & "#" & Tbold ("DERIVED VALUE"));
         for D of E.Derived loop
            IO.Put_Line (Raw_Prefix & To_String (D.Value) & "#T{");
            IO.Put_Line (Raw_Prefix & Format_Derived_Description (D));
            IO.Put_Line (Raw_Prefix & "T}");
         end loop;
         IO.Put_Line (Raw_Prefix);
      end if;

      if not E.Attributes.Is_Empty then
         if First_Section_Seen then
            IO.Put_Line (Raw_Prefix & ".T&");
         end if;
         IO.Put_Line (Raw_Prefix & "c c lx .");
         if not First_Section_Seen then
            First_Section_Seen := True;
            IO.Put_Line (Raw_Prefix & "=");
         end if;
         IO.Put_Line
           (Raw_Prefix & Tbold ("LEVEL") & "#" & Tbold ("POINTS") & "#" &
            Tbold ("ATTRIBUTE"));
         for A of E.Attributes loop
            IO.Put_Line (Raw_Prefix & To_String (A.Level) & "#" & Points_Image (A.Points) & "#T{");
            IO.Put_Line (Raw_Prefix & Format_Attribute_Description (A));
            IO.Put_Line (Raw_Prefix & "T}");
         end loop;
         if Config.Show_Subtotals then
            IO.Put_Line
              (Raw_Prefix & "#" & Tbold (Points_Image (E.Attributes_Total)) & "#" &
               Tbold ("ATTRIBUTES TOTAL"));
         end if;
         IO.Put_Line (Raw_Prefix);
      end if;

      if not E.Defects.Is_Empty then
         if First_Section_Seen then
            IO.Put_Line (Raw_Prefix & ".T&");
         end if;
         IO.Put_Line (Raw_Prefix & "c c lx .");
         if not First_Section_Seen then
            First_Section_Seen := True;
            IO.Put_Line (Raw_Prefix & "=");
         end if;
         IO.Put_Line (Raw_Prefix & "#" & Tbold ("POINTS") & "#" & Tbold ("DEFECT"));
         for D of E.Defects loop
            IO.Put_Line (Raw_Prefix & "#" & Defect_Points_Image (D.Points) & "#T{");
            IO.Put_Line (Raw_Prefix & Format_Defect_Description (D));
            IO.Put_Line (Raw_Prefix & "T}");
         end loop;
         if Config.Show_Subtotals then
            IO.Put_Line
              (Raw_Prefix & "#" & Tbold (Signed_Points_Image (E.Defects_Total)) & "#" &
               Tbold ("DEFECTS TOTAL"));
         end if;
         IO.Put_Line (Raw_Prefix);
      end if;

      if not E.Skills.Is_Empty then
         if First_Section_Seen then
            IO.Put_Line (Raw_Prefix & ".T&");
         end if;
         IO.Put_Line (Raw_Prefix & "c c lx .");
         if not First_Section_Seen then
            First_Section_Seen := True;
            IO.Put_Line (Raw_Prefix & "=");
         end if;
         IO.Put_Line
           (Raw_Prefix & Tbold ("LEVEL") & "#" & Tbold ("POINTS") & "#" & Tbold ("SKILL"));
         for S of E.Skills loop
            IO.Put_Line (Raw_Prefix & To_String (S.Level) & "#" & Points_Image (S.Points) & "#T{");
            IO.Put_Line (Raw_Prefix & Format_Skill_Description (S));
            IO.Put_Line (Raw_Prefix & "T}");
         end loop;
         --  Unlike Stats/Attributes/Defects above, the skill-points
         --  total row is unconditional -- matches Format_Grid's own
         --  Skills total (besm2-rst.scm's process-entity-raw-ms never
         --  guards this one with *show-subtotals* either).
         IO.Put_Line
           (Raw_Prefix & "#" & Tbold (Points_Image (E.Skills_Total)) & "#" &
            Tbold ("SKILL POINTS TOTAL"));
         IO.Put_Line (Raw_Prefix);
      end if;

      --  Grand total: only shown when positive (unlike Format_Grid's
      --  unconditional TOTAL row) -- besm2-rst.scm's own
      --  "(when (> entity-total 0) ...)". The closing "=" and ".TE"
      --  are unconditional either way.
      if E.Entity_Total > 0 then
         IO.Put_Line
           (Raw_Prefix & "#" & Tbold (Signed_Points_Image (E.Entity_Total)) & "#" &
            Tbold ("TOTAL"));
      end if;
      IO.Put_Line (Raw_Prefix & "=");
      IO.Put_Line (Raw_Prefix & ".TE");
   end Process_Entity;

end BESM2_Fmt.Format_Raw_Ms;
