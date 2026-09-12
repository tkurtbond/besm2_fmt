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

Generated: 2026-09-12 00:28:16 UTC by `tools/benchmark.sh`.

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
| besm2-rst | 21.140 ms | 17.275 ms | 15.988 ms | 17.615 ms |
| besm2-rst -f/--fyaml | 20.933 ms | 16.581 ms | 17.615 ms | 18.193 ms |
| besm2-rst-f | 20.880 ms | 14.746 ms | 15.949 ms | 16.852 ms |
| besm2-rst-e | 22.904 ms | 16.164 ms | 16.683 ms | 17.089 ms |
| besm2-rst-f-e | 21.103 ms | 16.953 ms | 16.081 ms | 17.655 ms |
| besm2_fmt | 2.191 ms | 1.922 ms | 2.037 ms | 2.036 ms |

besm2_fmt's speedup over each

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| besm2-rst | 9.6x | 9.0x | 7.8x | 8.7x |
| besm2-rst -f/--fyaml | 9.6x | 8.6x | 8.6x | 8.9x |
| besm2-rst-f | 9.5x | 7.7x | 7.8x | 8.3x |
| besm2-rst-e | 10.5x | 8.4x | 8.2x | 8.4x |
| besm2-rst-f-e | 9.6x | 8.8x | 7.9x | 8.7x |

## Throughput: multi-entity document (2000 entities, one YAML document)

One `---` document containing a 2000-entity sequence --
every program processes every entity; this is an apples-to-apples
comparison.

Time

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| besm2-rst | 15.59 s | 4.77 s | 4.84 s | 5.55 s |
| besm2-rst -f/--fyaml | 13.99 s | 3.57 s | 3.76 s | 4.45 s |
| besm2-rst-f | 13.48 s | 3.15 s | 3.30 s | 3.99 s |
| besm2-rst-e | 15.04 s | 4.63 s | 4.68 s | 5.45 s |
| besm2-rst-f-e | 13.42 s | 3.00 s | 3.13 s | 3.89 s |
| besm2_fmt | 0.42 s | 0.19 s | 0.19 s | 0.20 s |

Entities processed (sanity check -- should read 2000 everywhere)

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| besm2-rst | 2000 | 2000 | 2000 | 2000 |
| besm2-rst -f/--fyaml | 2000 | 2000 | 2000 | 2000 |
| besm2-rst-f | 2000 | 2000 | 2000 | 2000 |
| besm2-rst-e | 2000 | 2000 | 2000 | 2000 |
| besm2-rst-f-e | 2000 | 2000 | 2000 | 2000 |
| besm2_fmt | 2000 | 2000 | 2000 | 2000 |

Peak RSS

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| besm2-rst | 59020 KB | 55400 KB | 69940 KB | 71080 KB |
| besm2-rst -f/--fyaml | 195256 KB | 193872 KB | 193520 KB | 194884 KB |
| besm2-rst-f | 166452 KB | 168884 KB | 178560 KB | 167996 KB |
| besm2-rst-e | 75532 KB | 70656 KB | 71376 KB | 70972 KB |
| besm2-rst-f-e | 172584 KB | 178180 KB | 178844 KB | 171120 KB |
| besm2_fmt | 135204 KB | 135420 KB | 136228 KB | 135676 KB |

besm2_fmt's speedup over each

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| besm2-rst | 37.1x | 25.1x | 25.5x | 27.7x |
| besm2-rst -f/--fyaml | 33.3x | 18.8x | 19.8x | 22.2x |
| besm2-rst-f | 32.1x | 16.6x | 17.4x | 19.9x |
| besm2-rst-e | 35.8x | 24.4x | 24.6x | 27.2x |
| besm2-rst-f-e | 32.0x | 15.8x | 16.5x | 19.4x |

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
| besm2-rst | 1.76 s | 1.76 s | 1.77 s | 1.77 s |
| besm2-rst -f/--fyaml | 0.78 s | 0.79 s | 0.78 s | 0.79 s |
| besm2-rst-f | 0.06 s | 0.05 s | 0.05 s | 0.06 s |
| besm2-rst-e | 1.78 s | 1.77 s | 1.75 s | 1.80 s |
| besm2-rst-f-e | 0.06 s | 0.05 s | 0.05 s | 0.05 s |
| besm2_fmt | 0.40 s | 0.17 s | 0.17 s | 0.18 s |

Entities processed

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| besm2-rst | 1 | 1 | 1 | 1 |
| besm2-rst -f/--fyaml | 1 | 1 | 1 | 1 |
| besm2-rst-f | 1 | 1 | 1 | 1 |
| besm2-rst-e | 1 | 1 | 1 | 1 |
| besm2-rst-f-e | 1 | 1 | 1 | 1 |
| besm2_fmt | 2000 | 2000 | 2000 | 2000 |

Peak RSS

| Program | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| besm2-rst | 34332 KB | 38472 KB | 34172 KB | 34004 KB |
| besm2-rst -f/--fyaml | 47108 KB | 46784 KB | 46704 KB | 49244 KB |
| besm2-rst-f | 27140 KB | 26724 KB | 26236 KB | 26756 KB |
| besm2-rst-e | 34880 KB | 34124 KB | 38992 KB | 34952 KB |
| besm2-rst-f-e | 27168 KB | 29588 KB | 29776 KB | 29596 KB |
| besm2_fmt | 5712 KB | 5632 KB | 5624 KB | 5900 KB |

----

## Reading it

The tables above are generated (by `tools/benchmark.sh`) each time the
benchmark is rerun, so the specific figures will drift between runs
and machines; read them for shape, not for the exact numbers quoted
here at the time this section was last written by hand:

- **Time: `besm2_fmt` wins everywhere, against every variant, and the
  gap widens with scale.** ~7.7-10.5x faster per invocation on a tiny
  real fixture, ~15.8-37.1x faster processing a 2000-entity document.
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
  `fyaml`'s RSS (~194 MB) being noticeably higher than `tree`/`etree`'s
  (~166-179 MB) is consistent with `(slibfyaml scheme)`'s eager
  whole-document decode building a *complete* second (Scheme alist)
  copy on top of libfyaml's tree, where `tree`/`etree`'s handle-based
  traversal decodes only the scalars each output backend actually
  reads.

- **The multi-document file exposes a real split *within* the
  besm2-rst family, not just a shared bug.** All six programs process
  exactly 1 entity from this file except `besm2_fmt` (which gets all
  2000 -- see below), so none of the besm2-rst-family times above are
  doing 2000x less useful work than each other -- yet they range from
  ~0.05 s (`tree`/`etree`) to ~0.78 s (`fyaml`) to ~1.76-1.80 s
  (`yaml`/`entity`), a >30x spread for the *same wrong answer*. That
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
