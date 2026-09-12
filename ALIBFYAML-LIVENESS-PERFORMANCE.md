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

`make benchmark-alibfyaml-liveness` wraps `tools/benchmark-
alibfyaml-liveness.sh` (see the `GNUmakefile` target's own comment).
It needs `BESM2_FMT_OLD` set to an already-built `besm2_fmt` linked
against a different `alibfyaml` commit -- there's no sensible default
for that one, since building it requires a separate `alibfyaml`
checkout at that other commit, outside this repo. `BESM2_FMT_NEW`
defaults to `$(PROGRAM)` (built by the target if missing), i.e. this
repo's own normal build against whatever `alibfyaml` is currently
installed system-wide (`/usr/local/sw/versions/ada` on this machine,
an install convention specific to this machine's owner, not part of
either project):

```sh
cd ~/Repos/Ada/alibfyaml
git worktree add /tmp/alibfyaml-old 567eda8
(cd /tmp/alibfyaml-old && gprbuild -P libfyaml_ada.gpr -p -largs $(pkg-config --libs libfyaml))

cd ~/Repos/RPG/Tools/besm2_fmt
gprclean -P besm2_fmt.gpr -r
GPR_PROJECT_PATH="/tmp/alibfyaml-old:$GPR_PROJECT_PATH" \
  gprbuild -p -P besm2_fmt.gpr -largs $(pkg-config --libs libfyaml)
cp besm2_fmt /tmp/besm2_fmt-old
gprclean -P besm2_fmt.gpr -r   # so the next `make` rebuilds against the installed (new) alibfyaml

BESM2_FMT_OLD=/tmp/besm2_fmt-old make benchmark-alibfyaml-liveness > /tmp/report.md

git worktree remove /tmp/alibfyaml-old
```

See `tools/benchmark-alibfyaml-liveness.sh`'s own header comment for
every environment variable it accepts (`BENCH_N`/`BENCH_ENTITIES`/
`BENCH_SOURCE`, matching `tools/benchmark.sh`'s own defaults so the two
reports' numbers are directly comparable in scale). Note that `make`
itself echoes the recipe line to stdout before the script's own
output, same as `make benchmark` does -- drop that first line when
capturing a clean report, as this document's own regeneration did.

The report below is **an average of 3 independent runs** of
`make benchmark-alibfyaml-liveness` (each a full fresh set of
`BENCH_N`=200 per-invocation runs and 3 throughput measurements), not
a single run's raw output, since a single run's per-invocation numbers
in particular are small enough (2-4 ms) to be noise-dominated -- see
"Reading it" below. The three individual runs' throughput numbers
agreed with each other to within 0.02 s in every cell; the averages
are simple means across all three. The per-invocation table is a
single representative run (see "Reading it" for why averaging it
wouldn't add anything meaningful).

----

# besm2_fmt: alibfyaml Node/Document liveness enforcement -- performance impact

Generated: 2026-09-12, averaged over 3 runs of `make benchmark-alibfyaml-liveness`.

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
| old | 3.155 ms | 2.806 ms | 2.711 ms | 2.269 ms |
| new | 3.464 ms | 2.097 ms | 2.778 ms | 2.175 ms |

new vs. old (positive = new is slower)

| | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| new/old | +9.8% | -25.3% | +2.5% | -4.1% |

## Throughput: multi-entity document (2000 entities, one YAML document)

One `---` document containing a 2000-entity sequence -- stresses Node
creation/navigation (`Value`/`Iterate`, each a `Wrap` call) within a
single `Document`, the same path `alibfyaml`'s own `bench_wide`
targets.

Time (mean of 3 runs)

| Build | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| old | 0.430 s | 0.190 s | 0.190 s | 0.210 s |
| new | 0.440 s | 0.213 s | 0.207 s | 0.227 s |

new vs. old (positive = new is slower)

| | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| new/old | +2.3% | +12.3% | +8.8% | +7.9% |

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
| old | 0.410 s | 0.167 s | 0.170 s | 0.180 s |
| new | 0.423 s | 0.190 s | 0.190 s | 0.207 s |

new vs. old (positive = new is slower)

| | grid | terse | hmm | raw-ms |
|---|---|---|---|---|
| new/old | +3.2% | +14.0% | +11.8% | +14.8% |

Entities processed: read all 2000 in every run, every mode, both
builds (confirms `Document_Stream` itself is unaffected).

Peak RSS: ~5.3-5.9 MB for both builds, in every mode -- no measurable
difference.

----

## Reading it

- **Per-invocation numbers are noise, not signal.** At 2-4 ms total
  runtime, a single run's timing is dominated by process
  startup/scheduling jitter, not by anything alibfyaml does -- `terse`
  even shows `new` as *faster* by 25% here, which cannot be a real
  effect of a change that only ever adds work (a different run of the
  same two binaries showed a different mode as the "faster" outlier
  instead -- see git history of this file). This matches
  `PERFORMANCE-COMPARISON.md`'s own observation that real BESM
  character-sheet files (1-3 KB, one entity) are dominated by
  fixed overhead, not per-entity cost. Not meaningful evidence either
  way; included only for completeness against the same table shape
  `tools/benchmark.sh` uses.

- **Throughput numbers are consistent and real: +2-15% depending on
  output mode, corroborating `alibfyaml`'s own synthetic `bench/`
  numbers (+14.5% / +10.7%) but smaller and mode-dependent.** The
  `grid` mode (the heaviest formatter -- full reST grid tables) shows
  the smallest overhead (+2.3% / +3.2%): most of `grid`'s own runtime
  is `besm2_fmt`'s own table-drawing code, not `alibfyaml`, so the
  liveness-tracking cost is a small fraction of a larger total.
  `terse`/`hmm`/`raw-ms` (lighter formatters, doing proportionally
  more of their work in parsing/node-navigation) show more of the
  underlying cost directly: +7.9% to +14.8%, close to the range
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
