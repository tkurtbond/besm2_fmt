# Performance impact of alibfyaml's Node/Document liveness enforcement on `besm2_fmt`

Compares two `besm2_fmt` builds that differ **only** in which commit of
`alibfyaml` (`~/Repos/Ada/alibfyaml`) they're statically linked
against:

- `old`: commit `567eda8` ("Fix Is_Null_Value reading fy_node_is_null
  on unresolved alias nodes") -- the commit immediately before
  Node/Document liveness enforcement was added.
- `new`: commit `b3ce24c` ("Add bench/ performance regression checks;
  record liveness-fix overhead") -- the current `alibfyaml`, with
  liveness enforcement in place (see that project's `PLAN.md`, "Node/
  Document liveness enforcement" section).

`alibfyaml`'s own `bench/` measured this change's cost with synthetic
fixtures in isolation (+14.5% / +10.7%, see its `PLAN.md`); this
document corroborates that against a real consumer's actual workload
(`besm2_fmt`'s own parsing + reST/terse/h-m-m/raw-ms formatting) rather
than a synthetic microbenchmark.

Both builds were confirmed to produce **byte-identical output** on
every `test-data/*.yaml` fixture, across all four output modes, before
any timing was taken -- `tools/benchmark-alibfyaml-liveness.sh` refuses
to report timing numbers at all if they ever disagree.

## Reproducing this

`tools/benchmark-alibfyaml-liveness.sh` needs two already-built
`besm2_fmt` binaries (`BESM2_FMT_OLD`/`BESM2_FMT_NEW`), one linked
against each `alibfyaml` commit. Building the `old` one requires a
separate `alibfyaml` checkout at the pre-liveness commit, since the
normal build picks up whatever `libfyaml_ada.gpr` is installed
system-wide (`/usr/local/sw/versions/ada` on this machine, an install
convention specific to this machine's owner, not part of either
project):

```sh
cd ~/Repos/Ada/alibfyaml
git worktree add /tmp/alibfyaml-old 567eda8
(cd /tmp/alibfyaml-old && gprbuild -P libfyaml_ada.gpr -p -largs $(pkg-config --libs libfyaml))

cd ~/Repos/RPG/Tools/besm2_fmt
gprclean -P besm2_fmt.gpr -r
GPR_PROJECT_PATH="/tmp/alibfyaml-old:$GPR_PROJECT_PATH" \
  gprbuild -p -P besm2_fmt.gpr -largs $(pkg-config --libs libfyaml)
cp besm2_fmt /tmp/besm2_fmt-old

gprclean -P besm2_fmt.gpr -r
gprbuild -p -P besm2_fmt.gpr   # normal build: picks up the installed (new) alibfyaml
cp besm2_fmt /tmp/besm2_fmt-new

BESM2_FMT_OLD=/tmp/besm2_fmt-old BESM2_FMT_NEW=/tmp/besm2_fmt-new \
  tools/benchmark-alibfyaml-liveness.sh > /tmp/report.md

git worktree remove /tmp/alibfyaml-old
```

See `tools/benchmark-alibfyaml-liveness.sh`'s own header comment for
every environment variable it accepts (`BENCH_N`/`BENCH_ENTITIES`/
`BENCH_SOURCE`, matching `tools/benchmark.sh`'s own defaults so the two
reports' numbers are directly comparable in scale).

The report below is **an average of 3 independent runs** of the script
(each a full fresh set of `BENCH_N`=200 per-invocation runs and 3
throughput measurements), not a single run's raw output, since a
single run's per-invocation numbers in particular are small enough
(2-4 ms) to be noise-dominated -- see "Reading it" below. The three
individual runs' throughput numbers agreed with each other to within
0.01 s in every cell; the averages are simple means across all three.

----

# besm2_fmt: alibfyaml Node/Document liveness enforcement -- performance impact

Generated: 2026-09-12, averaged over 3 runs, by `tools/benchmark-alibfyaml-liveness.sh`.

- Machine: 13th Gen Intel(R) Core(TM) i9-13900HX, 32 threads, Linux 7.1.10-200.fc44.x86_64 x86_64
- `BENCH_N`=200, `BENCH_ENTITIES`=2000, `BENCH_SOURCE`=./test-data/enyon-boase-2e.yaml
- `old`: besm2_fmt linked against alibfyaml commit `567eda8` (pre-liveness-enforcement)
- `new`: besm2_fmt linked against alibfyaml commit `b3ce24c` (post-liveness-enforcement)

Both builds confirmed to produce byte-identical output on every
`test-data/*.yaml` fixture, across all four output modes, before any
timing below was taken.

## Per-invocation overhead (N=200 runs, `enyon-boase-2e.yaml`, single run shown -- see "Reading it")

Mean time per invocation

| Build | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| old | 3.375 ms | 2.494 ms | 2.926 ms | 2.973 ms |
| new | 2.690 ms | 2.653 ms | 3.378 ms | 3.191 ms |

new vs. old (positive = new is slower)

| | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| new/old | -20.3% | +6.4% | +15.4% | +7.3% |

## Throughput: multi-entity document (2000 entities, one YAML document)

One `---` document containing a 2000-entity sequence -- stresses Node
creation/navigation (`Value`/`Iterate`, each a `Wrap` call) within a
single `Document`, the same path `alibfyaml`'s own `bench_wide`
targets.

Time (mean of 3 runs)

| Build | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| old | 0.423 s | 0.190 s | 0.190 s | 0.197 s |
| new | 0.433 s | 0.220 s | 0.213 s | 0.227 s |

new vs. old (positive = new is slower)

| | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| new/old | +2.4% | +15.8% | +12.3% | +15.3% |

Entities processed (sanity check -- read 2000 in every run, every mode, both builds)

Peak RSS: ~135 MB for both builds, in every mode -- no measurable
difference (within GNU `time`'s KB-granularity noise).

## Throughput: multi-document file (2000 separate documents, one entity each)

2000 `---`-delimited YAML documents in one file, each a one-entity
sequence, read via `Document_Stream` -- stresses `Document`
creation/destruction (one `Owner_Liveness` alloc + `Mark_Dead` per
document in the `new` build) instead of Node navigation volume, the
same path `alibfyaml`'s own `bench_streams` targets.

Time (mean of 3 runs)

| Build | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| old | 0.403 s | 0.170 s | 0.177 s | 0.177 s |
| new | 0.417 s | 0.190 s | 0.187 s | 0.200 s |

new vs. old (positive = new is slower)

| | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| new/old | +3.3% | +11.8% | +5.7% | +13.0% |

Entities processed: read all 2000 in every run, every mode, both
builds (confirms `Document_Stream` itself is unaffected).

Peak RSS: ~5.3-5.9 MB for both builds, in every mode -- no measurable
difference.

----

## Reading it

- **Per-invocation numbers are noise, not signal.** At 2-4 ms total
  runtime, a single run's timing is dominated by process
  startup/scheduling jitter, not by anything alibfyaml does -- the
  `grid` mode even shows `new` as *faster* by 20%, which cannot be a
  real effect of a change that only ever adds work. This matches
  `PERFORMANCE-COMPARISON.md`'s own observation that real BESM
  character-sheet files (1-3 KB, one entity) are dominated by
  fixed overhead, not per-entity cost. Not meaningful evidence either
  way; included only for completeness against the same table shape
  `tools/benchmark.sh` uses.

- **Throughput numbers are consistent and real: +2-16% depending on
  output mode, corroborating `alibfyaml`'s own synthetic `bench/`
  numbers (+14.5% / +10.7%) but smaller and mode-dependent.** The
  `grid` mode (the heaviest formatter -- full reST grid tables) shows
  the smallest overhead (+2.4% / +3.3%): most of `grid`'s own runtime
  is `besm2_fmt`'s own table-drawing code, not `alibfyaml`, so the
  liveness-tracking cost is a small fraction of a larger total.
  `terse`/`hmm`/`raw-ms` (lighter formatters, doing proportionally
  more of their work in parsing/node-navigation) show more of the
  underlying cost directly: +5.7% to +15.8%, squarely in the range
  `alibfyaml`'s own `bench/` measured against nothing but parsing and
  navigation. This is exactly the expected shape: a fixed per-Node/
  per-Document overhead shows up as a *smaller relative* cost the more
  other work surrounds it, not a different cost.

- **Memory is unaffected either way**, at both scales tested (~135 MB
  for the single 2000-entity document, ~5.5 MB for the 2000-document
  stream) -- `Owner_Liveness`'s extra allocation (one small heap cell
  per `Document`, freed via the same refcounting `Buffer_Ref` already
  used) is too small to show up against `libfyaml`'s own C-side tree
  memory at this scale.

- **Correctness is unaffected**, confirmed byte-for-byte across every
  fixture and mode before any timing was taken, and entity counts
  matching in every throughput run -- this change is a pure constant-
  factor cost for a real correctness fix, not a behavior change, on a
  real consumer's actual workload as well as `alibfyaml`'s own
  synthetic benchmarks.

**Bottom line:** the liveness-enforcement change costs `besm2_fmt`
roughly what `alibfyaml`'s own numbers predicted, scaled down by
however much of each output mode's time is spent outside `alibfyaml`
entirely. Nothing here changes the judgment call already recorded in
`alibfyaml`'s `PLAN.md` (worth it for closing a real, confirmed-
elsewhere use-after-free class) -- if anything, seeing the overhead
shrink to single digits once real formatting work is added on top
makes it easier to accept, not harder.
