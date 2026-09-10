with Ada.Characters.Handling;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;
with BESM2_Fmt.Text_Layout;

package body BESM2_Fmt.Entities is

   package Nod renames Libfyaml.Nodes;
   package TL renames BESM2_Fmt.Text_Layout;

   --  Ada.Strings.Fixed.Trim's 2-argument form only strips the space
   --  character, not general whitespace -- unlike Chicken's
   --  string-trim-both (besm2-rst.scm's `details`/`tagline` fields are
   --  trimmed with it), which strips space/tab/newline/CR. That
   --  matters here specifically because a YAML literal block scalar
   --  ("details: |") leaves exactly one trailing newline on the
   --  decoded text, which string-trim-both removes and a plain
   --  space-only Trim doesn't -- left in, that newline ends up
   --  embedded mid-sentence in the formatted output.
   Whitespace : constant Ada.Strings.Maps.Character_Set :=
     Ada.Strings.Maps.To_Set (" " & ASCII.HT & ASCII.LF & ASCII.CR);

   function Trim_Whitespace (S : String) return String is
     (Ada.Strings.Fixed.Trim (S, Whitespace, Whitespace));

   function CI_Less (L, R : Unbounded_String) return Boolean is
     (Ada.Characters.Handling.To_Lower (To_String (L)) <
      Ada.Characters.Handling.To_Lower (To_String (R)));

   package String_Sorting is new String_Vectors.Generic_Sorting ("<" => CI_Less);

   function Attribute_CI_Less (L, R : Attribute) return Boolean is
     (CI_Less (L.Name, R.Name));
   package Attribute_Sorting is new Attribute_Vectors.Generic_Sorting
     ("<" => Attribute_CI_Less);

   function Defect_CI_Less (L, R : Defect) return Boolean is
     (CI_Less (L.Name, R.Name));
   package Defect_Sorting is new Defect_Vectors.Generic_Sorting
     ("<" => Defect_CI_Less);

   function Skill_CI_Less (L, R : Skill) return Boolean is
     (CI_Less (L.Name, R.Name));
   package Skill_Sorting is new Skill_Vectors.Generic_Sorting
     ("<" => Skill_CI_Less);

   function Join (Vec : String_Vectors.Vector; Sep : String) return String is
      Result : Unbounded_String;
   begin
      for I in Vec.First_Index .. Vec.Last_Index loop
         if I > Vec.First_Index then
            Append (Result, Sep);
         end if;
         Append (Result, Vec (I));
      end loop;
      return To_String (Result);
   end Join;

   function Optional_String (Map : Nod.Node; Key : String) return Unbounded_String is
     (if Map.Has_Key (Key) then To_Unbounded_String (Map.String_Value (Key))
      else Null_Unbounded_String);

   function Load_String_List (N : Nod.Node) return String_Vectors.Vector is
      Result : String_Vectors.Vector;

      procedure Add (Element : Nod.Node) is
      begin
         Result.Append (To_Unbounded_String (Element.Scalar_Value));
      end Add;
   begin
      N.Iterate (Add'Access);
      return Result;
   end Load_String_List;

   -----------------------------------------------------------------
   --  format-customizers: an enhancement/limiter list item is
   --  either a plain string, or a sequence of
   --  [name, counts-as, applies-to...] (0 or more applies-to
   --  strings, joined with ", " when there are any -- besm2-rst.scm
   --  match-cases this as "exactly one applies-to string" and
   --  "zero-or-more applies-to strings" separately, but joining a
   --  single-element list is that element, so one length->=3 case
   --  here covers both).
   -----------------------------------------------------------------

   type Customizer_Kind is (Enhancement, Limiter);

   function Sign_For (Kind : Customizer_Kind) return String is
     (if Kind = Enhancement then TL.Minus_Glyph else "+");
   --  Limiter's "+" is always plain ASCII -- -n/--no-unicode-minus
   --  only swaps the negative-number glyph, never "+".

   function Format_Customizers
     (Items : Nod.Node; Kind : Customizer_Kind) return String_Vectors.Vector
   is
      Result : String_Vectors.Vector;

      procedure Add (Item : Nod.Node) is
      begin
         if Item.Is_Scalar then
            Result.Append
              (To_Unbounded_String
                 (Item.Scalar_Value & " " & Sign_For (Kind) & "1"));
         elsif Item.Is_Sequence then
            declare
               Len       : constant Natural := Item.Length;
               Name      : constant String := Item.Item (1).Scalar_Value;
               Counts_As : constant Integer := Item.Item (2).Integer_Value;
               Sign_Str  : constant String :=
                 Sign_For (Kind) &
                 Ada.Strings.Fixed.Trim (Counts_As'Image, Ada.Strings.Both);
            begin
               if Len < 2 then
                  raise Program_Error with "customizer sequence too short";
               elsif Len = 2 then
                  Result.Append (To_Unbounded_String (Name & " " & Sign_Str));
               else
                  declare
                     Applies_To : String_Vectors.Vector;
                  begin
                     for K in 3 .. Len loop
                        Applies_To.Append
                          (To_Unbounded_String (Item.Item (K).Scalar_Value));
                     end loop;
                     Result.Append
                       (To_Unbounded_String
                          (Name & ": " & Join (Applies_To, ", ") &
                           " " & Sign_Str));
                  end;
               end if;
            end;
         else
            raise Program_Error with "do not understand customizer";
         end if;
      end Add;
   begin
      Items.Iterate (Add'Access);
      return Result;
   end Format_Customizers;

   function Make_Attribute_Details
     (Details_Text               : Unbounded_String;
      Enhancements, Limiters, Elements : Nod.Node) return Unbounded_String
   is
      Parts : String_Vectors.Vector;
   begin
      if Elements.Is_Valid then
         declare
            Sorted : String_Vectors.Vector := Load_String_List (Elements);
         begin
            String_Sorting.Sort (Sorted);
            if not Sorted.Is_Empty then
               Parts.Append (To_Unbounded_String (Join (Sorted, ", ")));
            end if;
         end;
      end if;

      declare
         Custom : String_Vectors.Vector;
      begin
         if Enhancements.Is_Valid and then Enhancements.Length > 0 then
            Custom.Append_Vector (Format_Customizers (Enhancements, Enhancement));
         end if;
         if Limiters.Is_Valid and then Limiters.Length > 0 then
            Custom.Append_Vector (Format_Customizers (Limiters, Limiter));
         end if;
         if not Custom.Is_Empty then
            String_Sorting.Sort (Custom);
            Parts.Append (To_Unbounded_String (Join (Custom, ", ")));
         end if;
      end;

      if Length (Details_Text) > 0 then
         Parts.Append (Details_Text);
      end if;

      if Parts.Is_Empty then
         return Null_Unbounded_String;
      end if;

      return To_Unbounded_String (Join (Parts, "; "));
   end Make_Attribute_Details;

   -----------------------------------------------------------------
   --  Per-item loaders.
   -----------------------------------------------------------------

   function Load_Stat (N : Nod.Node) return Stat is
     (Name   => To_Unbounded_String (N.String_Value ("name")),
      Value  => To_Unbounded_String (N.String_Value ("value")),
      Points => N.Integer_Value ("points"));

   function Load_Derived (N : Nod.Node) return Derived_Value is
      Alt_Node : constant Nod.Node := N.Value ("alternatives");
   begin
      return
        (Name  => To_Unbounded_String (N.String_Value ("name")),
         Value => To_Unbounded_String (N.String_Value ("value")),
         Alternatives =>
           (if Alt_Node.Is_Valid then Load_String_List (Alt_Node)
            else String_Vectors.Empty_Vector));
   end Load_Derived;

   function Load_Attribute (N : Nod.Node) return Attribute is
      Name         : constant String := N.String_Value ("name");
      Points       : constant Integer := N.Integer_Value ("points");
      Level_Text   : Unbounded_String := To_Unbounded_String (N.String_Value ("level"));
      Details_Text : Unbounded_String := Optional_String (N, "details");
      Effective    : constant Unbounded_String := Optional_String (N, "effective");
      Enhancements : constant Nod.Node := N.Value ("enhancements");
      Limiters     : constant Nod.Node := N.Value ("limiters");
      Elements     : constant Nod.Node := N.Value ("elements");
   begin
      if Length (Details_Text) > 0 then
         Details_Text :=
           To_Unbounded_String (Trim_Whitespace (To_String (Details_Text)));
      end if;
      if Length (Effective) > 0 then
         Level_Text := Level_Text & " (" & Effective & ")";
      end if;
      return
        (Name    => To_Unbounded_String (Name),
         Level   => Level_Text,
         Points  => Points,
         Details =>
           Make_Attribute_Details (Details_Text, Enhancements, Limiters, Elements));
   end Load_Attribute;

   function Load_Defect (N : Nod.Node) return Defect is
      Name         : constant String := N.String_Value ("name");
      Points       : constant Integer := N.Integer_Value ("points");
      Details_Text : Unbounded_String := Optional_String (N, "details");
   begin
      if Length (Details_Text) > 0 then
         Details_Text :=
           To_Unbounded_String (Trim_Whitespace (To_String (Details_Text)));
      end if;
      return
        (Name => To_Unbounded_String (Name), Points => Points, Details => Details_Text);
   end Load_Defect;

   function Load_Skill (N : Nod.Node) return Skill is
      Specialisations_Node : constant Nod.Node := N.Value ("specialisations");
   begin
      return
        (Name   => To_Unbounded_String (N.String_Value ("name")),
         Level  => To_Unbounded_String (N.String_Value ("level")),
         Points => N.Integer_Value ("points"),
         Specialisations =>
           (if Specialisations_Node.Is_Valid
            then Load_String_List (Specialisations_Node)
            else String_Vectors.Empty_Vector));
   end Load_Skill;

   -----------------------------------------------------------------
   --  Load_Entity.
   -----------------------------------------------------------------

   function Load_Entity (N : Nod.Node) return Entity is
      Result : Entity;

      procedure Load_Stats_Field is
         Stats_Node : constant Nod.Node := N.Value ("stats");
         procedure Add (Item : Nod.Node) is
         begin
            Result.Stats.Append (Load_Stat (Item));
         end Add;
      begin
         if Stats_Node.Is_Valid then
            Stats_Node.Iterate (Add'Access);
            for S of Result.Stats loop
               Result.Stats_Total := Result.Stats_Total + S.Points;
            end loop;
         end if;
      end Load_Stats_Field;

      procedure Load_Derived_Field is
         Derived_Node : constant Nod.Node := N.Value ("derived");
         procedure Add (Item : Nod.Node) is
         begin
            Result.Derived.Append (Load_Derived (Item));
         end Add;
      begin
         if Derived_Node.Is_Valid then
            Derived_Node.Iterate (Add'Access);
         end if;
      end Load_Derived_Field;

      procedure Load_Attributes_Field is
         Attrs_Node : constant Nod.Node := N.Value ("attributes");
         procedure Add (Item : Nod.Node) is
         begin
            Result.Attributes.Append (Load_Attribute (Item));
         end Add;
      begin
         if Attrs_Node.Is_Valid then
            Attrs_Node.Iterate (Add'Access);
            Attribute_Sorting.Sort (Result.Attributes);
            for A of Result.Attributes loop
               Result.Attributes_Total := Result.Attributes_Total + A.Points;
            end loop;
         end if;
      end Load_Attributes_Field;

      procedure Load_Defects_Field is
         Defects_Node : constant Nod.Node := N.Value ("defects");
         procedure Add (Item : Nod.Node) is
         begin
            Result.Defects.Append (Load_Defect (Item));
         end Add;
      begin
         if Defects_Node.Is_Valid then
            Defects_Node.Iterate (Add'Access);
            Defect_Sorting.Sort (Result.Defects);
            for D of Result.Defects loop
               Result.Defects_Total := Result.Defects_Total + D.Points;
            end loop;
         end if;
      end Load_Defects_Field;

      procedure Load_Skills_Field is
         Skills_Node : constant Nod.Node := N.Value ("skills");
         procedure Add (Item : Nod.Node) is
         begin
            Result.Skills.Append (Load_Skill (Item));
         end Add;
      begin
         if Skills_Node.Is_Valid then
            Skills_Node.Iterate (Add'Access);
            Skill_Sorting.Sort (Result.Skills);
            for S of Result.Skills loop
               Result.Skills_Total := Result.Skills_Total + S.Points;
            end loop;
         end if;
      end Load_Skills_Field;

   begin
      Result.Has_Name := N.Has_Key ("name");
      if Result.Has_Name then
         Result.Name := To_Unbounded_String (N.String_Value ("name"));
      end if;

      Result.Has_Tagline := N.Has_Key ("tagline");
      if Result.Has_Tagline then
         Result.Tagline :=
           To_Unbounded_String
             (Trim_Whitespace (N.String_Value ("tagline")));
      end if;

      Result.Has_Description := N.Has_Key ("description");
      if Result.Has_Description then
         Result.Description := To_Unbounded_String (N.String_Value ("description"));
      end if;

      Result.Has_Size := N.Has_Key ("size");
      if Result.Has_Size then
         Result.Size := To_Unbounded_String (N.String_Value ("size"));
      end if;

      Result.Mecha := N.Boolean_Value ("mecha", Default => False);
      --  Not N.Has_Key ("mecha"): that's true whenever the key is
      --  merely present, regardless of its value, so "mecha: false"
      --  would turn mecha mode ON same as "mecha: true" -- fixed
      --  upstream in besm-tools commit 8da3e95 (besm2-rst.scm's
      --  mecha? was parameterized straight off `(assoc "mecha"
      --  entity)`, a pair and hence truthy either way; switched to
      --  its own may-exist helper, which unwraps to the real
      --  #t/#f/absent value). Boolean_Value's optional-with-default
      --  form is the direct Ada equivalent.

      Load_Stats_Field;
      Load_Derived_Field;
      Load_Attributes_Field;
      Load_Defects_Field;
      Load_Skills_Field;

      Result.Entity_Total :=
        Result.Stats_Total + Result.Attributes_Total + Result.Defects_Total;

      return Result;
   end Load_Entity;

end BESM2_Fmt.Entities;
