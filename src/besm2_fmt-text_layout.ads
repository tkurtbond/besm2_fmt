--  BESM2_Fmt.Text_Layout - fixed-width padding, greedy word-wrap, and
--  the bordered "|...|...|" columnar row renderer that besm2-rst.scm
--  builds out of (schemepunk show)/SRFI 166's `padded`/`wrapped`/
--  `columnar` combinators. Ada has no equivalent library, but the
--  Scheme code only ever uses a narrow slice of it -- always
--  plain-ASCII(-ish), fixed-width, single-font text, with bold/italic
--  just literal "**"/"*" markers baked into the string -- so this is
--  one small, purpose-built package rather than a general show-style
--  engine. See PLAN.md section 3.
--
--  Deliberately independent of BESM2_Fmt.Entities/Libfyaml: everything
--  here operates on plain String/Character, so it's unit-testable
--  without any YAML input at all (see test/test_text_layout.adb).
--  Only the Bold/Italics/... family below depends on BESM2_Fmt.Config,
--  for the CLI flags (-b/--bold, -i/--italics, -B/--no-bold-head) that
--  gate them.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package BESM2_Fmt.Text_Layout is

   type Alignment is (Left_Align, Right_Align);

   function Display_Length (S : String) return Natural;
   --  Number of Unicode codepoints in S, a UTF-8-encoded String --
   --  NOT S'Length (bytes). besm2-rst.scm's data contains multi-byte
   --  UTF-8 text (curly quotes, em dashes, the multiplication sign:
   --  see test-data's "Shots \xd7 2"), and Chicken Scheme's
   --  Unicode-aware string-length -- which is what every one of
   --  *table-width*/*num-width*'s `padded`/`wrapped` column
   --  computations is built on -- counts codepoints, not bytes. Every
   --  width computation in this package has to match that or a column
   --  containing non-ASCII text comes out too narrow and the grid
   --  table's borders stop lining up. Counts UTF-8 lead bytes (any
   --  byte not in 16#80# .. 16#BF#, the continuation-byte range); does
   --  not validate the input is well-formed UTF-8.

   function Pad
     (S : String; Width : Natural; Align : Alignment := Left_Align)
      return String;
   --  Pad S with ASCII spaces to Width display columns (Display_Length,
   --  not S'Length). If S already measures >= Width, returned
   --  unchanged -- matches SRFI 166's `padded`, which never truncates.

   package Line_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Unbounded_String);

   function Word_Wrap (S : String; Width : Positive) return Line_Vectors.Vector;
   --  Greedy word-wrap on runs of ASCII spaces to Width display
   --  columns (one word per gap; multiple spaces between words
   --  collapse to one on rewrap, as with ordinary text-fill
   --  algorithms). A single word longer than Width is not broken --
   --  it is emitted alone on its own line, overrunning Width; this
   --  never comes up in the real BESM data at the default
   --  *table-width* of 60. An empty S yields one empty line, not zero
   --  lines -- a table row still needs a line to print even when its
   --  wrapped column is "".

   Num_Width : constant Positive := 10;
   --  besm2-rst.scm's *num-width*: max(length("LEVEL"),
   --  length("VALUE"), length("POINTS")) = 6, plus the +4 `main`
   --  always adds unconditionally (for the two reST "**" bold-marker
   --  characters wrapped around header cells by `hbolding`) -- applied
   --  even when -B/--no-bold-head is passed, so the header text ends
   --  up with a little slack padding in that case. Ports the Scheme's
   --  arithmetic as-is (PLAN.md section 3: "it's arithmetic, not
   --  show-specific"), not a bug this port should silently fix.

   procedure Put_Row (Cols : Line_Vectors.Vector);
   --  Writes one logical table row -- one or more physical
   --  "|...|...|" lines to Ada.Text_IO.Current_Output -- with
   --  Cols'Length - 1 fixed-width columns (each Num_Width display
   --  columns wide, left-aligned) followed by one wrapped column that
   --  fills the rest of Config.Table_Width. Continuation lines (when
   --  the wrapped column takes more than one physical line) are blank
   --  in every column but the wrapped one. Exactly besm2-rst.scm's
   --  `row2 col1 col2`/`row3 col1 col2 col3`, called with a 2- or
   --  3-element Cols; callers apply Hbolding/Bolding/etc. to build
   --  each column's text themselves before calling this, the same way
   --  the Scheme callers wrap their arguments in `hbolding` before
   --  passing them to row2/row3.

   procedure Separator_Line (Num_Columns : Positive; Fill : Character := '-');
   --  Writes one "+---+---+...+" line: Num_Columns - 1 segments of
   --  Num_Width Fill characters, then one segment absorbing the rest
   --  of Config.Table_Width. The border character is always '+',
   --  matching besm2-rst.scm's separator-line (whose `sep` argument is
   --  literally #\+ at every call site). besm2-rst.scm's sep1/sep2/
   --  sep3 are this with Num_Columns 1/2/3 and Fill = '-' (the
   --  default); headsep2/headsep3 are the same with
   --  Fill = Config.Head_Sep (an '=' by default).

   procedure Empty_Row;
   --  Writes one "| |" line spanning the whole of Config.Table_Width --
   --  besm2-rst.scm's `empty`, used only when -1/--one-table selects a
   --  single combined table instead of one table per section. Not
   --  exercised by any current golden-output test fixture (no test
   --  file's GNUmakefile invocation passes -1), so this is ported by
   --  reading `empty`'s definition rather than verified byte-for-byte;
   --  revisit if a -1 golden fixture turns up a mismatch.

   function Bold (S : String) return String;
   function Italics (S : String) return String;
   --  Always-on "**"/"*" wrapping -- besm2-rst.scm's `bold`/`italics`,
   --  used unconditionally (e.g. entity name underlines, "Size:").

   function Bolding (S : String) return String;
   --  Bold S if -b/--bold (Config.Bolding) was given, else return S
   --  unchanged -- besm2-rst.scm's `bolding`.

   function Italicizing (S : String) return String;
   --  Italicize S if -i/--italics (Config.Italicizing) was given, else
   --  return S unchanged -- besm2-rst.scm's `italicizing`.

   function Emphasizing (S : String) return String;
   --  Bold S if Config.Bolding, else italicize if Config.Italicizing,
   --  else return S unchanged -- besm2-rst.scm's `emphasizing`, used
   --  for attribute/defect/skill names.

   function Hbolding (S : String) return String;
   --  Bold S if Config.Bold_Head (on by default; cleared by
   --  -B/--no-bold-head), else return S unchanged -- besm2-rst.scm's
   --  `hbolding`, used only for grid-table header cells.

end BESM2_Fmt.Text_Layout;
