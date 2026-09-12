# Source size comparison: `besm2_fmt/src` vs the `besm2-rst` family

Compares the source code of `besm2_fmt` (this project, Ada/GNAT)
against the whole `besm2-rst` family it is a port of -- from
[besm-tools](https://github.com/tkurtbond/besm-tools) -- using
[`sloccount`](https://dwheeler.com/sloccount/) plus manual
comment/blank line counts. This is a structural comparison of the two
codebases, not a runtime one -- see `PERFORMANCE-COMPARISON.md` for
the performance comparison.

The "family" is five Chicken Scheme files, not one:

- `besm2-rst.scm` -- the original this project was first ported from:
  loads YAML via the `yaml` egg (default) or `(slibfyaml scheme)`
  (`-f`/`--fyaml`), building each output backend's entity data inline,
  once per backend.
- `besm2-rst-f.scm` -- the same program, refactored to walk
  slibfyaml's own handle/tree API directly instead of going through
  either whole-document loader.
- `besm-entities.scm` -- added later: a shared record type
  (`<entity>` and friends) that both `besm2-rst.scm` and
  `besm2-rst-f.scm` are refactored to decode into exactly once,
  replacing the duplicated inline entity-building code in each of the
  four output backends. This is the closest Scheme counterpart
  `besm2_fmt-entities.{ads,adb}` has ever had -- see below.
- `besm2-rst-e.scm` -- `besm2-rst.scm`, thinned down to CLI/loader
  glue now that entity decoding lives in `besm-entities.scm`.
- `besm2-rst-f-e.scm` -- `besm2-rst-f.scm`, thinned down the same way.

`besm2-rst-e.scm` and `besm2-rst-f-e.scm` each require
`besm-entities.scm` to run; `besm2-rst.scm` and `besm2-rst-f.scm` are
each fully self-contained. All five files coexist in the besm-tools
repository as deliberate comparison points (correctness-verified
byte-identical to each other, and benchmarked against each other -- see
`PERFORMANCE-COMPARISON.md` and besm-tools' own `benchmark-fyaml.rst`),
not as a "delete the old ones" refactor.

## Reproducing this

```
sloccount src
sloccount /path/to/besm2-rst.scm
sloccount /path/to/besm2-rst-f.scm
sloccount /path/to/besm2-rst-e.scm
sloccount /path/to/besm2-rst-f-e.scm
sloccount /path/to/besm-entities.scm
```

Comment/blank counts below were taken with:

```
grep -cE '^\s*--' <file>   # Ada comment-only lines
grep -cE '^\s*;'  <file>   # Scheme comment-only lines
grep -cE '^\s*$'  <file>   # blank lines (either language)
```

Scheme sources used (all from `/home/tkb/current/RPG/Tools/BESM`, as
of this writing):

| File | Physical lines (`wc -l`) |
|---|---|
| `besm2-rst.scm` | 1,268 |
| `besm2-rst-f.scm` | 1,328 |
| `besm2-rst-e.scm` | 351 |
| `besm2-rst-f-e.scm` | 376 |
| `besm-entities.scm` | 1,131 |

## Headline numbers

| | SLOC (sloccount) | Physical lines (`wc -l`) | Files |
|---|---|---|---|
| `besm2-rst.scm` alone | 995 | 1,268 | 1 |
| `besm2-rst-f.scm` alone | 1,020 | 1,328 | 1 |
| `besm2-rst-e.scm`\* | 1,004 | 1,482 | 2 |
| `besm2-rst-f-e.scm`\* | 1,022 | 1,507 | 2 |
| `besm2_fmt/src` (Ada) | 1,667 | 2,460 | 17 (`.ads`/`.adb` pairs) |

Each row above is a complete, independently runnable program's total
SLOC. `\*` marks the two rows that also require `besm-entities.scm`
to run -- its 777 SLOC is included (counted once, not twice) in both,
since each genuinely needs the whole file, not because it's being
double-counted by mistake.
(Summed once across the distinct-file corpus -- `sloccount` on all
five files together agrees -- the whole besm-tools side is 3,264 SLOC;
that number mixes an original and its refactor and isn't the right
one to compare against Ada's single 1,667, which is why it isn't a row
above.)

The Ada port remains ~1.6-1.7x any single besm2-rst-family program in
SLOC (~1.6-2x in raw line count), despite being a faithful behavioral
port with no new user-facing features. That premium is essentially
unchanged from the original `besm2-rst.scm`-only comparison: **the
shared-record refactor left besm-tools' own SLOC total flat.**
`besm2-rst.scm` (995) vs. `besm2-rst-e.scm` + `besm-entities.scm`
(1,004): +9 SLOC (+0.9%). `besm2-rst-f.scm` (1,020) vs.
`besm2-rst-f-e.scm` + `besm-entities.scm` (1,022): +2 SLOC (+0.2%).
Consolidating the duplicated per-backend entity-building code into one
shared module didn't shrink the codebase -- it relocated the same
amount of code into record-type declarations, accessors, and
config-parameter objects instead. (Six `define-record-type` forms
account for only 53 of `besm-entities.scm`'s 777 SLOC, so it isn't
mainly record boilerplate either; it's the four formatters and their
supporting helpers, which used to be spread across `besm2-rst.scm`
inline and are now concentrated in one file.) The refactor's payoff,
per besm-tools' own benchmark-fyaml.rst, is a single place to get
formatting logic right once instead of four, and it costs nothing at
runtime -- not a smaller codebase.

## Spec vs body split (Ada has no Scheme equivalent of this)

| | SLOC | % of total |
|---|---|---|
| `.ads` (specs) | 278 | 16.7% |
| `.adb` (bodies) | 1,389 | 83.3% |

Scheme has no separate interface files, so this split alone accounts
for a real chunk of Ada's line-count premium -- declarations that exist
purely so other units can `with` a package are pure overhead relative
to any single-file Scheme original.

## Comment and blank-line density

File names below are abbreviated (`.scm` dropped, `besm2-` shortened
to `rst-` where it was a prefix). Code line counts aren't shown
separately -- they're each row's remainder after comment-only and
blank (e.g. `rst`: 1,268 - 142 - 131 = 995, matching its SLOC above):

| File | Total lines | Comment-only | Blank |
|---|---|---|---|
| `rst` | 1,268 | 142 (11.2%) | 131 (10.3%) |
| `rst-f` | 1,328 | 170 (12.8%) | 138 (10.4%) |
| `rst-e` | 351 | 96 (27.4%) | 28 (8.0%) |
| `rst-f-e` | 376 | 97 (25.8%) | 34 (9.0%) |
| `entities` | 1,131 | 223 (19.7%) | 131 (11.6%) |
| `besm2_fmt/src` | 2,460 | ~509 (~20.7%) | ~282 (~11.5%) |

`besm2-rst-e.scm`/`besm2-rst-f-e.scm` are the most densely commented
Scheme files here by a wide margin (>25%, close to Ada's own ~20.7%)
-- unsurprising, since almost everything left in them after the
extraction *is* the part worth explaining (which loader is in use,
what changed vs. the pre-refactor program, CLI option handling), with
little routine code left to pad the denominator. `besm-entities.scm`
sits closer to the middle: 19.7% is a real step up from the two
monolithic originals' ~11-13%, reflecting the same kind of
"consolidated code deserves an explanatory comment where scattered
code didn't" effect Ada's own port already showed for its `Entities`
and `Text_Layout` modules (see below and the original analysis this
section is built on).

## Per-file SLOC (sloccount)

Ada (`besm2_fmt/src`):

| File | SLOC |
|---|---|
| `besm2_fmt.ads` | 2 |
| `besm2_fmt-format_terse.ads` | 4 |
| `besm2_fmt-format_grid.ads` | 4 |
| `besm2_fmt-format_hmm.ads` | 4 |
| `besm2_fmt-format_raw_ms.ads` | 4 |
| `besm2_fmt-config.ads` | 25 |
| `besm2_fmt-text_layout.ads` | 23 |
| `besm2_fmt-entities.ads` | 68 |
| `besm2_fmt-cli.ads` | 144 |
| `besm2_fmt-cli.adb` | 61 |
| `besm2_fmt_main.adb` | 120 |
| `besm2_fmt-text_layout.adb` | 123 |
| `besm2_fmt-format_terse.adb` | 187 |
| `besm2_fmt-format_grid.adb` | 189 |
| `besm2_fmt-format_hmm.adb` | 198 |
| `besm2_fmt-format_raw_ms.adb` | 208 |
| `besm2_fmt-entities.adb` | 303 |
| **Total** | **1,667** |

Scheme (besm-tools):

| File | SLOC |
|---|---|
| `besm2-rst-e.scm` | 227 |
| `besm2-rst-f-e.scm` | 245 |
| `besm-entities.scm` | 777 |
| `besm2-rst.scm` (monolithic, for reference) | 995 |
| `besm2-rst-f.scm` (monolithic, for reference) | 1,020 |

## The shared-record refactor: `besm-entities.scm` vs `besm2_fmt-entities`

This is now a genuinely fair, apples-to-apples comparison that didn't
exist when this document was first written -- both languages have,
independently, built exactly one module whose job is "decode a YAML
entity once, into a typed/record structure, so every output backend
reads from it instead of re-deriving fields itself":

| | Decode/accessor module only | + the formatters it feeds |
|---|---|---|
| Scheme | 777 SLOC | 777 SLOC (formatters live in the same file) |
| Ada | 371 SLOC | 371 + 782 = 1,153 SLOC |

Two things stand out:

- **Scoped to decode-only, Ada's module is smaller** (371 vs. 777) --
  consistent with the rest of this document: Scheme's version carries
  its own record-type declarations (which Ada also pays for, in
  `.ads` form, inside that 371) but, unlike Ada, gets no benefit from
  static typing catching field-shape mistakes at compile time, and (as
  the previous section shows) the extraction didn't actually save
  lines within the Scheme codebase the way the original hoped.
- **Scoped to "decode once, format four ways" as a whole -- the actual
  job both modules do -- Scheme is smaller** (777 vs. 1,153). Ada
  deliberately keeps formatting in four separate `format_*` packages,
  each with its own spec; Scheme's refactor folded the formatters into
  the same file as the record types. That's an architectural choice,
  not a language limitation -- Ada could have folded its formatters
  into `Entities` too, and Scheme could split `besm-entities.scm` into
  five files the way `besm2-rst.scm`'s CLI/loader is already split
  from it -- but as actually built, it's the one place in this whole
  comparison where the Scheme side is the more compact design for the
  same combined responsibility.

## Reading it

- **`besm2_fmt-text_layout.ads`: 148 lines, 107 comments (72%).** By
  far the most heavily annotated file in the port -- the public spec
  for line-wrapping/text-layout utilities, with nearly every
  declaration carrying an explanatory comment. This single file
  accounts for ~21% of all comment lines in the Ada codebase. Like
  `Entities`, `Text_Layout` (146 SLOC across both files) has no
  line-for-line Scheme counterpart to compare against: in
  `besm2-rst.scm`/`besm2-rst-f.scm` this job is done by pulling in
  `(schemepunk show)` (SRFI 166) and its
  `columnar`/`wrapped`/`padded`/`displayed`/`each` combinators -- a
  general-purpose external library, not code the Scheme source itself
  pays SLOC for, and unaffected by the shared-record refactor (all
  four besm2-rst-family programs still use it). Ada has no equivalent
  library, so the port had to write one, purpose-built to the narrower
  subset the Scheme originals actually use (per `PLAN.md` §1:
  plain-ASCII, fixed-width, single-font text -- fixed-width padding,
  greedy word-wrap, and the `row2`/`row3`/`separator-line`
  bordered-row renderer, nothing more). So part of Ada's SLOC premium
  isn't "the same logic written more verbosely" -- it's a dependency
  the Scheme version got for free (library code, uncounted here) that
  the Ada version had to internalize and therefore does get counted.

- **`besm2_fmt-cli.ads`: 144 SLOC, only 21 comment / 12 blank lines.**
  This is the option/flag table also mentioned in `PLAN.md` -- every
  besm2-rst-family program's `+command-line-options+` alist (compact,
  ~20 entries, one table, unchanged by the shared-record refactor)
  becomes an Ada declarative spec with named record types/discriminants
  per flag. Dense with actual declarations, not comments -- a case
  where the port genuinely needed more code to express the same table
  in a statically-typed form.

- **`besm2_fmt-entities.{ads,adb}`: 68 + 303 = 371 SLOC -- no longer
  without a Scheme counterpart.** When this document was first
  written, this module was "a deliberate addition, not a translation
  cost," since Scheme re-walked the raw YAML alist and validated keys
  on every access (`must-exist ...`) scattered across call sites, with
  nothing centralizing that the way Ada's accessor module did. That's
  no longer true: `besm-entities.scm` is now exactly that
  centralization, built independently on the Scheme side for the same
  reason (see the dedicated section above for the direct comparison).
  What *is* still true, and now empirically confirmed rather than just
  argued: besm-tools' own benchmark found the Scheme refactor's own
  version of this centralization added no measurable per-entity
  runtime cost either (see `PERFORMANCE-COMPARISON.md`) -- both
  languages independently discovered that "decode once, pay the
  lookup/validation cost up front" is free at runtime and roughly a
  wash in code size within each language, whatever it costs relative
  to *the other* language.

- **The four format modules are the closest thing to a direct
  translation.** `format_grid`, `format_hmm`, `format_raw_ms`, and
  `format_terse` bodies total 187+198+189+208 = 782 SLOC -- comparable
  in shape to the corresponding `process-entity-*` formatters, which
  now live inside `besm-entities.scm` rather than scattered per-backend
  in `besm2-rst.scm`/`besm2-rst-f.scm` -- and (`format_raw_ms.adb`
  aside, at ~18% comments) their comment ratios are closer to the
  Scheme baseline than the rest of the codebase.

- **Net picture:** of the Ada codebase's ~1.6-1.7x SLOC premium over
  any single besm2-rst-family program, roughly four sources account
  for most of it: (1) the spec/body split, which is structural and
  Ada-language-inherent (278 SLOC of pure interface declarations); (2)
  comment density that was roughly double the original `besm2-rst.scm`
  (though `besm2-rst-e.scm`/`besm2-rst-f-e.scm` have since closed most
  of that gap on the Scheme side); (3) `Entities`, which -- now that
  `besm-entities.scm` exists -- turns out to be a case where *both*
  ports independently converged on the same architecture, with Ada's
  version smaller when scoped narrowly to decoding but Scheme's
  smaller once formatting is folded in too (see above); and (4)
  `Text_Layout`, which internalizes as counted Ada SLOC what every
  besm2-rst-family program gets for free as an external library
  dependency (`(schemepunk show)`/SRFI 166). The actual translated
  rendering logic (the four format modules) remains roughly
  line-for-line comparable to its Scheme source, wherever in the
  Scheme family that source currently lives.
