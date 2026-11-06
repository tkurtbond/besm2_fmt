with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with BESM2_Fmt.Config;
with BESM2_Fmt.Text_Layout;

package body BESM2_Fmt.Format_Terse is

   package Config renames BESM2_Fmt.Config;
   package IO renames Ada.Text_IO;
   package TL renames BESM2_Fmt.Text_Layout;

   function Bold (S : String) return String is ("**" & S & "**");
   function Italic (S : String) return String is ("*" & S & "*");

   --  Always-bold/italic (Bold/Italic above) is for headers like
   --  "Size:"/"Statistics" (besm2-rst.scm's unconditional `bold`);
   --  Emphasize is for attribute/defect/skill names, conditional on
   --  -b/--bold or -i/--italics (besm2-rst.scm's `emphasizing`).
   function Emphasize (S : String) return String is
     (if Config.Bolding then Bold (S)
      elsif Config.Italicizing then Italic (S)
      else S);

   --  TL.Override_Mark if Marked (an overridden number), else "".
   function Mark (Marked : Boolean) return String is
     (if Marked then TL.Override_Mark else "");

   function Label_Points
     (Points : Integer; Mecha : Boolean; Marked : Boolean := False) return String
   is
      Suffix : constant String :=
        (if Mecha then (if Points < 0 then "MBP" else "MP")
         else (if Points < 0 then "BP" else "CP"));
   begin
      return
        Ada.Strings.Fixed.Trim (Integer'Image (abs Points), Ada.Strings.Left) &
        Mark (Marked) & " " & Suffix;
   end Label_Points;

   function Format_Stat (S : Entities.Stat; Mecha : Boolean) return String is
     (To_String (S.Name) & " " & To_String (S.Value) & " (" &
      Label_Points (S.Points, Mecha, S.Points_Mark) & ")");

   function Format_Derived (D : Entities.Derived_Value) return String is
     (To_String (D.Name) & " " & To_String (D.Value) & Mark (D.Value_Mark) &
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
        (if Length (A.Marked_Details) > 0 then To_String (A.Marked_Details) & ". "
         else "");
   begin
      return
        Emphasized & " (" & Details_Part &
        Label_Points (A.Points, Mecha, A.Points_Mark) & ")";
   end Format_Attribute;

   function Format_Defect (D : Entities.Defect; Mecha : Boolean) return String is
      Details_Part : constant String :=
        (if Length (D.Details) > 0 then To_String (D.Details) & ". " else "");
   begin
      return
        Emphasize (To_String (D.Name)) & " (" & Details_Part &
        Label_Points (D.Points, Mecha, D.Points_Mark) & ")";
   end Format_Defect;

   function Format_Skill (S : Entities.Skill) return String is
      Sep          : constant String := (if Config.Em_Dash then " — " else " ");
      Level_Prefix : constant String := (if Config.Level then "Level " else "");
      Emphasized   : constant String :=
        Emphasize
          (To_String (S.Name) & Sep & Level_Prefix & To_String (S.Level));
      Spec_Part    : constant String :=
        (if not S.Specialisations.Is_Empty
         then Entities.Join (S.Specialisations, ", ") & ". "
         else "");
   begin
      return
        Emphasized & " (" & Spec_Part &
        Ada.Strings.Fixed.Trim (Integer'Image (S.Points), Ada.Strings.Left) &
        Mark (S.Points_Mark) & " SP)";
   end Format_Skill;

   procedure Process_Entity (E : Entities.Entity; Entity_No : Positive) is
   begin
      if E.Has_Name then
         declare
            Header : constant String :=
              To_String (E.Name) & " (" &
              Label_Points (E.Entity_Total, E.Mecha) & ")";
            Underline_Char : constant Character :=
              (if Entity_No > 1 and then Config.Subunderliner /= ASCII.NUL
               then Config.Subunderliner
               else Config.Underliner);
         begin
            IO.Put_Line (Header);
            IO.Put_Line (String'(1 .. Header'Length => Underline_Char));
            IO.New_Line;
         end;
      else
         IO.Put_Line (Label_Points (E.Entity_Total, E.Mecha));
         IO.New_Line;
      end if;

      if E.Has_Tagline then
         IO.Put_Line (Italic (To_String (E.Tagline)));
         IO.New_Line;
      end if;

      if E.Has_Description and then not Config.Omit_Entity_Description then
         IO.Put_Line (To_String (E.Description));
         IO.New_Line;
         if Config.Page_After_Description then
            IO.Put_Line (".. raw:: ms");
            IO.New_Line;
            IO.Put_Line ("   .bp");
            IO.New_Line;
         end if;
      end if;

      if E.Has_Size then
         IO.Put_Line (Bold ("Size:") & " " & To_String (E.Size));
         IO.New_Line;
      end if;

      if not E.Stats.Is_Empty then
         IO.Put (Bold ("Statistics"));
         if Config.Show_Subtotals then
            IO.Put (" (" & Label_Points (E.Stats_Total, E.Mecha) & ")");
         end if;
         IO.Put_Line (" — ");
         for I in E.Stats.First_Index .. E.Stats.Last_Index loop
            if I > E.Stats.First_Index then
               IO.Put (", ");
            end if;
            IO.Put (Format_Stat (E.Stats (I), E.Mecha));
         end loop;
         IO.New_Line;
         IO.New_Line;
      end if;

      if not E.Derived.Is_Empty then
         IO.Put (Bold ("Derived Values") & " — ");
         for I in E.Derived.First_Index .. E.Derived.Last_Index loop
            if I > E.Derived.First_Index then
               IO.Put (", ");
            end if;
            IO.Put (Format_Derived (E.Derived (I)));
         end loop;
         IO.New_Line;
         IO.New_Line;
      end if;

      if not E.Attributes.Is_Empty then
         if E.Mecha then
            IO.Put (Bold ("Mecha Sub-Attributes"));
         else
            IO.Put (Bold ("Attributes"));
         end if;
         if Config.Show_Subtotals then
            IO.Put (" (" & Label_Points (E.Attributes_Total, E.Mecha) & ")");
         end if;
         IO.Put_Line (" — ");
         for I in E.Attributes.First_Index .. E.Attributes.Last_Index loop
            if I > E.Attributes.First_Index then
               IO.Put (", ");
            end if;
            IO.Put (Format_Attribute (E.Attributes (I), E.Mecha));
         end loop;
         IO.New_Line;
         IO.New_Line;
      end if;

      if not E.Defects.Is_Empty then
         if E.Mecha then
            IO.Put (Bold ("Mecha Defects"));
         else
            IO.Put (Bold ("Defects"));
         end if;
         if Config.Show_Subtotals then
            IO.Put (" (" & Label_Points (E.Defects_Total, E.Mecha) & ")");
         end if;
         IO.Put_Line (" — ");
         for I in E.Defects.First_Index .. E.Defects.Last_Index loop
            if I > E.Defects.First_Index then
               IO.Put (", ");
            end if;
            IO.Put (Format_Defect (E.Defects (I), E.Mecha));
         end loop;
         IO.New_Line;
         IO.New_Line;
      end if;

      if not E.Skills.Is_Empty then
         IO.Put (Bold ("Skills"));
         if Config.Show_Subtotals then
            IO.Put
              (" (" &
               Ada.Strings.Fixed.Trim (Integer'Image (E.Skills_Total), Ada.Strings.Left) &
               " SP)");
         end if;
         IO.Put_Line (" — ");
         for I in E.Skills.First_Index .. E.Skills.Last_Index loop
            if I > E.Skills.First_Index then
               IO.Put (", ");
            end if;
            IO.Put (Format_Skill (E.Skills (I)));
         end loop;
         IO.New_Line;
         IO.New_Line;
      end if;

      --  Notes: a bullet list, as in the grid and raw ms formats,
      --  since a note may hold commas and semicolons of its own.
      if not E.Notes.Is_Empty then
         IO.Put_Line (Bold ("Notes:"));
         IO.New_Line;
         for Note of E.Notes loop
            IO.Put_Line (TL.Bullet_Item (To_String (Note)));
         end loop;
         IO.New_Line;
      end if;
   end Process_Entity;

end BESM2_Fmt.Format_Terse;
