# besm2_fmt: porting `besm2-rst.scm` to Ada

**Source being ported:**
[`besm2-rst.scm`](https://github.com/tkurtbond/besm-tools/blob/main/besm2-rst.scm)
(Chicken Scheme, 1219 lines), part of the
[BESM Tools](https://github.com/tkurtbond/besm-tools) suite
(`README.rst` in that repo). It converts a YAML BESM 2E
character/template/item file into reStructuredText, in one of four
output formats selected by CLI flag.

**Target:** an Ada program, `besm2_fmt`, built on
[`alibfyaml`](https://github.com/tkurtbond/alibfyaml), the Ada binding
to libfyaml's core parser/document/emitter API.

## 1. Why this is a real port, not a transliteration

Two things don't map 1:1 and need actual design work:

- **`(schemepunk show)` / SRFI 166.** Everything renders through `show`
  combinators — `columnar`, `wrapped`, `padded`, `displayed`, `each`,
  `joined`. Ada has no equivalent library. But looking closely at *how*
  it's used here, the requirement is narrower than full SRFI 166: it's
  always plain-ASCII, fixed-width, single-font text (bold/italic are just
  literal `**`/`*` markers baked into the string — note
  `(set! *num-width* (+ *num-width* 4))` in `main`, which manually
  compensates column width for `**...**` markup rather than relying on
  span-aware width measurement). So the port doesn't need a general
  show-style engine — it needs one small, purpose-built `Text_Layout`
  package: fixed-width padding, greedy word-wrap to a column width, and a
  "columnar row" renderer that emits one or more bordered `|...|...|`
  physical lines per logical row (continuation lines blank in all but the
  wrapped column) — i.e. exactly what `row2`/`row3`/`separator-line` need,
  nothing more.
- **YAML's implicit typing vs. libfyaml core.** Chicken's `yaml` egg
  decodes scalars into native Scheme numbers/booleans automatically, so
  `points`, `level`, `value` arrive as numbers and arithmetic (`+`, `sum`,
  `<`) just works. `alibfyaml`'s core layer (deliberately, matching
  upstream libfyaml) hands back scalar *text* — no implicit typing. So
  every numeric field needs an explicit `Scalar_Value` → `Integer'Value`
  step in Ada. This is mechanical but touches nearly every accessor
  function, so it belongs in one small helper layer, not scattered ad hoc.

Everything else — `must-exist`/`may-exist` alist lookups, the
`match`-based `format-customizers`, sorting, the four format backends —
maps onto `alibfyaml`'s `Node`/`Document` API cleanly with no gaps. The
top-level document is a YAML **sequence** of entity mappings (`Doc.Root`
→ `Length`/`Item`/`Iterate` on a sequence node), and every field lookup
in the Scheme code is a flat key access (`assoc "name" entity`), never a
path expression — so `Node.Value("key")` covers all of it; `By_Path`
isn't needed for this port.

## 2. Package layout

```
besm2_fmt/
  src/
    besm2_fmt.ads                    -- empty root package, anchors the BESM2_Fmt.* children
    besm2_fmt-config.ads             -- CLI-settable globals (was the *star* specials) [done]
    besm2_fmt-text_layout.ads/.adb   -- pad/wrap/columnar-row rendering; bold/italics/emphasis [done]
    besm2_fmt-entities.ads/.adb      -- domain types: Stat, Derived, Attribute, Defect, Skill,
                                         Entity, built by walking Nodes once per entity;
                                         format-customizers/make-attribute-details live here
                                         too (private to the body), not a separate file as
                                         originally sketched -- there was no other consumer
                                         to justify splitting them out [done]
    besm2_fmt-format_grid.ads/.adb   -- process-entity (reST grid table) [done]
    besm2_fmt-format_terse.ads/.adb  -- process-entity-terse [done]
    besm2_fmt-format_hmm.ads/.adb    -- process-entity-hmm [done]
    besm2_fmt-format_raw_ms.ads/.adb -- process-entity-raw-ms [done]
    besm2_fmt-cli.ads/.adb           -- argument parsing (the args:make-option table), via arg_parser [done]
    besm2_fmt_main.adb               -- main: parse args, open input(s), dispatch, write output
  besm2_fmt.gpr
```

Root package `BESM2_Fmt.*` (BESM2 kept upper-case as the abbreviation
it is — Big Eyes, Small Mouth, 2nd edition; file, executable, project,
and repo names stay lowercase `besm2_fmt` per Unix/GNAT convention,
same as `alibfyaml` uses `Libfyaml_Ada` as its package/project
identifier alongside lowercase file names), executable and project
file `besm2_fmt`/`besm2_fmt.gpr`.

Two naming wrinkles found while actually implementing this (not
apparent from the plan alone): a child package hierarchy's parent
(`BESM2_Fmt`) must itself be a real library unit, so an otherwise-empty
`besm2_fmt.ads` exists purely to anchor `BESM2_Fmt.Config`/
`BESM2_Fmt.Cli`; and the executable entry point can't be a procedure
literally named `BESM2_Fmt` (Ada identifiers are case-insensitive, so
casing it differently doesn't help either) since that collides with
the children's parent package name — it's `BESM2_Fmt_Main`
(`besm2_fmt_main.adb`) instead, with `besm2_fmt.gpr`'s `Builder.Executable`
renaming just the *produced binary* back to `besm2_fmt`.

`BESM2_Fmt.Entities` is a deliberate addition with no Scheme counterpart:
the Scheme code re-walks the raw alist on every access (`must-exist
"name" attribute` scattered across each `process-*` and
`process-*-terse`/`-hmm`/`-raw-ms` variant — the same attribute gets
decoded up to 4 times across the 4 backends when you count them all). In
Ada it's better to parse each entity's YAML subtree into a small typed
record **once** (`Load_Entity : Node → Entity`), then have all four
format backends consume the same typed data. This removes a good chunk
of the duplication that exists in the Scheme (which pays that cost once
per format because each backend was copy-pasted and hand-edited) and
gives one place to catch/report malformed input instead of four.

## 3. `Text_Layout` — the core new subsystem

This is the piece with actual design risk, so it's worth detailing:

- `Pad (S : String; Width : Natural; Align : Left_Align | Right_Align) return String`
- `Word_Wrap (S : String; Width : Positive) return String_Vector` — greedy
  wrap on space boundaries (matches what `wrapped` does for plain
  unstyled text)
- `Put_Row (Cols : array of (Width, Text, Wrap : Boolean))` — renders N
  columns bordered by `|`, wrapping only the designated (last) column and
  repeating blank-padded cells for the other columns on continuation
  lines. This directly replaces `row2`/`row3`/`separator-line`/`empty`.
- `Bold`, `Italics`, `Emphasizing`, `Bolding`, `Hbolding` — trivial
  string-wrapping functions gated on `Config` flags (`*bolding*`,
  `*italicizing*`, `*bold_head*`).

Table width bookkeeping (`*table-width*`, `*num-width*`, the `+4` bold
compensation) ports as-is — it's arithmetic, not `show`-specific.

## 4. Numeric/type-conversion layer

This was originally planned as a `BESM2_Fmt.Yaml_Access` package
implementing `Must_Exist`/`May_Exist`/`Must_Integer`/`May_Integer`
etc. from scratch, wrapping `Scalar_Value` + `Integer'Value` by hand.
On reflection that layer is generically useful to any `alibfyaml`
consumer, not specific to this tool, so it's being built into
`alibfyaml` itself instead — see `alibfyaml`'s `PLAN.md` ("Typed
scalar accessors, timestamps, and document resolution"). That plan
adds exactly this shape directly to `Libfyaml.Nodes`: required and
optional-with-default forms of `Integer_Value`, `Long_Integer_Value`,
`Long_Long_Integer_Value`, `Float_Value`, `Long_Float_Value`,
`Boolean_Value`, and `String_Value` on a `(Map, Key)` pair, raising
`Libfyaml.Missing_Key` (absent required key) or `Libfyaml.Data_Error`
(present but malformed) — the same missing-vs-malformed distinction
this section originally called for.

**Consequence for this project:** `besm2_fmt` doesn't need its own
`Yaml_Access` package for generic typed access at all once that
`alibfyaml` work lands — call `Libfyaml.Nodes`'s accessors directly
(e.g. `Attribute.Integer_Value ("points")`). What's left as
`besm2_fmt`-specific is just: (a) catching `Missing_Key`/`Data_Error`
at the top of `main` and turning them into the `die 2 "..."` exit-code-2
stderr behavior the Scheme version has, and (b) the domain-specific
`format-customizers` dispatch below, which isn't a generic
typed-access problem and stays here. This is a **build-order
dependency**, not just a design note: the `alibfyaml` typed-accessors
work needs to land (at least the Integer/Float/Boolean/String pieces)
before step 2 of the build order below can be done the intended way,
rather than as a throwaway local shim.

`format-customizers`' `match` becomes explicit dispatch on the
enhancement/limiter list-item node: scalar → string case; sequence of
length 2 → `[name, counts-as]`; length 3 with a scalar third element →
`[name, counts-as, applies-to]`; length ≥3 otherwise → `[name,
counts-as, applies-to...]`. All four shapes appear or are plausible from
`FV2021-Coleopteran-4e.yaml`'s `enhancements`/`limiters` lists (`[Range,
5]`, `Area`, etc.), even though no *2e* test file happens to exercise
them yet.

## 5. CLI parsing

Uses [`arg_parser`](https://github.com/tkurtbond/arg_parser)
(`~/Repos/Ada/arg_parser`), not `GNAT.Command_Line`. Dependency
mechanism is already settled, unlike `alibfyaml`'s (see Open
questions): `arg_parser` is installed under
`/usr/local/sw/versions/ada/`, and `GPR_PROJECT_PATH` already includes
`/usr/local/sw/versions/ada/share/gpr`, so a plain `with "arg_parser.gpr";`
in `besm2_fmt.gpr` resolves it with no path or Alire dependency needed.

(One correction from how this requirement was first described: the
relevant env var is `GPR_PROJECT_PATH`, not `GPR_INCLUDE_PATH` — the
latter isn't a `gprbuild` variable. Confirmed set in this environment
already, pointing at `/usr/local/sw/versions/ada/share/gpr`, which is
exactly where `arg_parser.gpr` and its compiled `.ali`/library live.)

`arg_parser` intermingles option/argument processing in declaration
order (see its README) rather than parsing all options up front, and
represents each option as a value of its `Option` type built by one of
several `Make_*_Option` constructors — a `Handler` function called on
the option's argument, or a `Variable` set directly, depending on the
constructor. The Scheme's `+command-line-options+` table (~20 flags:
`-1/--one`, `-B`, `-b`, `-D`, `-d`, `-H`, `-L`, `-R`, `-S`, `-h`, `-i`,
`-l`, `-M`, `-m`, `-o`, `-p`, `-s`, `-t`, `-U`, `-u`, `-w`) maps onto
these fairly directly, in four groups:

- **Plain boolean flags** (`-B`/`--no-bold-head`, `-b`/`--bold`,
  `-D`/`--omit-description`, `-d`/`--debug`, `-S`/`--hmm-separate`,
  `-i`/`--italics`, `-l`/`--level`, `-M`/`--em-dash`,
  `-p`/`--page`, `-s`/`--subtotals`): `Make_Set_Boolean_True_Option`
  (or `_False_` for `-B`, which is the one flag that turns a
  default-on setting off), each with `Variable` pointing at an
  `aliased Boolean` field of a `Config` record.
- **Output-format selection** (`-t`/`--terse`, `-H`/`--hmm`,
  `-m`/`--raw-ms-tables`, and no flag for the reST-grid default): the
  Scheme's `(set! *output-formatter* process-entity-X)` — "whichever
  was named last wins" — maps onto a single `Output_Format` enum
  variable (`Grid | Terse | Hmm | Raw_Ms`) rather than onto a set of
  independent booleans. `-t`/`-H`/`-m` each become a `Make_Option`
  (no-argument) whose `Handler` sets that one variable and returns
  `True` — `-H` additionally needs to set `*hmm-output*` too (a
  "set two things from one flag" case; the handler just does both).
- **Required-argument options**: `-L`/`--hmm-depth` and `-w`/`--width`
  are `Make_Set_Natural_Option`/`Make_Set_Positive_Option` (numeric,
  so `arg_parser` validates and converts for free — no
  `string->number` equivalent to hand-write); `-R`/`--hmm-root` and
  `-o`/`--output` are `Make_Set_String_Option` (`Variable` is a
  `String_Reference`, i.e. `access all String` — see `arg_parser`'s
  README on why: you can't point at an unconstrained `String`
  directly). `-U`/`--subunderliner` and `-u`/`--underliner` take a
  single character (the Scheme does `(string-ref arg 0)`); no
  dedicated `Character` option kind exists, so these use
  `Make_String_Option` with a `Handler` that validates
  `Arg'Length = 1` and extracts `Arg (Arg'First)`.
- **`-h`/`--help`**: `Make_Option` with a `Handler` that calls `Usage`
  on the parser and then unwinds — `arg_parser`'s own
  `examples/src/simple2_args.adb` (`Do_Help`) does exactly this
  (raise a local `End_Program` exception after printing usage), so
  `besm2_fmt` follows the same pattern rather than inventing one.

Following `arg_parser`'s own recommended non-`'Unrestricted_Access`
style (`examples/src/simple2_args.ads`/`.adb`, not `simple.adb`'s
single-file version): `Config`'s fields are `aliased` package-level
state in `BESM2_Fmt.Config`, and `BESM2_Fmt.Cli` holds the `Handler`
functions, the `Options : aliased Option_Array`, and the `Parser`
value built by `Make_Parser`, referencing `Config`'s fields via
`'Access`. This also removes the Scheme's `parameterize`/dynamic-scoping
pattern (`mecha?`, `*hmm-depth*`) — `Config` (and, for
`mecha?`/`hmm-depth`, explicit parameters or a small mutable "render
state" record) is threaded through the four format backends instead.

## 6. A behavior worth flagging before porting it faithfully

`(mecha? (assoc "mecha" entity))` — `assoc` returns a pair (truthy)
whenever the key **exists**, regardless of its YAML value. So `mecha:
false` would still turn mecha-mode on, same as `mecha: true`. This is
almost certainly an unintentional latent quirk in the Scheme rather than
a deliberate design choice (nothing in the design-decision comments at
the top of the file mentions it).

**Resolved:** confirmed a bug, fixed upstream in besm-tools commit
`8da3e95` (`besm2-rst.scm`'s `mecha?` now parameterized off the
existing `may-exist` helper — used everywhere else in the file for
"optional field, `#f` if absent" — instead of the raw `assoc` result).
`BESM2_Fmt.Entities.Load_Entity` (`besm2_fmt-entities.adb`) updated to
match: `N.Boolean_Value ("mecha", Default => False)` instead of
`N.Has_Key ("mecha")`. Verified against the rebuilt `besm2-rst`
binary with a synthetic `mecha: true`/`false`/absent fixture across
all four output formats (byte-for-byte match in all three cases), and
confirmed no regression on the real 2E golden fixtures (none of which
use `mecha: false` — `FV2021-Coleopteran-2e.yaml`'s `mecha: true` is
unaffected either way).

## 7. Testing strategy

[`test-data/*.yaml`](https://github.com/tkurtbond/besm-tools/tree/main/test-data)
(11 files) plus the `GNUmakefile`'s existing invocation patterns
(`-s`, `-t`, `-m` combinations feeding `pandoc`) give ready-made
golden inputs. Plan: run the existing Chicken binary on each
test file in each mode, save output, then diff the Ada port's output
byte-for-byte against it as the acceptance test — much stronger than
eyeballing, and catches whitespace/wrapping regressions the eye would
miss.

## 8. Suggested build order

1. [done] `Text_Layout` in isolation (unit-testable without any YAML
   at all) — `test/test_text_layout.adb` (`test/test.gpr`, a small
   sibling project mirroring `alibfyaml`'s own `test/test.gpr`
   pattern), 30 checks, all passing (includes `Minus_Glyph`'s two
   states, added alongside the `-n`/`--unicode-minus` port -- see
   below). `Put_Row`/`Separator_Line` are
   checked against the real golden STAT-table fragment from
   `enyon-boase-2e.gen.rst` byte-for-byte (captured via
   `Ada.Text_IO.Set_Output` to a temp file and read back), not just
   eyeballed. One real design issue surfaced here, not apparent from
   the plan alone: besm2-rst.scm's test data contains multi-byte UTF-8
   text (curly quotes, an em dash, the multiplication sign — see
   `test-data`'s "Shots ×2"), and Chicken Scheme's `string-length` is
   Unicode-codepoint-aware, which is what every `*num-width*`/
   `*table-width*` column computation is built on. A naive Ada port
   using `String'Length` would count UTF-8 continuation bytes as extra
   columns and come out narrower than the real output wherever
   non-ASCII text appears. Fixed with a `Display_Length` function
   (counts bytes outside the `16#80#..16#BF#` continuation-byte range)
   used everywhere `Pad`/`Word_Wrap` measure width, instead of
   `'Length`. Verified directly: `Word_Wrap` of the real
   "Weapon: Rocket Pod ... Shots ×2 [3 shots], Stoppable)" attribute
   text at width 36 reproduces the golden output's exact three-line
   break.
2. [done] `Entities` against `alibfyaml` (using its typed accessors
   directly — see §4).
3. [done] **Terse backend first** — it does zero column layout, so it
   validates CLI + data access + domain formatting before touching the
   harder `Text_Layout` row renderer. Validated against besm-tools'
   *actual* golden output (`build/*-2e-terse.gen.rst`, built by its
   `GNUmakefile` from the real `besm2-rst` binary) rather than just
   eyeballing: byte-for-byte diff, zero differences, on both 2E
   test-data files, via a file argument, via stdin, and via
   `-o`/--output`. One real bug found this way: `Ada.Strings.Fixed.Trim`'s
   2-argument form only strips spaces, not the trailing newline a YAML
   literal block scalar (`details: |`) leaves on the decoded text —
   Scheme's `string-trim-both` strips general whitespace, so that
   newline was staying embedded mid-sentence in the Ada output until
   fixed with an explicit whitespace `Character_Set`.
4. [done] Grid-table backend (`Format_Grid`, `process-entity`'s
   process-stat/process-derived/process-attribute/process-defect/
   process-skill) — exercises `Text_Layout` fully, and is now
   besm2_fmt's default output (no flag needed, matching
   `*output-formatter*`'s Scheme default). `row2`/`row3`/`sep2`/`sep3`/
   `headsep2`/`headsep3` are ported as same-named thin local wrappers
   over `Text_Layout.Put_Row`/`Separator_Line`, so `Format_Grid`'s body
   reads next to `besm2-rst.scm`'s `process-entity` with minimal
   translation. Verified byte-for-byte against besm-tools' real
   `build/*-2e.gen.rst` golden output on both 2E test-data files, via
   file argument, stdin, and `-o`/`--output`, plus the
   `composite-2e.yaml`/`composite-multi-doc-2e.yaml` multi-document
   equivalence check. One real bug found this way, distinct from
   Terse's: `Text_Layout.Word_Wrap` only split words on ASCII space, so
   a `details: |` YAML literal block scalar's *embedded* newline (not
   the trailing one Terse's fix already covered — see below) got
   carried through as literal word content instead of being treated as
   a word break. Confirmed against `FV2021-Coleopteran-2e.yaml`'s
   "Weapon: Rocket Pod" attribute, whose two-line `details: |` block
   re-fills as one continuous phrase in the real golden output; the
   unfixed Ada version instead printed the embedded `\n` raw, splitting
   a table row's `|...|` borders across two malformed physical lines.
   Fixed by making `Word_Wrap` treat any of space/LF/CR/HT as a word
   boundary, not just `' '` — a permanent regression test for this
   exact case (the two-line block scalar, not just a pre-joined
   single-line string) is in `test/test_text_layout.adb`. Two
   grid-specific things intentionally live only in `Format_Grid`, not
   `Entities`, because Terse's golden output proves they're
   format-specific rather than domain data: `derived-abbreviations`
   (`ACV` → `Attack Combat Value` etc. — Terse's golden output keeps
   the raw abbreviation) and the "Mecha Sub-Attributes"/"Mecha
   Defects"/label-points (`CP`/`BP`/`MP`/`MBP`) machinery, which
   `process-entity` (grid) never uses at all, unlike
   `process-entity-terse`/`-hmm`.
5. [done] `h-m-m` backend (`Format_Hmm`, `process-entity-hmm`'s
   process-stat-hmm/process-derived-hmm/process-attribute-hmm/
   process-defect-hmm/process-skill-hmm) — a tab-indented outline, one
   node per line, structurally closest to Terse's per-item formatting
   (Stat/Derived/Skill text assembly is byte-identical to Terse's;
   Attribute/Defect differ only in wrapping `details` with
   `All_One_Line`) but with Grid-like Mecha-label/subtotal machinery
   per section. `besm2-rst.scm`'s `*hmm-depth*` SRFI-39 parameter and
   nested `depth+`/`parameterize` become a plain `Natural` computed
   once per `Process_Entity` call from `Config.Hmm_Depth` (the `-L`
   baseline) — `depth+`'s `parameterize` never actually accumulates
   *across* entities (its dynamic extent ends before the next one), so
   there's nothing to thread between calls. No golden `build/*.hmm`
   file existed to diff against (unlike Grid/Terse's `GNUmakefile`
   targets), so golden output was generated directly from
   besm-tools' real compiled `besm2-rst` binary
   (`build/besm2-rst`) across several flag combinations
   (`-s`, `-S`, `-b`, `-i`, `-l`, `-M`, `-R`/`-L`, the Mecha entity,
   and the multi-entity composite fixture) and diffed byte-for-byte;
   all pass. (Note: `entity-styles.hmm` in the besm-tools checkout
   looks like a hand-edited/stale sample, not a mechanically generated
   one — e.g. it has an unmatched `**` around "Defects" — so it wasn't
   used as a reference.) Two real findings from the golden diffs, both
   confirmed against the actual Scheme source rather than assumed:
   - `process-skill-hmm`'s `emphasizing` call wrapped the *entire* rest
     of the line, "`(N SP)`" included — unlike
     `process-attribute-hmm`/`process-defect-hmm` (which close
     `emphasizing` right after name+level, matching Terse's skill
     formatting too). Confirmed with `-b`: `**Interrogation 1 (2
     SP)**`, not `**Interrogation 1** (2 SP)`. Confirmed as a genuine
     upstream bug (not a deliberate design choice) and fixed at the
     source — see the former open question below, now resolved.
   - The `-R`/`--hmm-root` root-node line
     (`besm2-rst.scm`'s `main`: `(when (and *hmm-output* *hmm-root*)
     ...)`) prints once per program run, before the `-o`/`--output`
     file redirection is set up — so it always goes to standard
     output, even when `-o` sends everything else to a file.
     Confirmed against the real binary and ported faithfully (in
     `BESM2_Fmt_Main`, not `Format_Hmm`, since it's a once-per-run
     concern, not once-per-entity) rather than treated as a bug to
     route around.
   Also confirmed, matching an existing asymmetry already visible by
   reading the source: the Statistics section's subtotal has a
   trailing space before its newline (`" (...) "`) that
   Attributes/Defects/Skills' subtotals don't — an actual
   inconsistency in `besm2-rst.scm` itself, ported as-is like the
   `mecha?` existence-check quirk below.
6. [done] raw-`ms`/`tbl` backend (`Format_Raw_Ms`,
   `process-entity-raw-ms`'s process-stat-raw-ms/process-derived-raw-ms/
   process-attribute-raw-ms/process-defect-raw-ms/process-skill-raw-ms)
   — a single `.TS`/`.TE` groff `tbl` table per entity wrapped in one
   `.. raw:: ms` reST block, `tbold`/`T{...T}` markup instead of reST
   grid syntax. Needed no `Text_Layout` column-layout code at all
   beyond `Bold`/`Italics` for the plain-reST portion before the
   table (name/tagline/size) — `tbl`'s own `x` (expand) column
   modifier and `T{...T}` text blocks handle column widths and
   wrapping at *render* time, so there's nothing for a fixed-width
   renderer to precompute, unlike Grid. Two bookkeeping variables
   (`Paragraph_Seen`, `First_Section_Seen`) replace the Scheme's
   `set!`-mutated locals directly, one-for-one. Verified byte-for-byte
   against besm-tools' real `build/*-2e-tbl.gen.rst` golden output on
   both 2E test-data files (file argument, stdin, `-o`/`--output`),
   plus fresh output from the real `besm2-rst` binary with `-s`/`-1`,
   the Mecha entity, and the multi-entity composite fixture. No new
   findings this time — the two real quirks this backend shares with
   Grid/Hmm (`derived-abbreviations` expansion, `mecha?`'s
   existence-check) were already known from those two backends, and
   its own two format-specific asymmetries (the grand TOTAL row only
   printing when positive, `> 0` — unlike Grid's unconditional one —
   and Stats never needing the `First_Section_Seen` check that
   Derived/Attributes/Defects/Skills do, since Stats is always first
   in entity field order when present at all) were caught by reading
   the source structurally before writing any code, not found via a
   diff mismatch. `titalics` (besm2-rst.scm's troff-italics
   counterpart to `tbold`) is defined right next to `tbold` in the
   Scheme but never actually called anywhere in the file — confirmed
   dead code in the original, so not ported.

All four output formats (`Format_Grid`, `Format_Terse`, `Format_Hmm`,
`Format_Raw_Ms`) are now implemented and wired into `BESM2_Fmt_Main`;
`besm2_fmt` has full functional parity with `besm2-rst.scm`.

`-n`/`--unicode-minus` (`Config.Unicode_Minus`) was ported from
besm-tools commits `5b9a72d`/`3bdc429`/`5cb3d92`: switches the glyph
used for a negative number this program builds itself (ASCII
hyphen-minus by default, or Unicode MINUS SIGN U+2212) between
`BESM2_Fmt.Text_Layout.Minus_Glyph` (the single shared source of
truth, alongside Bold/Italics/... since it's the same
"Config-gated text choice" shape) and three call sites:
`BESM2_Fmt.Entities.Sign_For` (enhancement/limiter signs baked into
an attribute's `Details` at load time, so this affects all four
backends' attribute descriptions, not just Grid/Raw_Ms — matches
besm2-rst.scm's `make-attribute-details` being called from all four
`process-attribute*` variants too), and `Format_Grid`/`Format_Raw_Ms`'s
own `Defect_Points_Image`/`Signed_Points_Image` (defect points and the
DEFECTS TOTAL/TOTAL rows — the latter needed for the same reason the
upstream `5cb3d92` fix was needed: those totals were being built with
plain `Integer'Image`, bypassing the glyph). `Format_Terse`/`Format_Hmm`
need no changes at all — their own defect-point rendering is
`Label_Points`' "N BP"/"N CP" suffix, never a sign glyph. Verified
byte-for-byte against besm-tools' real `besm2-rst` binary across all
four formats, with and without `-n`, including the enhancement/limiter
path (a synthetic fixture, since no committed 2E test-data file has
them). `Minus_Glyph`'s two states (default ASCII hyphen-minus; Unicode
MINUS SIGN once `Config.Unicode_Minus` is set) are covered by a
permanent regression test in `test/test_text_layout.adb` (§8 item 1),
checked against the exact U+2212 UTF-8 bytes rather than just
eyeballed.

`PERFORMANCE-COMPARISON.md` documents a performance comparison against
`besm2-rst`, reproducible via `tools/benchmark.sh`/`make benchmark`
(env vars: `BESM2_RST`, `BENCH_N`, `BENCH_ENTITIES`, `BENCH_SOURCE` —
see the script's header comment). Measures both per-invocation
overhead (many runs of a tiny real fixture) and throughput (one run
on a generated large fixture), in two distinct shapes: one big
multi-entity document, and a genuinely multi-document file (which
also happens to be a good way to observe `besm2-rst.scm`'s
multi-document-collapsing bug and `Document_Stream`'s streaming
memory behavior side by side, on purpose rather than by accident).
Linux/GNU-coreutils-specific (GNU `time` for RSS, GNU `date` for
sub-second timing) — not portable to macOS/BSD as written.

## Open questions

- ~~**`mecha?` semantics**~~ (§6): Resolved: confirmed a bug (same
  shape as the `process-skill-hmm` one below — a latent quirk, not a
  documented design decision), fixed upstream in besm-tools commit
  `8da3e95` and ported to `BESM2_Fmt.Entities.Load_Entity`. See §6 for
  detail.
- ~~**`process-skill-hmm`'s over-wide `emphasizing` scope**~~ Resolved:
  confirmed an unintentional bug in `besm2-rst.scm` itself (not a
  deliberate design choice — `process-attribute-hmm`/`process-defect-hmm`
  and `process-skill-terse` all close `emphasizing` right after
  name+level; `process-skill-hmm` alone kept it open through the entire
  rest of the line, `" SP)"` included). Fixed upstream in besm-tools
  commit `b04abb5` (`besm2-rst.scm`, moved `emphasizing`'s closing paren
  to right after `level`) and re-verified: `-b`/`--bold` now produces
  `**Interrogation 1** (2 SP)`, matching attribute/defect/terse-skill.
  `BESM2_Fmt.Format_Hmm.Format_Skill` updated to match (only name+level
  wrapped in `Emphasize`, same shape as `Format_Attribute`/
  `Format_Defect`), and every hmm-mode golden check (`-s`/`-S`/`-b`/`-i`/
  `-l`/`-M`/`-R`, the Mecha entity, the multi-entity composite fixture)
  re-verified byte-for-byte against the rebuilt `besm2-rst` binary.
  Regenerating besm-tools' non-hmm golden fixtures (`build/*.gen.rst`
  via `make`) confirmed the fix is hmm-only, as expected: nothing else
  changed.
- **Shared library with a future besm4 port.** `besm4-rst.scm` is ~80%
  structurally identical to `besm2-rst.scm` (same helpers, same
  row/sep functions, same customizer logic; it only lacks the `h-m-m`
  backend and has a few extra entity fields). If a besm4 port is wanted
  later, `Text_Layout`/customizer logic should probably be factored into
  a shared library now rather than duplicated later (typed data access
  no longer needs factoring out for this purpose — it's shared for free
  via `alibfyaml` once that lands). Not needed for `besm2_fmt` alone.
- ~~**Dependency mechanism for `alibfyaml`.**~~ Resolved pragmatically,
  for now: a relative `with "../../alibfyaml/libfyaml_ada.gpr";` in
  `besm2_fmt.gpr` (unlike `arg_parser`, `alibfyaml` isn't installed
  under `/usr/local/sw/versions/ada/` or registered on
  `GPR_PROJECT_PATH`, so this assumes the sibling checkout layout used
  throughout this session — `~/Repos/Ada/alibfyaml` next to
  `~/Repos/Ada/RPG/besm2_fmt`). Revisit if `alibfyaml` ever gets a
  proper install/Alire release.
- ~~**Timing relative to the `alibfyaml` typed-accessors work.**~~
  Resolved: that work has landed (`Integer_Value`/`Long_Integer_Value`/
  `Long_Long_Integer_Value`/`Float_Value`/`Long_Float_Value`/
  `Boolean_Value`/`String_Value`, required and optional-with-default
  forms, plus `0b`-binary and `_`-separator extensions), so §4 can be
  implemented directly against current `alibfyaml`, no shim needed.
- ~~**Multi-document YAML files aren't handled.**~~ Resolved:
  `alibfyaml` landed `Libfyaml.Documents.Streams.Document_Stream`
  (`Open_String`/`Open_File` + `Has_Next`/`Next`, see its `PLAN.md`,
  "Multi-document YAML streams"), and `besm2_fmt_main.adb`'s
  `Process_One` now reads a file through that instead of
  `Doc.Parse_String`/`Parse_File`, looping `Has_Next`/`Next` over every
  `---`-separated document. `Process_Entities`' entity counter was
  pulled out into a `Count : in out Natural` threaded across the whole
  loop, so numbering stays continuous per *file* regardless of how many
  documents it's split into (matches the pre-existing "`Entity_No` is 1
  for the first entity in a file, 2 for the second" contract in
  `Format_Terse`'s spec). Note the original `besm2-rst.scm` didn't
  actually handle this correctly either — Chicken's `yaml-load`
  collapses each `document-end` event to `(car seed)`, silently
  discarding every prior document and keeping only the *last* one — so
  there was no faithful legacy behavior to preserve; this is a case
  where the Ada port does it properly rather than porting a bug.
  Verified: existing single-document goldens
  (`enyon-boase-2e.yaml`/`FV2021-Coleopteran-2e.yaml`, file arg/stdin/
  `-o`, diffed against besm-tools' real `*-terse.gen.rst` output)
  still byte-for-byte match after the switch, and
  `composite-multi-doc-2e.yaml` (two documents, one entity each) now
  produces output byte-identical to `composite-2e.yaml` (one document,
  a two-entity sequence) — both via file argument and via stdin.

## Decisions already made

- Program name: **besm2_fmt** (was `besmfmt`, was `besm2-rst`).
- Project directory: **`~/Repos/Ada/RPG/besm2_fmt`** (was
  `BESM2-formatter`), pushed to
  [`github.com/tkurtbond/besm2_fmt`](https://github.com/tkurtbond/besm2_fmt).
- Ada root package: **`BESM2_Fmt`** — BESM2 is an abbreviation (Big
  Eyes, Small Mouth, 2nd edition), so it's kept upper-case rather than
  title-cased like an ordinary word; file/executable/project/repo
  names stay lowercase `besm2_fmt` regardless (Unix/GNAT convention).
- Scope: **besm2 only** — no `-2`/`-4` mode-switching; a besm4 port, if
  wanted, would be a separate `besm4_fmt` sharing code via a library.
- CLI parsing: **[`arg_parser`](https://github.com/tkurtbond/arg_parser)**
  (see §5), not `GNAT.Command_Line`. Installed under
  `/usr/local/sw/versions/ada/`, resolved via `GPR_PROJECT_PATH`
  (already set) — `with "arg_parser.gpr";` needs no path or Alire
  dependency.
- Performance vs. `besm2-rst`: benchmarked and documented in
  `PERFORMANCE-COMPARISON.md`, reproducible via `tools/benchmark.sh`/
  `make benchmark`. `besm2_fmt` is substantially faster (~6-9x per
  invocation on a tiny real fixture; ~25-37x throughput on a
  2000-entity file), at the cost of higher peak RSS on a single very
  large document (libfyaml holds the whole parsed node tree in memory
  at once) — though notably *not* on a genuinely multi-document file,
  where `Document_Stream`'s per-document streaming keeps `besm2_fmt`'s
  RSS lower than `besm2-rst`'s. Not a decision that changes anything
  about the port (no performance requirement drove it — parity with
  `besm2-rst.scm`'s behavior did), just a recorded data point.
