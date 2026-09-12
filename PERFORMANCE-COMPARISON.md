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

Generated: 2026-09-12 13:56:38 UTC by `tools/benchmark.sh`.

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
| yaml | 22.449 ms | 20.657 ms | 18.113 ms | 19.679 ms |
| fyaml | 23.946 ms | 18.804 ms | 18.775 ms | 18.780 ms |
| tree | 21.465 ms | 17.129 ms | 16.421 ms | 17.737 ms |
| entity | 24.656 ms | 18.292 ms | 17.090 ms | 20.146 ms |
| etree | 22.680 ms | 19.508 ms | 18.214 ms | 19.594 ms |
| besm2_fmt | 3.531 ms | 2.950 ms | 2.320 ms | 2.941 ms |

besm2_fmt's speedup over each

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| yaml | 6.4x | 7.0x | 7.8x | 6.7x |
| fyaml | 6.8x | 6.4x | 8.1x | 6.4x |
| tree | 6.1x | 5.8x | 7.1x | 6.0x |
| entity | 7.0x | 6.2x | 7.4x | 6.9x |
| etree | 6.4x | 6.6x | 7.9x | 6.7x |

## Throughput: multi-entity document (2000 entities, one YAML document)

One `---` document containing a 2000-entity sequence --
every program processes every entity; this is an apples-to-apples
comparison.

Time

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| yaml | 15.80 s | 4.81 s | 4.94 s | 5.71 s |
| fyaml | 14.41 s | 3.73 s | 3.82 s | 4.53 s |
| tree | 13.73 s | 3.22 s | 3.33 s | 4.03 s |
| entity | 15.17 s | 4.64 s | 4.74 s | 5.53 s |
| etree | 13.62 s | 3.08 s | 3.24 s | 3.93 s |
| besm2_fmt | 0.44 s | 0.23 s | 0.22 s | 0.23 s |

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
| yaml | 75060 KB | 69996 KB | 69360 KB | 55076 KB |
| fyaml | 195232 KB | 194376 KB | 192960 KB | 194148 KB |
| tree | 177024 KB | 168332 KB | 167020 KB | 167160 KB |
| entity | 75524 KB | 70628 KB | 71064 KB | 70772 KB |
| etree | 172196 KB | 168336 KB | 168784 KB | 180100 KB |
| besm2_fmt | 135728 KB | 134984 KB | 135484 KB | 135472 KB |

besm2_fmt's speedup over each

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| yaml | 35.9x | 20.9x | 22.5x | 24.8x |
| fyaml | 32.8x | 16.2x | 17.4x | 19.7x |
| tree | 31.2x | 14.0x | 15.1x | 17.5x |
| entity | 34.5x | 20.2x | 21.5x | 24.0x |
| etree | 31.0x | 13.4x | 14.7x | 17.1x |

## Throughput: multi-document file (2000 separate documents, one entity each)

2000 `---`-delimited YAML documents in one file, each a
one-entity sequence. besm2_fmt (via `Document_Stream`) processes
all of them; every besm2-rst-family variant reads only 1 entity
below regardless of $BENCH_ENTITIES -- documented for `yaml`/
`fyaml` as a `yaml-load`/`(slibfyaml scheme)` bug in besm2-rst.scm
(not a besm2_fmt one -- see PLAN.md's former "Multi-document YAML
files aren't handled" open question) that collapses a
multi-document stream to a single document; `tree`/`entity`/
`etree` measure the same way here, though besm2-rst-f/-e/-f-e
never claimed streaming support in the first place, so this isn't
necessarily the identical root cause, just the identical observed
behavior on this file shape. This section measures each program's
actual behavior here, not an apples-to-apples per-entity
comparison -- read the entity counts alongside the timings.

Time

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| yaml | 1.83 s | 1.79 s | 1.80 s | 1.80 s |
| fyaml | 0.82 s | 0.82 s | 0.79 s | 0.80 s |
| tree | 0.05 s | 0.05 s | 0.06 s | 0.04 s |
| entity | 1.82 s | 1.83 s | 1.81 s | 1.82 s |
| etree | 0.05 s | 0.05 s | 0.05 s | 0.05 s |
| besm2_fmt | 0.41 s | 0.19 s | 0.19 s | 0.20 s |

Entities processed

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| yaml | 1 | 1 | 1 | 1 |
| fyaml | 1 | 1 | 1 | 1 |
| tree | 1 | 1 | 1 | 1 |
| entity | 1 | 1 | 1 | 1 |
| etree | 1 | 1 | 1 | 1 |
| besm2_fmt | 2000 | 2000 | 2000 | 2000 |

Peak RSS

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| yaml | 33884 KB | 38428 KB | 38048 KB | 33120 KB |
| fyaml | 46528 KB | 45672 KB | 46384 KB | 45732 KB |
| tree | 27260 KB | 26592 KB | 26320 KB | 26556 KB |
| entity | 33792 KB | 33304 KB | 33480 KB | 34092 KB |
| etree | 29588 KB | 29736 KB | 29640 KB | 29852 KB |
| besm2_fmt | 5364 KB | 5840 KB | 5640 KB | 5640 KB |
----

## Reading it

The tables above are generated (by `tools/benchmark.sh`) each time the
benchmark is rerun, so the specific figures will drift between runs
and machines; read them for shape, not for the exact numbers quoted
here at the time this section was last written by hand. This
particular run postdates `alibfyaml`'s Node/Document liveness
enforcement change (see "Historical note" above) -- `besm2_fmt`'s
margins over the `besm2-rst` family are slightly narrower than an
earlier version of this document recorded, though the shape of every
conclusion below is unchanged:

- **Time: `besm2_fmt` wins everywhere, against every variant, and the
  gap widens with scale.** ~5.8-8.1x faster per invocation on a tiny
  real fixture, ~13.4-35.9x faster processing a 2000-entity document.
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
  included, and besm-tools' own `fyaml`/`tree`/`etree` (~167-195 MB) --
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
  `fyaml`'s RSS (~193-195 MB) sitting toward the high end of
  `tree`/`etree`'s (~167-180 MB) is consistent with `(slibfyaml
  scheme)`'s eager
  whole-document decode building a *complete* second (Scheme alist)
  copy on top of libfyaml's tree, where `tree`/`etree`'s handle-based
  traversal decodes only the scalars each output backend actually
  reads. `besm2_fmt`'s own RSS here (~135 MB) is essentially unchanged
  from before the liveness-enforcement change (see "Historical note"
  above) -- `Owner_Liveness`'s extra allocation (one small heap cell
  per `Document`) is far too small to show up against `libfyaml`'s own
  C-side tree memory at this scale, exactly as `ALIBFYAML-LIVENESS-
  PERFORMANCE.md` found in isolation.

- **The multi-document file exposes a real split *within* the
  besm2-rst family, not just a shared bug.** All six programs process
  exactly 1 entity from this file except `besm2_fmt` (which gets all
  2000 -- see below), so none of the besm2-rst-family times above are
  doing 2000x less useful work than each other -- yet they range from
  ~0.04-0.06 s (`tree`/`etree`) to ~0.79-0.82 s (`fyaml`) to
  ~1.79-1.83 s (`yaml`/`entity`), a >30x spread for the *same wrong
  answer*. That
  pattern is consistent with `tree`/`etree` opening just the first
  `---`-delimited document via slibfyaml's handle API and stopping
  there (roughly constant-time regardless of how many more documents
  follow), while `yaml`/`entity` (the `yaml` egg) and `fyaml`
  (`(slibfyaml scheme)`) apparently parse or scan the *entire*
  2000-document byte stream before collapsing down to one result --
  i.e. `tree`/`etree` fail fast on this input shape, `yaml`/`fyaml`/
  `entity` fail slow, paying a cost that scales with the whole file
  even though almost all of that work is discarded. This wasn't
  separately traced in besm-tools' own source this session, so read it
  as "consistent with the numbers," not confirmed by code reading --
  but it's a large enough, consistent enough gap (reproduced across
  all four output modes) to be worth someone's attention upstream.
  `besm2_fmt`'s own `Document_Stream` handles this file shape
  correctly (all 2000 entities) and is still faster than four of the
  five besm2-rst-family variants doing 1/2000th the work (only
  `tree`/`etree`'s fail-fast path beats it, and only because it's
  doing so much less).

- **Real-world files are tiny.** The actual `test-data/*.yaml` fixtures
  are 1-3 KB, one entity each -- at that scale this is entirely
  dominated by the per-invocation numbers (a couple ms vs. 16-25 ms
  across the whole besm2-rst family), and multi-thousand-entity files
  aren't a realistic BESM character-sheet workload. The
  throughput/memory tables exist purely to separate "process startup
  and small-input cost" from "cost that actually scales with input
  size," and to give `Document_Stream`'s streaming behavior -- and,
  now, the besm2-rst family's own multi-document fail-fast/fail-slow
  split -- a file shape where they can show up in the numbers at all.
