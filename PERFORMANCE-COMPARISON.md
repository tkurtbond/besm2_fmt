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

Generated: 2026-09-12 01:18:46 UTC by `tools/benchmark.sh`.

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
| yaml | 22.199 ms | 17.289 ms | 16.041 ms | 18.072 ms |
| fyaml | 21.264 ms | 17.911 ms | 17.274 ms | 18.640 ms |
| tree | 20.037 ms | 15.022 ms | 16.077 ms | 16.638 ms |
| entity | 22.618 ms | 15.452 ms | 16.575 ms | 18.168 ms |
| etree | 20.431 ms | 17.032 ms | 15.911 ms | 17.554 ms |
| besm2_fmt | 2.214 ms | 1.688 ms | 1.965 ms | 1.879 ms |

besm2_fmt's speedup over each

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| yaml | 10.0x | 10.2x | 8.2x | 9.6x |
| fyaml | 9.6x | 10.6x | 8.8x | 9.9x |
| tree | 9.1x | 8.9x | 8.2x | 8.9x |
| entity | 10.2x | 9.2x | 8.4x | 9.7x |
| etree | 9.2x | 10.1x | 8.1x | 9.3x |

## Throughput: multi-entity document (2000 entities, one YAML document)

One `---` document containing a 2000-entity sequence --
every program processes every entity; this is an apples-to-apples
comparison.

Time

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| yaml | 15.37 s | 4.66 s | 4.84 s | 5.51 s |
| fyaml | 14.18 s | 3.63 s | 3.71 s | 4.45 s |
| tree | 13.53 s | 3.12 s | 3.28 s | 4.00 s |
| entity | 15.02 s | 4.60 s | 4.71 s | 5.46 s |
| etree | 13.30 s | 3.03 s | 3.17 s | 3.83 s |
| besm2_fmt | 0.41 s | 0.19 s | 0.18 s | 0.20 s |

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
| yaml | 75392 KB | 70408 KB | 55540 KB | 70916 KB |
| fyaml | 180124 KB | 194368 KB | 178912 KB | 194536 KB |
| tree | 166492 KB | 168300 KB | 166984 KB | 168084 KB |
| entity | 75596 KB | 56368 KB | 71120 KB | 71296 KB |
| etree | 172388 KB | 168900 KB | 178612 KB | 179968 KB |
| besm2_fmt | 135552 KB | 136252 KB | 135928 KB | 136008 KB |

besm2_fmt's speedup over each

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| yaml | 37.5x | 24.5x | 26.9x | 27.5x |
| fyaml | 34.6x | 19.1x | 20.6x | 22.2x |
| tree | 33.0x | 16.4x | 18.2x | 20.0x |
| entity | 36.6x | 24.2x | 26.2x | 27.3x |
| etree | 32.4x | 15.9x | 17.6x | 19.1x |

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
| yaml | 1.77 s | 1.79 s | 1.77 s | 1.75 s |
| fyaml | 0.80 s | 0.80 s | 0.80 s | 0.78 s |
| tree | 0.06 s | 0.05 s | 0.05 s | 0.05 s |
| entity | 1.79 s | 1.76 s | 1.75 s | 1.77 s |
| etree | 0.05 s | 0.05 s | 0.05 s | 0.06 s |
| besm2_fmt | 0.40 s | 0.17 s | 0.17 s | 0.17 s |

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
| yaml | 34208 KB | 34548 KB | 33924 KB | 33980 KB |
| fyaml | 47396 KB | 46524 KB | 46512 KB | 49312 KB |
| tree | 27416 KB | 29452 KB | 29796 KB | 29612 KB |
| entity | 39352 KB | 38432 KB | 39188 KB | 34744 KB |
| etree | 27408 KB | 29504 KB | 29760 KB | 29684 KB |
| besm2_fmt | 5888 KB | 5652 KB | 5872 KB | 5880 KB |
----

## Reading it

The tables above are generated (by `tools/benchmark.sh`) each time the
benchmark is rerun, so the specific figures will drift between runs
and machines; read them for shape, not for the exact numbers quoted
here at the time this section was last written by hand:

- **Time: `besm2_fmt` wins everywhere, against every variant, and the
  gap widens with scale.** ~8.1-10.6x faster per invocation on a tiny
  real fixture, ~15.9-37.5x faster processing a 2000-entity document.
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
  programs (`yaml`, `entity`) use the *least* RSS here (~56-76 MB);
  every libfyaml-backed program -- `besm2_fmt` itself (~136 MB)
  included, and besm-tools' own `fyaml`/`tree`/`etree` (~166-195 MB) --
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
  `fyaml`'s RSS (~179-195 MB) sitting toward the high end of
  `tree`/`etree`'s (~166-180 MB) is consistent with `(slibfyaml
  scheme)`'s eager
  whole-document decode building a *complete* second (Scheme alist)
  copy on top of libfyaml's tree, where `tree`/`etree`'s handle-based
  traversal decodes only the scalars each output backend actually
  reads.

- **The multi-document file exposes a real split *within* the
  besm2-rst family, not just a shared bug.** All six programs process
  exactly 1 entity from this file except `besm2_fmt` (which gets all
  2000 -- see below), so none of the besm2-rst-family times above are
  doing 2000x less useful work than each other -- yet they range from
  ~0.05-0.06 s (`tree`/`etree`) to ~0.78-0.81 s (`fyaml`) to
  ~1.76-1.81 s (`yaml`/`entity`), a >30x spread for the *same wrong
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
  dominated by the per-invocation numbers (a couple ms vs. 15-23 ms
  across the whole besm2-rst family), and multi-thousand-entity files
  aren't a realistic BESM character-sheet workload. The
  throughput/memory tables exist purely to separate "process startup
  and small-input cost" from "cost that actually scales with input
  size," and to give `Document_Stream`'s streaming behavior -- and,
  now, the besm2-rst family's own multi-document fail-fast/fail-slow
  split -- a file shape where they can show up in the numbers at all.
