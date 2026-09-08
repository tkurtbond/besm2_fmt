# Source size comparison: `besm2_fmt/src` vs `besm2-rst.scm`

Compares the source code of `besm2_fmt` (this project, Ada/GNAT) against
`besm2-rst.scm` (the original Chicken Scheme implementation this project
is a port of, from
[besm-tools](https://github.com/tkurtbond/besm-tools)), using
[`sloccount`](https://dwheeler.com/sloccount/) plus manual comment/blank
line counts. This is a structural comparison of the two codebases, not
a runtime one — see `PERFORMANCE-COMPARISON.md` for the performance
comparison.

## Reproducing this

```
sloccount src
sloccount /path/to/besm2-rst.scm
```

Comment/blank counts below were taken with:

```
grep -cE '^\s*--' <file>   # Ada comment-only lines
grep -cE '^\s*;'  <file>   # Scheme comment-only lines
grep -cE '^\s*$'  <file>   # blank lines (either language)
```

Scheme source used: `/home/tkb/current/RPG/Tools/BESM/besm2-rst.scm`
(1,256 lines as of this writing).

## Headline numbers

| | SLOC (sloccount) | Physical lines (`wc -l`) | Files |
|---|---|---|---|
| `besm2-rst.scm` (Chicken Scheme) | 992 | 1,256 | 1 |
| `besm2_fmt/src` (Ada) | 1,667 | 2,458 | 17 (`.ads`/`.adb` pairs) |

The Ada port is ~1.7x the Scheme original in SLOC (~2x in raw line
count), despite being a faithful behavioral port with no new
user-facing features.

## Spec vs. body split (Ada has no Scheme equivalent of this)

| | SLOC | % of total |
|---|---|---|
| `.ads` (specs) | 278 | 16.7% |
| `.adb` (bodies) | 1,389 | 83.3% |

Scheme has no separate interface files, so this split alone accounts
for a real chunk of Ada's line-count premium — declarations that exist
purely so other units can `with` a package are pure overhead relative
to the single-file Scheme original.

## Comment and blank-line density

| | Total lines | Comment-only | Blank | Code (rest) |
|---|---|---|---|---|
| `besm2-rst.scm` | 1,256 | 135 (10.7%) | 129 (10.3%) | 992 (79.0%) |
| `besm2_fmt/src` | 2,458 | 509 (20.7%) | 282 (11.5%) | 1,667 (67.8%) |

The Ada codebase is documented almost twice as densely as the Scheme
original (comment-only lines: 20.7% vs 10.7%). That's a meaningful
share of the size gap — it isn't all "more logic," a lot of it is doc
comments Scheme never had.

## Per-file SLOC (sloccount)

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

## Reading it

- **`besm2_fmt-text_layout.ads`: 148 lines, 107 comments (72%).** By
  far the most heavily annotated file in the port — the public spec
  for line-wrapping/text-layout utilities, with nearly every
  declaration carrying an explanatory comment. This single file
  accounts for ~21% of all comment lines in the Ada codebase. Like
  `Entities`, `Text_Layout` (146 SLOC across both files) has no
  line-for-line Scheme counterpart to compare against: in
  `besm2-rst.scm` this job is done by pulling in `(schemepunk show)`
  (SRFI 166) and its `columnar`/`wrapped`/`padded`/`displayed`/`each`
  combinators — a general-purpose external library, not code the
  Scheme source itself pays SLOC for. Ada has no equivalent library, so
  the port had to write one, purpose-built to the narrower subset
  `besm2-rst.scm` actually uses (per `PLAN.md` §1: plain-ASCII,
  fixed-width, single-font text — fixed-width padding, greedy
  word-wrap, and the `row2`/`row3`/`separator-line` bordered-row
  renderer, nothing more). So part of Ada's SLOC premium isn't "the
  same logic written more verbosely" — it's a dependency the Scheme
  version got for free (library code, uncounted here) that the Ada
  version had to internalize and therefore does get counted.

- **`besm2_fmt-cli.ads`: 144 SLOC, only 21 comment / 12 blank lines.**
  This is the option/flag table also mentioned in `PLAN.md` — Scheme's
  `+command-line-options+` alist (compact, ~20 entries, one table)
  becomes an Ada declarative spec with named record types/discriminants
  per flag. Dense with actual declarations, not comments — a case
  where the port genuinely needed more code to express the same table
  in a statically-typed form.

- **`besm2_fmt-entities.{ads,adb}`: 68 + 303 = 371 SLOC, no Scheme
  counterpart.** A deliberate addition, not a translation cost. Scheme
  re-walks the raw YAML alist and validates keys on every access
  (`must-exist ...`) scattered across call sites; Ada centralizes that
  into one accessor module. It's the single largest concentration of
  new code in the port — roughly 22% of all Ada SLOC — but it's paying
  once for validation/lookup logic Scheme pays for repeatedly and
  implicitly.

- **The four format modules are the closest thing to a direct
  translation.** `format_grid`, `format_hmm`, `format_raw_ms`, and
  `format_terse` bodies total 187+198+189+208 = 782 SLOC — comparable
  in shape to the corresponding `process-entity-*`/rendering functions
  in the Scheme file, and (`format_raw_ms.adb` aside, at ~18% comments)
  their comment ratios are closer to the Scheme baseline than the rest
  of the codebase.

- **Net picture:** of the Ada codebase's ~1.7x SLOC premium over
  Scheme, roughly four sources account for most of it: (1) the
  spec/body split, which is structural and Ada-language-inherent
  (278 SLOC of pure interface declarations); (2) comment density
  roughly double the Scheme original's; (3) the `Entities` module, a
  genuine architectural addition with no Scheme counterpart; and (4)
  `Text_Layout`, which internalizes as counted Ada SLOC what
  `besm2-rst.scm` gets for free as an external library dependency
  (`(schemepunk show)`/SRFI 166). The actual translated rendering logic
  (the four format modules) is roughly line-for-line comparable to its
  Scheme source.
