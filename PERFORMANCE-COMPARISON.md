# Performance comparison: `besm2_fmt` vs `besm2-rst`

Compares `besm2_fmt` (this project, Ada/GNAT) against `besm2-rst` (the
original Chicken Scheme implementation this project is a port of, from
[besm-tools](https://github.com/tkurtbond/besm-tools)). Both binaries
were verified to produce byte-identical output on every input used
below before timing.

## Reproducing this

The report below (everything between the `----` markers) is the
unedited stdout of `tools/benchmark.sh` — regenerate it with:

```
BESM2_RST=/path/to/a/freshly-built/besm2-rst tools/benchmark.sh > /tmp/report.md
```

or `make benchmark` (same script; prints to the terminal instead of a
file). `BESM2_RST` isn't required — omit it for a `besm2_fmt`-only
report — but if a `besm2-rst` happens to be on `PATH`, the script will
use it with a loud warning rather than silently trusting it, since a
`PATH`-installed one can easily be stale (built before some fix
landed upstream in besm-tools). See `tools/benchmark.sh`'s header
comment for every environment variable it accepts
(`BENCH_N`/`BENCH_ENTITIES`/`BENCH_SOURCE`) and its Linux/GNU-coreutils
dependencies (GNU `time`, GNU `date`).

A methodological pitfall the script's design deliberately routes
around: naively concatenating a single-entity fixture N times to build
a synthetic multi-entity file produces N separate YAML *documents*
(since the fixture starts with its own `---` marker), not one
N-entity document — which would silently trigger the documented
`besm2-rst.scm` bug where multi-document input collapses to just the
last document. The script generates the "multi-entity" and
"multi-document" fixtures below deliberately, as two distinct, correct
shapes, specifically so that bug's effect can be measured on purpose
in the last table rather than showing up by accident in the others.

----

# besm2_fmt vs besm2-rst benchmark

Generated: 2026-09-08 21:56:06 UTC by `tools/benchmark.sh`.

- Machine: 13th Gen Intel(R) Core(TM) i9-13900HX, 32 threads, Linux 7.1.10-200.fc44.x86_64 x86_64
- `besm2_fmt`: `./besm2_fmt`
- `besm2-rst`: `/home/tkb/current/RPG/Tools/BESM/build/besm2-rst`
- `BENCH_N`=200, `BENCH_ENTITIES`=2000, `BENCH_SOURCE`=./test-data/enyon-boase-2e.yaml

## Per-invocation overhead (N=200 runs, `enyon-boase-2e.yaml`)

| Mode | besm2-rst | besm2_fmt | speedup |
|---|---|---|---|
| grid | 20.501 ms | 2.726 ms | 7.5x |
| terse | 15.275 ms | 2.549 ms | 6.0x |
| hmm | 14.774 ms | 2.263 ms | 6.5x |
| raw-ms | 17.629 ms | 3.195 ms | 5.5x |

## Throughput: multi-entity document (2000 entities, one YAML document)

One `---` document containing a 2000-entity sequence --
both tools process every entity; this is an apples-to-apples
comparison.

| Mode | besm2-rst (entities) | besm2_fmt (entities) | speedup | besm2-rst RSS | besm2_fmt RSS |
|---|---|---|---|---|---|
| grid | 16.33 s (2000) | 0.44 s (2000) | 37.1x | 74356 KB | 135748 KB |
| terse | 4.99 s (2000) | 0.20 s (2000) | 24.9x | 69080 KB | 135712 KB |
| hmm | 5.15 s (2000) | 0.20 s (2000) | 25.8x | 67348 KB | 135968 KB |
| raw-ms | 5.94 s (2000) | 0.21 s (2000) | 28.3x | 54336 KB | 136052 KB |

## Throughput: multi-document file (2000 separate documents, one entity each)

2000 `---`-delimited YAML documents in one file, each a
one-entity sequence -- besm2-rst's `yaml-load` collapses a
multi-document stream to just the *last* document (a known bug in
besm2-rst.scm, not a besm2_fmt one -- see PLAN.md's former
"Multi-document YAML files aren't handled" open question), so its
entity count below is 1 regardless of $BENCH_ENTITIES, while
besm2_fmt (via `Document_Stream`) processes all of them. This
section measures each tool's actual behavior on this file shape,
not an apples-to-apples per-entity comparison -- read the entity
counts alongside the timings.

| Mode | besm2-rst (entities) | besm2_fmt (entities) | besm2-rst RSS | besm2_fmt RSS |
|---|---|---|---|---|
| grid | 1.95 s (1) | 0.41 s (2000) | 33556 KB | 5392 KB |
| terse | 1.90 s (1) | 0.17 s (2000) | 33752 KB | 5616 KB |
| hmm | 1.92 s (1) | 0.17 s (2000) | 37928 KB | 5440 KB |
| raw-ms | 1.91 s (1) | 0.18 s (2000) | 33012 KB | 5432 KB |

----

## Reading it

- **Time: `besm2_fmt` wins everywhere, and the gap widens with scale.**
  ~6-7x faster per invocation on a tiny real fixture, ~25-37x faster
  processing a 2000-entity document. The throughput gap growing faster
  than the fixed-overhead gap points to an algorithmic difference, not
  just constant-factor process-startup cost — most likely Chicken's
  pure-Scheme `yaml` egg parser and `(schemepunk show)`/SRFI 166's
  combinator-based formatting (lots of closures and per-character
  dispatch) versus `besm2_fmt`'s C-backed `libfyaml` parser (via
  `alibfyaml`) and Ada's `Text_IO`/`String` handling. Rebuilding both
  with optimization (`-O2 -gnatn` / `-O3`) changed nothing within
  noise for either binary, so this is structural, not a
  missing-build-flag artifact.

- **Memory tells two different stories depending on file shape, and
  the multi-document case is the interesting one.** On the
  multi-*entity* file (one big document, 2000 entities in a single
  sequence), `besm2_fmt` uses *more* RSS than `besm2-rst` (~136 MB vs.
  ~55-75 MB) — unsurprising, since libfyaml has to parse and hold the
  entire node tree in memory before any entity can be read out of it,
  and 2000 entities' worth of tree costs more per-entity than Chicken's
  alist-based representation apparently does. But on the
  multi-*document* file (2000 separate one-entity documents in one
  file), `besm2_fmt`'s RSS *drops* to ~5.5 MB — dramatically lower than
  either its own multi-entity number or `besm2-rst`'s ~33-38 MB on the
  same file. That's `Document_Stream`'s `Has_Next`/`Next` doing exactly
  what a real streaming API should: each document's `libfyaml` tree is
  parsed, consumed, and freed before the next one is read, so peak
  memory stays bounded by one document's size rather than the whole
  file's. `besm2-rst`'s lower (but not nearly as low) multi-document
  RSS is a side effect of its own bug, not deliberate streaming — it
  still builds and discards 2000 alists one after another via
  `yaml-load`'s document-collapsing behavior, so it's not holding all
  2000 in memory either, just not for a reason worth taking credit for.

- **Real-world files are tiny.** The actual `test-data/*.yaml` fixtures
  are 1-3 KB, one entity each — at that scale this is entirely
  dominated by the per-invocation numbers (a few ms vs. a couple dozen
  ms), and multi-thousand-entity files aren't a realistic BESM
  character-sheet workload. The throughput/memory tables exist purely
  to separate "process startup and small-input cost" from "cost that
  actually scales with input size," and to give `Document_Stream`'s
  streaming behavior a file shape where it can show up in the numbers
  at all.
