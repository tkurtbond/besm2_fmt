with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with BESM2_Fmt.Config;
with BESM2_Fmt.Text_Layout;

package body BESM2_Fmt.Format_Hmm is

   package Config renames BESM2_Fmt.Config;
   package IO renames Ada.Text_IO;
   package TL renames BESM2_Fmt.Text_Layout;

   function Indent (Depth : Natural) return String is
     (String'(1 .. Depth => ASCII.HT));

   function All_One_Line (S : String) return String is
      Result : String := S;
   begin
      for C of Result loop
         if C = ASCII.LF then
            C := ' ';
         end if;
      end loop;
      return Result;
   end All_One_Line;
   --  besm2-rst.scm's all-one-line (string-join (string-split s "\n")
   --  " ") -- an h-m-m node is exactly one physical line, so any
   --  internal newline in a tagline/description/details field (from a
   --  "details: |" YAML literal block scalar, e.g.
   --  FV2021-Coleopteran-2e.yaml's "Weapon: Rocket Pod" attribute) has
   --  to be flattened to a space rather than printed literally.
   --  Splitting-then-joining on a single-character separator is
   --  exactly a per-character replace, including the "two spaces for
   --  two consecutive newlines" case, so this ports it directly rather
   --  than via a split/join round-trip.

   function Points_Image (N : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (N), Ada.Strings.Left));

   function Label_Points (Points : Integer; Mecha : Boolean) return String is
      Suffix : constant String :=
        (if Mecha then (if Points < 0 then "MBP" else "MP")
         else (if Points < 0 then "BP" else "CP"));
   begin
      return Points_Image (abs Points) & " " & Suffix;
   end Label_Points;

   function Emphasize (S : String) return String is
     (if Config.Bolding then TL.Bold (S)
      elsif Config.Italicizing then TL.Italics (S)
      else S);

   -----------------------------------------------------------------
   --  Per-item text -- besm2-rst.scm's process-stat-hmm/
   --  process-derived-hmm/process-attribute-hmm/process-defect-hmm/
   --  process-skill-hmm, minus the `show`/output part (each just
   --  returns the one-line text here; Process_Entity below writes it
   --  with the right indentation and item separator).
   -----------------------------------------------------------------

   function Format_Stat (S : Entities.Stat; Mecha : Boolean) return String is
     (To_String (S.Name) & " " & To_String (S.Value) & " (" &
      Label_Points (S.Points, Mecha) & ")");

   function Format_Derived (D : Entities.Derived_Value) return String is
     (To_String (D.Name) & " " & To_String (D.Value) &
      (if D.Alternatives.Is_Empty then ""
       else " (" & Entities.Join (D.Alternatives, ", ") & ")"));

   function Format_Attribute (A : Entities.Attribute; Mecha : Boolean) return String
   is
      Sep          : constant String := (if Config.Em_Dash then " — " else " ");
      Level_Prefix : constant String := (if Config.Level then "Level " else "");
      Emphasized   : constant String :=
        Emphasize
          (To_String (A.Name) & Sep & Level_Prefix & To_String (A.Level));
      Details_Part : constant String :=
        (if Length (A.Details) > 0
         then All_One_Line (To_String (A.Details) & ". ")
         else "");
   begin
      return Emphasized & " (" & Details_Part & Label_Points (A.Points, Mecha) & ")";
   end Format_Attribute;

   function Format_Defect (D : Entities.Defect; Mecha : Boolean) return String is
      Details_Part : constant String :=
        (if Length (D.Details) > 0
         then All_One_Line (To_String (D.Details) & ".  ")
         else "");
   begin
      return
        Emphasize (To_String (D.Name)) & " (" & Details_Part &
        Label_Points (D.Points, Mecha) & ")";
   end Format_Defect;

   function Format_Skill (S : Entities.Skill) return String is
      Sep          : constant String := (if Config.Em_Dash then " — " else " ");
      Level_Prefix : constant String := (if Config.Level then "Level " else "");
      Spec_Part    : constant String :=
        (if not S.Specialisations.Is_Empty
         then Entities.Join (S.Specialisations, ", ") & ".  "
         else "");
   begin
      --  Unlike Format_Attribute/Format_Defect above (and unlike
      --  Format_Terse's own Format_Skill), besm2-rst.scm's
      --  process-skill-hmm's `emphasizing` call doesn't close after
      --  name+level -- it wraps the whole rest of the line, "(...SP)"
      --  included: "(show #t (emphasizing name ... level " (" ...
      --  points " SP)"))" is all one argument list to emphasizing.
      --  Confirmed against the real besm2-rst binary's -b output.
      return
        Emphasize
          (To_String (S.Name) & Sep & Level_Prefix & To_String (S.Level) &
           " (" & Spec_Part & Points_Image (S.Points) & " SP)");
   end Format_Skill;

   -----------------------------------------------------------------
   --  Process_Entity
   -----------------------------------------------------------------

   procedure Process_Entity (E : Entities.Entity; Entity_No : Positive) is
      pragma Unreferenced (Entity_No);

      Base : constant Natural := Config.Hmm_Depth;
      D1   : constant Natural := Base + 1;  --  entity line
      D2   : constant Natural := Base + 2;  --  section headers
      D3   : constant Natural := Base + 3;  --  item lists

      --  Writes each element of a "join with Sep, or one per own
      --  D3-indented line under -S/--hmm-separate" list, matching
      --  besm2-rst.scm's identical `loop ... when (> i 1) do (show #t
      --  (if *hmm-separate* (each nl (indent)) ", "))` in every one of
      --  its five item loops.
      procedure Put_Item (First : in out Boolean) is
      begin
         if First then
            First := False;
         elsif Config.Hmm_Separate then
            IO.New_Line;
            IO.Put (Indent (D3));
         else
            IO.Put (", ");
         end if;
      end Put_Item;

   begin
      if E.Has_Name then
         IO.Put_Line
           (Indent (D1) & To_String (E.Name) & " (" &
            Label_Points (E.Entity_Total, E.Mecha) & ")");
      else
         IO.Put_Line (Indent (D1) & Label_Points (E.Entity_Total, E.Mecha));
      end if;

      if E.Has_Tagline then
         IO.Put_Line (Indent (D2) & TL.Italics (All_One_Line (To_String (E.Tagline))));
      end if;

      if not Config.Omit_Entity_Description and then E.Has_Description then
         IO.Put_Line (Indent (D2) & All_One_Line (To_String (E.Description)) & " ");
      end if;

      if E.Has_Size then
         IO.Put_Line (Indent (D2) & TL.Bold ("Size:") & " " & To_String (E.Size));
      end if;

      if not E.Stats.Is_Empty then
         IO.Put (Indent (D2) & TL.Bold ("Statistics"));
         if Config.Show_Subtotals then
            IO.Put (" (" & Label_Points (E.Stats_Total, E.Mecha) & ") ");
         end if;
         IO.New_Line;
         IO.Put (Indent (D3));
         declare
            First : Boolean := True;
         begin
            for S of E.Stats loop
               Put_Item (First);
               IO.Put (Format_Stat (S, E.Mecha));
            end loop;
         end;
         IO.New_Line;
      end if;

      if not E.Derived.Is_Empty then
         IO.Put_Line (Indent (D2) & TL.Bold ("Derived Values"));
         IO.Put (Indent (D3));
         declare
            First : Boolean := True;
         begin
            for D of E.Derived loop
               Put_Item (First);
               IO.Put (Format_Derived (D));
            end loop;
         end;
         IO.New_Line;
      end if;

      if not E.Attributes.Is_Empty then
         IO.Put
           (Indent (D2) &
            TL.Bold (if E.Mecha then "Mecha Sub-Attributes" else "Attributes"));
         if Config.Show_Subtotals then
            IO.Put (" (" & Label_Points (E.Attributes_Total, E.Mecha) & ")");
         end if;
         IO.New_Line;
         IO.Put (Indent (D3));
         declare
            First : Boolean := True;
         begin
            for A of E.Attributes loop
               Put_Item (First);
               IO.Put (Format_Attribute (A, E.Mecha));
            end loop;
         end;
         IO.New_Line;
      end if;

      if not E.Defects.Is_Empty then
         IO.Put
           (Indent (D2) & TL.Bold (if E.Mecha then "Mecha Defects" else "Defects"));
         if Config.Show_Subtotals then
            IO.Put (" (" & Label_Points (E.Defects_Total, E.Mecha) & ")");
         end if;
         IO.New_Line;
         IO.Put (Indent (D3));
         declare
            First : Boolean := True;
         begin
            for D of E.Defects loop
               Put_Item (First);
               IO.Put (Format_Defect (D, E.Mecha));
            end loop;
         end;
         IO.New_Line;
      end if;

      if not E.Skills.Is_Empty then
         IO.Put (Indent (D2) & TL.Bold ("Skills"));
         if Config.Show_Subtotals then
            IO.Put (" (" & Points_Image (E.Skills_Total) & " SP)");
         end if;
         IO.New_Line;
         IO.Put (Indent (D3));
         declare
            First : Boolean := True;
         begin
            for S of E.Skills loop
               Put_Item (First);
               IO.Put (Format_Skill (S));
            end loop;
         end;
         IO.New_Line;
      end if;
   end Process_Entity;

end BESM2_Fmt.Format_Hmm;
