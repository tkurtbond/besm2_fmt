with Ada.Text_IO;
with BESM2_Fmt.Config;

package body BESM2_Fmt.Text_Layout is

   package Config renames BESM2_Fmt.Config;
   package IO renames Ada.Text_IO;

   -----------------------------------------------------------------
   --  Display_Length / Pad
   -----------------------------------------------------------------

   function Display_Length (S : String) return Natural is
      Count : Natural := 0;
   begin
      for C of S loop
         --  A UTF-8 continuation byte has the top two bits "10", i.e.
         --  its value falls in 16#80# .. 16#BF#; every other byte --
         --  ASCII, or the lead byte of a multi-byte sequence -- starts
         --  a new codepoint and counts once.
         if Character'Pos (C) not in 16#80# .. 16#BF# then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Display_Length;

   function Pad
     (S : String; Width : Natural; Align : Alignment := Left_Align)
      return String
   is
      Len : constant Natural := Display_Length (S);
   begin
      if Len >= Width then
         return S;
      end if;
      declare
         Fill : constant String (1 .. Width - Len) := (others => ' ');
      begin
         case Align is
            when Left_Align  => return S & Fill;
            when Right_Align => return Fill & S;
         end case;
      end;
   end Pad;

   -----------------------------------------------------------------
   --  Word_Wrap
   -----------------------------------------------------------------

   function Word_Wrap (S : String; Width : Positive) return Line_Vectors.Vector is
      Result  : Line_Vectors.Vector;
      Current : Unbounded_String := Null_Unbounded_String;
      I       : Natural := S'First;
   begin
      if S'Length = 0 then
         Result.Append (Null_Unbounded_String);
         return Result;
      end if;

      while I <= S'Last loop
         declare
            Word_Start : constant Natural := I;
         begin
            while I <= S'Last and then S (I) /= ' ' loop
               I := I + 1;
            end loop;
            declare
               Word : constant String := S (Word_Start .. I - 1);
            begin
               if Length (Current) = 0 then
                  Current := To_Unbounded_String (Word);
               elsif Display_Length (To_String (Current)) + 1 +
                     Display_Length (Word) <= Width
               then
                  Append (Current, " " & Word);
               else
                  Result.Append (Current);
                  Current := To_Unbounded_String (Word);
               end if;
            end;
         end;
         while I <= S'Last and then S (I) = ' ' loop
            I := I + 1;
         end loop;
      end loop;

      Result.Append (Current);
      return Result;
   end Word_Wrap;

   -----------------------------------------------------------------
   --  Put_Row / Separator_Line / Empty_Row
   -----------------------------------------------------------------

   function Wrap_Column_Width (Num_Columns : Positive) return Positive is
     (Config.Table_Width - 2 - (Num_Columns - 1) * (Num_Width + 1));
   --  The last column absorbs whatever space the fixed-width columns
   --  and borders don't use -- exactly besm2-rst.scm's separator-line:
   --  (- *table-width* 1 1 (* (- num-columns 1) (+ *num-width* 1))).

   procedure Put_Row (Cols : Line_Vectors.Vector) is
      N          : constant Positive := Positive (Cols.Length);
      Wrap_Width : constant Positive := Wrap_Column_Width (N);
      Wrapped    : constant Line_Vectors.Vector :=
        Word_Wrap (To_String (Cols (N)), Wrap_Width);
   begin
      for L in 1 .. Positive (Wrapped.Length) loop
         IO.Put ("|");
         for C in 1 .. N - 1 loop
            IO.Put (Pad ((if L = 1 then To_String (Cols (C)) else ""), Num_Width));
            IO.Put ("|");
         end loop;
         IO.Put (Pad (To_String (Wrapped (L)), Wrap_Width));
         IO.Put_Line ("|");
      end loop;
   end Put_Row;

   procedure Separator_Line (Num_Columns : Positive; Fill : Character := '-') is
      Wrap_Width : constant Positive := Wrap_Column_Width (Num_Columns);
   begin
      IO.Put ("+");
      for I in 1 .. Num_Columns - 1 loop
         IO.Put (String'(1 .. Num_Width => Fill));
         IO.Put ("+");
      end loop;
      IO.Put (String'(1 .. Wrap_Width => Fill));
      IO.Put_Line ("+");
   end Separator_Line;

   procedure Empty_Row is
   begin
      IO.Put ("|");
      IO.Put (Pad ("", Config.Table_Width - 2));
      IO.Put_Line ("|");
   end Empty_Row;

   -----------------------------------------------------------------
   --  Bold / Italics / ... emphasis family
   -----------------------------------------------------------------

   function Bold (S : String) return String is ("**" & S & "**");
   function Italics (S : String) return String is ("*" & S & "*");

   function Bolding (S : String) return String is
     (if Config.Bolding then Bold (S) else S);

   function Italicizing (S : String) return String is
     (if Config.Italicizing then Italics (S) else S);

   function Emphasizing (S : String) return String is
     (if Config.Bolding then Bold (S)
      elsif Config.Italicizing then Italics (S)
      else S);

   function Hbolding (S : String) return String is
     (if Config.Bold_Head then Bold (S) else S);

end BESM2_Fmt.Text_Layout;
