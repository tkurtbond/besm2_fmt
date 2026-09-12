# Performance comparison: `besm2_fmt` vs the `besm2-rst` family

Compares `besm2_fmt` (this project, Ada/GNAT) against the whole
`besm2-rst` family (the original Chicken Scheme implementation this
project is a port of, from
[besm-tools](https://github.com/tkurtbond/besm-tools), plus the three
variants besm-tools has since added). All six binaries were verified
to produce byte-identical output on every input used below before
timing.

The `besm2-rst` family, and the short code each is given below:

- `yaml` -- `besm2-rst`, the original, loading via the `yaml` egg
  (default).
- `fyaml` -- `besm2-rst -f`/`--fyaml`: same binary, loading via
  `(slibfyaml scheme)`'s eager whole-document decode instead.
- `tree` -- `besm2-rst-f`: a separate program, walking slibfyaml's own
  handle/tree-based document API directly rather than going through
  either whole-document loader.
- `entity` -- `besm2-rst-e`: `besm2-rst` refactored to decode every
  entity once into a shared record (`besm-entities.scm`) instead of
  re-deriving the same fields separately in each output backend --
  still `yaml`-egg-loaded by default.
- `etree` -- `besm2-rst-f-e`: `besm2-rst-f` refactored the same way.

See besm-tools' own `benchmark-fyaml.rst` for a benchmark of these
five against each other in isolation (loader choice and the
shared-record refactor); this document only compares each against
`besm2_fmt`.

## Historical note: alibfyaml's Node/Document liveness enforcement

`besm2_fmt`'s own numbers in this report (per-invocation especially)
are noticeably higher than in an earlier version of this document
(`~2.2 ms` mean per-invocation then vs. `~2.9 ms` now, e.g.) --
**not** because `besm2_fmt`'s own source changed, but because
`alibfyaml` (`~/Repos/Ada/alibfyaml`, the Ada binding to `libfyaml`
this project is built on) has since added runtime Node/Document
liveness enforcement, closing a real, confirmed-elsewhere
use-after-free bug class at a measured constant-factor cost (see
`alibfyaml`'s `PLAN.md`, "Node/Document liveness enforcement"
section). This project's `besm2_fmt` binary is always built against
whatever `alibfyaml` is installed system-wide, so this report reflects
whichever `alibfyaml` was current when it was regenerated -- there is
no version pin recorded here beyond that.

`ALIBFYAML-LIVENESS-PERFORMANCE.md` (this repo) measures that specific
change in isolation, with a controlled before/after comparison (two
`besm2_fmt` builds differing *only* in which `alibfyaml` commit they
link against, output-correctness-gated before any timing): **+2.3% to
+14.8%** on throughput, depending on output mode, with per-invocation
numbers there flagged as too noise-dominated at that timescale to be
meaningful either way -- the same caveat applies to comparing this
document's own per-invocation numbers across two different points in
its own history; don't read a clean liveness-enforcement cost out of
this document's before/after delta the way `ALIBFYAML-LIVENESS-
PERFORMANCE.md`'s controlled comparison lets you. The besm2-rst-family
numbers below are entirely unaffected (none of those programs touch
`alibfyaml`) -- only `besm2_fmt`'s own column moved, and only by the
amount `ALIBFYAML-LIVENESS-PERFORMANCE.md` already accounts for.
`besm2_fmt`'s conclusions relative to the `besm2-rst` family below are
unchanged in kind, just slightly narrower margins -- see "Reading it"
for the updated ranges.

## Historical note: besm-tools' tree/etree multi-document fix

An earlier version of this document found `tree`/`etree` (`besm2-rst-f`/
`besm2-rst-f-e`) reading only 1 entity from the multi-document
throughput fixture below, same as `yaml`/`fyaml`/`entity` -- but for a
different, confirmed-by-reading-the-source reason: `besm2-rst-f.scm`/
`besm2-rst-f-e.scm` called `document-parse-port`, `slibfyaml`'s
single-document parse entry point, and simply never called
`(slibfyaml documents streams)`, `slibfyaml`'s own `Document_Stream`-
equivalent multi-document API -- a `besm2-rst-f`/`-f-e` implementation
gap, not a limitation of `slibfyaml`'s Node/handle-based approach
itself (`Document_Stream` was already fully capable). Fixed upstream
in besm-tools commit `5c25561` (`~/current/RPG/Tools/BESM`): both now
stream via `document-stream-open-*`/`-has-next?`/`-next!`, matching
`besm2_fmt`'s own `Document_Stream` loop, verified byte-identical to
the prior binaries on every existing single-document fixture first.
See the "multi-document file" section's own numbers below and its
"Reading it" bullet for what that fix changed here -- `yaml`/`fyaml`/
`entity` still only read 1 entity from this file, a separate,
still-open bug unrelated to and unaffected by this fix.

## Reproducing this

The report below (everything between the `----` markers) is the
unedited stdout of `tools/benchmark.sh` -- regenerate it with:

```
BESM2_RST=/path/to/besm2-rst \
BESM2_RST_F=/path/to/besm2-rst-f \
BESM2_RST_E=/path/to/besm2-rst-e \
BESM2_RST_FE=/path/to/besm2-rst-f-e \
tools/benchmark.sh > /tmp/report.md
```

or `make benchmark` (same script; prints to the terminal instead of a
file). Each of the four env vars above is independently optional --
set however many you have freshly built, and the report adapts,
down to zero (a `besm2_fmt`-only report, no comparison). `BESM2_RST`
also isn't required to be set explicitly -- omitted, it falls back to
`PATH` -- but if a `besm2-rst` happens to be there, the script will
use it with a loud warning rather than silently trusting it, since a
`PATH`-installed one can easily be stale (built before some fix landed
upstream in besm-tools); `BESM2_RST_F`/`_E`/`_FE` have no such
fallback -- unset simply means that variant is skipped. See
`tools/benchmark.sh`'s header comment for every environment variable
it accepts (`BENCH_N`/`BENCH_ENTITIES`/`BENCH_SOURCE` too) and its
Linux/GNU-coreutils dependencies (GNU `time`, GNU `date`).

A methodological pitfall the script's design deliberately routes
around: naively concatenating a single-entity fixture N times to build
a synthetic multi-entity file produces N separate YAML *documents*
(since the fixture starts with its own `---` marker), not one
N-entity document -- which would silently trigger the documented
`besm2-rst.scm` bug where multi-document input collapses to just the
last document. The script generates the "multi-entity" and
"multi-document" fixtures below deliberately, as two distinct, correct
shapes, specifically so that bug's effect can be measured on purpose
in the last table rather than showing up by accident in the others.

----

# besm2_fmt vs besm2-rst-family benchmark

Generated: 2026-09-12 14:51:12 UTC by `tools/benchmark.sh`.

- Machine: 13th Gen Intel(R) Core(TM) i9-13900HX, 32 threads, Linux 7.1.10-200.fc44.x86_64 x86_64
- `BENCH_N`=200, `BENCH_ENTITIES`=2000, `BENCH_SOURCE`=./test-data/enyon-boase-2e.yaml

Programs compared below:

- `yaml`: `besm2-rst` (default, yaml egg): `/home/tkb/current/RPG/Tools/BESM/build/besm2-rst`
- `fyaml`: `besm2-rst -f`/`--fyaml` (slibfyaml egg, eager decode): `/home/tkb/current/RPG/Tools/BESM/build/besm2-rst`
- `tree`: `besm2-rst-f` (slibfyaml handle/tree API): `/home/tkb/current/RPG/Tools/BESM/build/besm2-rst-f`
- `entity`: `besm2-rst-e` (yaml egg, shared entity record): `/home/tkb/current/RPG/Tools/BESM/build/besm2-rst-e`
- `etree`: `besm2-rst-f-e` (handle/tree, shared entity record): `/home/tkb/current/RPG/Tools/BESM/build/besm2-rst-f-e`
- `besm2_fmt`: this project: `./besm2_fmt`

## Per-invocation overhead (N=200 runs, `enyon-boase-2e.yaml`)

Mean time per invocation

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| yaml | 23.308 ms | 18.304 ms | 19.234 ms | 18.226 ms |
| fyaml | 22.963 ms | 19.391 ms | 18.053 ms | 18.820 ms |
| tree | 21.764 ms | 19.063 ms | 18.709 ms | 19.042 ms |
| entity | 23.098 ms | 17.438 ms | 17.287 ms | 20.090 ms |
| etree | 21.708 ms | 19.541 ms | 18.559 ms | 19.456 ms |
| besm2_fmt | 2.853 ms | 2.806 ms | 2.890 ms | 2.112 ms |

besm2_fmt's speedup over each

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| yaml | 8.2x | 6.5x | 6.7x | 8.6x |
| fyaml | 8.0x | 6.9x | 6.2x | 8.9x |
| tree | 7.6x | 6.8x | 6.5x | 9.0x |
| entity | 8.1x | 6.2x | 6.0x | 9.5x |
| etree | 7.6x | 7.0x | 6.4x | 9.2x |

## Throughput: multi-entity document (2000 entities, one YAML document)

One `---` document containing a 2000-entity sequence --
every program processes every entity; this is an apples-to-apples
comparison.

Time

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| yaml | 15.86 s | 4.77 s | 4.89 s | 5.64 s |
| fyaml | 14.30 s | 3.63 s | 3.82 s | 4.56 s |
| tree | 13.61 s | 3.17 s | 3.32 s | 4.02 s |
| entity | 15.19 s | 4.61 s | 4.79 s | 5.58 s |
| etree | 13.55 s | 3.00 s | 3.23 s | 3.94 s |
| besm2_fmt | 0.44 s | 0.21 s | 0.21 s | 0.22 s |

Entities processed (sanity check -- should read 2000 everywhere)

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| yaml | 2000 | 2000 | 2000 | 2000 |
| fyaml | 2000 | 2000 | 2000 | 2000 |
| tree | 2000 | 2000 | 2000 | 2000 |
| entity | 2000 | 2000 | 2000 | 2000 |
| etree | 2000 | 2000 | 2000 | 2000 |
| besm2_fmt | 2000 | 2000 | 2000 | 2000 |

Peak RSS

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| yaml | 58960 KB | 70968 KB | 69916 KB | 70736 KB |
| fyaml | 195580 KB | 194080 KB | 179136 KB | 194476 KB |
| tree | 157872 KB | 156708 KB | 157020 KB | 162624 KB |
| entity | 75676 KB | 70384 KB | 56564 KB | 71120 KB |
| etree | 170776 KB | 176924 KB | 168424 KB | 169852 KB |
| besm2_fmt | 135684 KB | 135984 KB | 135720 KB | 136012 KB |

besm2_fmt's speedup over each

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| yaml | 36.0x | 22.7x | 23.3x | 25.6x |
| fyaml | 32.5x | 17.3x | 18.2x | 20.7x |
| tree | 30.9x | 15.1x | 15.8x | 18.3x |
| entity | 34.5x | 22.0x | 22.8x | 25.4x |
| etree | 30.8x | 14.3x | 15.4x | 17.9x |

## Throughput: multi-document file (2000 separate documents, one entity each)

2000 `---`-delimited YAML documents in one file, each a
one-entity sequence.

`tree`, `etree` and `besm2_fmt` read all 2000 entities
correctly here; `yaml`, `fyaml` and `entity` did not (see the
entity counts below, not just the timings) -- known bugs in
specific programs, not something this script can explain in
general; check each one's own history/issue tracker. This
section measures each program's actual behavior on this file
shape, not an apples-to-apples per-entity comparison where any
program reads the wrong number of entities.

Time

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| yaml | 1.81 s | 1.83 s | 1.83 s | 1.83 s |
| fyaml | 0.80 s | 0.81 s | 0.81 s | 0.80 s |
| tree | 13.70 s | 3.10 s | 3.25 s | 3.98 s |
| entity | 1.82 s | 1.81 s | 1.82 s | 1.83 s |
| etree | 13.48 s | 3.03 s | 3.15 s | 3.91 s |
| besm2_fmt | 0.42 s | 0.19 s | 0.19 s | 0.20 s |

Entities processed

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| yaml | 1 | 1 | 1 | 1 |
| fyaml | 1 | 1 | 1 | 1 |
| tree | 2000 | 2000 | 2000 | 2000 |
| entity | 1 | 1 | 1 | 1 |
| etree | 2000 | 2000 | 2000 | 2000 |
| besm2_fmt | 2000 | 2000 | 2000 | 2000 |

Peak RSS

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| yaml | 34488 KB | 34928 KB | 34424 KB | 33964 KB |
| fyaml | 47320 KB | 46168 KB | 46664 KB | 49100 KB |
| tree | 27960 KB | 27704 KB | 28144 KB | 27040 KB |
| entity | 38848 KB | 38312 KB | 38660 KB | 34252 KB |
| etree | 32544 KB | 28668 KB | 27676 KB | 27720 KB |
| besm2_fmt | 5688 KB | 5692 KB | 5904 KB | 5916 KB |
----

## Reading it

The tables above are generated (by `tools/benchmark.sh`) each time the
benchmark is rerun, so the specific figures will drift between runs
and machines; read them for shape, not for the exact numbers quoted
here at the time this section was last written by hand. This
particular run postdates both `alibfyaml`'s Node/Document liveness
enforcement change and besm-tools' `tree`/`etree` multi-document fix
(see both "Historical note" sections above) -- `besm2_fmt`'s margins
over the `besm2-rst` family on the first two tables are about the same
as before (within normal run-to-run noise), but the third table's
story has fundamentally changed; see that bullet below:

- **Time: `besm2_fmt` wins everywhere, against every variant, and the
  gap widens with scale.** ~6.0-9.5x faster per invocation on a tiny
  real fixture, ~14.3-36.0x faster processing a 2000-entity document.
  The five besm2-rst-family variants are all clustered fairly close
  together against `besm2_fmt` -- none of besm-tools' own internal
  refactors (loader choice, or the shared-record refactor `entity`/
  `etree` add) closes any real fraction of the gap to `besm2_fmt`,
  which is unsurprising: those refactors were about code
  organization/duplication and, per besm-tools' own benchmark, were
  designed to (and did) cost nothing extra at that scale. The
  throughput gap growing faster than the fixed-overhead gap still
  points to an algorithmic difference, not just constant-factor
  process-startup cost -- most likely Chicken's `yaml`/`slibfyaml`
  parsers and `(schemepunk show)`/SRFI 166's combinator-based
  formatting (lots of closures and per-character dispatch) versus
  `besm2_fmt`'s C-backed `libfyaml` parser (via `alibfyaml`) and Ada's
  `Text_IO`/`String` handling.

- **Memory on the multi-entity (one big document) file splits along
  parser-backend lines, not language lines.** The two `yaml`-egg-based
  programs (`yaml`, `entity`) use the *least* RSS here (~55-76 MB);
  every libfyaml-backed program -- `besm2_fmt` itself (~135 MB)
  included, and besm-tools' own `fyaml`/`tree`/`etree` (~157-196 MB) --
  uses substantially more. That lines up with what both projects'
  documentation already says: a pure-Scheme parser builds exactly one
  representation (Scheme alists) of a document, while anything
  built on libfyaml (`besm2_fmt`, and besm-tools' `slibfyaml`-based
  variants alike) must first hold libfyaml's own C node tree for the
  whole document in memory, on top of whatever gets decoded out of it
  -- so the "double structure" cost `besm2_fmt` already paid relative
  to the `yaml` egg (see the original single-`besm2-rst` comparison
  this document extends) turns out to be a libfyaml-the-C-library
  cost, not an Ada-vs-Scheme one: besm-tools' own `fyaml`/`tree`/
  `etree` pay it too, in the same language as `yaml`/`entity`.
  `fyaml`'s RSS (~179-196 MB) sitting toward the high end of
  `tree`/`etree`'s (~157-177 MB) is consistent with `(slibfyaml
  scheme)`'s eager
  whole-document decode building a *complete* second (Scheme alist)
  copy on top of libfyaml's tree, where `tree`/`etree`'s handle-based
  traversal decodes only the scalars each output backend actually
  reads. `tree`'s own RSS here (~157-163 MB) is somewhat lower than an
  earlier version of this document recorded (~167-177 MB) -- confirmed
  by reading `slibfyaml`'s source (not just inferred): the multi-
  document fix above (see "Historical note") also changed *this*
  single-document file's read path for `tree`/`etree`, from
  `document-parse-port` (reads the whole port into a CHICKEN string via
  `read-string`, *then* copies that string again into a malloc'd
  buffer for `fy_document_build_from_string` -- two full copies of the
  file's content briefly coexisting) to `document-stream-open-file`
  (`fy_parser_set_input_file`'s lazy `fread()` straight into libfyaml's
  own buffer, no CHICKEN-side string ever materialized). One fewer full
  copy of the file in memory at once is a plausible, if not separately
  torn-down-and-measured, explanation for the drop. `besm2_fmt`'s own
  RSS here (~135-136 MB) is essentially unchanged
  from before the liveness-enforcement change (see "Historical note"
  above) -- `Owner_Liveness`'s extra allocation (one small heap cell
  per `Document`) is far too small to show up against `libfyaml`'s own
  C-side tree memory at this scale, exactly as `ALIBFYAML-LIVENESS-
  PERFORMANCE.md` found in isolation.

- **The `tree`/`etree` fail-fast bug is fixed -- and `besm2_fmt` now
  beats every besm2-rst-family variant outright, not just four of
  five.** See "Historical note: besm-tools' tree/etree multi-document
  fix" above for what changed and why. `tree`/`etree` now correctly
  read all 2000 entities from this file (were stuck at 1, same as
  `yaml`/`fyaml`/`entity`, in an earlier version of this document), and
  their timing here (~13.5-13.7 s grid, ~3.0-3.25 s terse/hmm, ~3.9-
  4.0 s raw-ms) lands almost exactly on their own multi-entity
  throughput numbers above -- expected, since it's the same total
  amount of entity-decoding/formatting work, just split across 2000
  small documents instead of one big one. `besm2_fmt` beats them here
  by roughly the same margin as that comparison too (~32x grid, ~16-
  17x terse/hmm, ~20x raw-ms).

  `yaml`/`fyaml`/`entity` still only read 1 entity from this file -- a
  separate, still-open bug (the `yaml-load`/`(slibfyaml scheme)`
  collapse-to-last-document behavior in `besm2-rst.scm`), unrelated to
  and unaffected by the `tree`/`etree` fix. The result is a cleaner
  story than before: `besm2_fmt`, doing all 2000 entities *correctly*,
  is now faster in absolute wall-clock time than *every* besm2-rst-
  family variant on this file, including the three still getting the
  wrong (1-entity) answer -- 0.42/0.19/0.19/0.20 s vs. `yaml`/`entity`'s
  ~1.81-1.83 s and `fyaml`'s ~0.80-0.81 s. This is no longer a case of
  `besm2_fmt` merely beating programs doing 1/2000th the work because
  they fail fast -- it's outright faster while also being the only one
  (besides `tree`/`etree`, doing 2000x more work than the other three)
  giving the right answer.

- **Real-world files are tiny.** The actual `test-data/*.yaml` fixtures
  are 1-3 KB, one entity each -- at that scale this is entirely
  dominated by the per-invocation numbers (a couple ms vs. ~17-23 ms
  across the whole besm2-rst family), and multi-thousand-entity files
  aren't a realistic BESM character-sheet workload. The
  throughput/memory tables exist purely to separate "process startup
  and small-input cost" from "cost that actually scales with input
  size," and to give `Document_Stream`'s streaming behavior -- and the
  besm2-rst family's own remaining `yaml`/`fyaml`/`entity` multi-
  document bug -- a file shape where they can show up in the numbers
  at all.
