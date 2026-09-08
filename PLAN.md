# besm2_fmt: porting `besm2-rst.scm` to Ada

**Source being ported:** `~/current/RPG/Tools/BESM/besm2-rst.scm` (Chicken Scheme,
1219 lines), part of the BESM Tools suite (`README.rst` in that directory).
It converts a YAML BESM 2E character/template/item file into
reStructuredText, in one of four output formats selected by CLI flag.

**Target:** an Ada program, `besm2_fmt`, built on
[`alibfyaml`](https://github.com/) (`~/Repos/Ada/alibfyaml`), the Ada
binding to libfyaml's core parser/document/emitter API.

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
    besm2_fmt-config.ads             -- CLI-settable globals (was the *star* specials)
    besm2_fmt-text_layout.ads/.adb   -- pad/wrap/columnar-row rendering; bold/italics/emphasis
    besm2_fmt-entities.ads/.adb      -- domain types: Stat, Derived, Attribute, Defect, Skill,
                                         Entity, built by walking Nodes once per entity
    besm2_fmt-customizers.adb        -- the format-customizers port (enhancement/limiter shapes)
    besm2_fmt-format_grid.adb        -- process-entity (reST grid table)
    besm2_fmt-format_terse.adb       -- process-entity-terse
    besm2_fmt-format_hmm.adb         -- process-entity-hmm
    besm2_fmt-format_raw_ms.adb      -- process-entity-raw-ms
    besm2_fmt-cli.adb                -- argument parsing (the args:make-option table)
    besm2_fmt.adb                    -- main: parse args, open input(s), dispatch, write output
  besm2_fmt.gpr
```

Root package `Besm2_Fmt.*`, executable and project file
`besm2_fmt`/`besm2_fmt.gpr`.

`Besm2_Fmt.Entities` is a deliberate addition with no Scheme counterpart:
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

This was originally planned as a `Besm2_Fmt.Yaml_Access` package
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

The `args` egg's option table (`+command-line-options+`, ~20 flags:
`-1/--one`, `-B`, `-b`, `-D`, `-d`, `-H`, `-L`, `-R`, `-S`, `-h`, `-i`,
`-l`, `-M`, `-m`, `-o`, `-p`, `-s`, `-t`, `-U`, `-u`, `-w`) maps onto
`GNAT.Command_Line`'s `Getopt`, or a small hand-rolled parser if
`Getopt`'s long-option support is inconvenient — needs checking once
actually implementing this. Each flag sets one field of a `Config`
record instead of a top-level `set!` special, which also removes the
`parameterize`/dynamic-scoping pattern (`mecha?`, `*hmm-depth*`) in
favor of passing `Config` (and, for `mecha?`/`hmm-depth`, explicit
parameters or a small mutable "render state" record threaded through the
four format backends).

## 6. A behavior worth flagging before porting it faithfully

`(mecha? (assoc "mecha" entity))` — `assoc` returns a pair (truthy)
whenever the key **exists**, regardless of its YAML value. So `mecha:
false` would still turn mecha-mode on, same as `mecha: true`. This is
almost certainly an unintentional latent quirk in the Scheme rather than
a deliberate design choice (nothing in the design-decision comments at
the top of the file mentions it). Default plan: port it as "key
presence" faithfully, but this is an open question — see below.

## 7. Testing strategy

`test-data/*.yaml` (11 files, in
`~/current/RPG/Tools/BESM/test-data/`) plus the `GNUmakefile`'s existing
invocation patterns (`-s`, `-t`, `-m` combinations feeding `pandoc`) give
ready-made golden inputs. Plan: run the existing Chicken binary on each
test file in each mode, save output, then diff the Ada port's output
byte-for-byte against it as the acceptance test — much stronger than
eyeballing, and catches whitespace/wrapping regressions the eye would
miss.

## 8. Suggested build order

1. `Text_Layout` in isolation (unit-testable without any YAML at all).
2. `Entities` against `alibfyaml` (using its typed accessors directly —
   see §4), validated by loading a test file and dumping field values.
3. **Terse backend first** — it does zero column layout, so it validates
   CLI + data access + domain formatting before touching the harder
   `Text_Layout` row renderer.
4. Grid-table backend (exercises `Text_Layout` fully) — diff against
   golden output.
5. `h-m-m` and raw-`ms`/`tbl` backends (structurally close to
   terse/grid respectively, so cheap once the first two are solid).

## Open questions

- **`mecha?` semantics** (§6): port the existence-check quirk faithfully,
  or fix it to check the actual boolean value?
- **Shared library with a future besm4 port.** `besm4-rst.scm` is ~80%
  structurally identical to `besm2-rst.scm` (same helpers, same
  row/sep functions, same customizer logic; it only lacks the `h-m-m`
  backend and has a few extra entity fields). If a besm4 port is wanted
  later, `Text_Layout`/customizer logic should probably be factored into
  a shared library now rather than duplicated later (typed data access
  no longer needs factoring out for this purpose — it's shared for free
  via `alibfyaml` once that lands). Not needed for `besm2_fmt` alone.
- **Dependency mechanism for `alibfyaml`.** Plain relative/absolute `with
  "..."` in the `.gpr`, or an Alire path/git dependency — not yet
  decided.
- **Timing relative to the `alibfyaml` typed-accessors work.** §4 above
  is now a real dependency on that plan landing first (at least its
  Integer/Float/Boolean/String pieces); decide whether to wait for it,
  or start `besm2_fmt` with a throwaway local shim and switch over once
  `alibfyaml` has it.

## Decisions already made

- Program name: **besm2_fmt** (was `besmfmt`, was `besm2-rst`).
- Project directory: **`~/Repos/Ada/RPG/besm2_fmt`** (was
  `BESM2-formatter`).
- Ada root package: **`Besm2_Fmt`**.
- Scope: **besm2 only** — no `-2`/`-4` mode-switching; a besm4 port, if
  wanted, would be a separate `besm4_fmt` sharing code via a library.
