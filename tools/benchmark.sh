#!/bin/bash
# tools/benchmark.sh - reproduces COMPARISON.md's besm2_fmt-vs-besm2-rst
# performance numbers.
#
# All progress/status/warning messages go to stderr; the Markdown
# report goes to stdout only -- so `tools/benchmark.sh > COMPARISON.md`
# (or `make benchmark > COMPARISON.md`) captures a clean report while
# progress stays visible on the terminal.
#
# Requires (Linux/GNU-coreutils specific, not portable to macOS/BSD):
#   - GNU time (/usr/bin/time, for the `-f "%e %M"` format -- bash's
#     builtin `time` and BSD/macOS `time` don't support this)
#   - GNU date (for `date +%s.%N` sub-second precision)
#   - gprbuild, awk (standard on this project's dev machine already)
#
# Environment variables (all optional):
#   BESM2_FMT      Path to the besm2_fmt binary. Default: ./besm2_fmt
#                  relative to the repo root, built via `gprbuild` if
#                  missing.
#   BESM2_RST      Path to a besm2-rst binary (from besm-tools) to
#                  compare against. If unset, falls back to `PATH` --
#                  but that fallback is NOT trusted silently: it warns
#                  loudly on stderr and the resolved path is printed
#                  in the report header, since a PATH-installed
#                  besm2-rst can easily be stale (built before a fix
#                  landed in besm-tools). If no besm2-rst can be found
#                  at all, the report is produced in besm2_fmt-only
#                  mode (no comparison columns).
#   BENCH_N        Per-invocation-overhead run count. Default: 200.
#   BENCH_ENTITIES Entity count for the throughput fixtures. Default:
#                  2000.
#   BENCH_SOURCE   The single-entity, single-document YAML fixture
#                  used as the basis for both the per-invocation-
#                  overhead test and the generated throughput
#                  fixtures. Must itself start with a "---" document
#                  marker (test-data/enyon-boase-2e.yaml, the default,
#                  does). Default: test-data/enyon-boase-2e.yaml.
#
# Generated throughput fixtures are written under build/ (already
# gitignored) and regenerated fresh on every run rather than cached,
# so the report never drifts from BENCH_ENTITIES/BENCH_SOURCE.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BESM2_FMT="${BESM2_FMT:-$ROOT/besm2_fmt}"
BENCH_N="${BENCH_N:-200}"
BENCH_ENTITIES="${BENCH_ENTITIES:-2000}"
BENCH_SOURCE="${BENCH_SOURCE:-$ROOT/test-data/enyon-boase-2e.yaml}"
BENCH_DIR="$ROOT/build"

log () { echo "benchmark.sh: $*" >&2; }
die () { echo "benchmark.sh: error: $*" >&2; exit 1; }

# ---------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------

command -v gprbuild >/dev/null || die "gprbuild not found on PATH"
command -v awk >/dev/null || die "awk not found on PATH"
/usr/bin/time -f "%e %M" true >/dev/null 2>/tmp/benchmark_sh_time_check.$$ \
  || die "GNU time (/usr/bin/time, supporting -f) not found -- required for RSS measurement"
rm -f /tmp/benchmark_sh_time_check.$$
case "$(date +%s.%N)" in
  [0-9]*.[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) : ;;
  *) die "date +%s.%N doesn't produce sub-second precision -- need GNU date" ;;
esac
[ -f "$BENCH_SOURCE" ] || die "BENCH_SOURCE not found: $BENCH_SOURCE"
head -n 1 "$BENCH_SOURCE" | command grep -q '^---$' \
  || die "BENCH_SOURCE must start with a '---' document marker: $BENCH_SOURCE"

if [ ! -x "$BESM2_FMT" ]; then
  log "building besm2_fmt ($BESM2_FMT not found)..."
  gprbuild -p -P "$ROOT/besm2_fmt.gpr" >&2
fi
[ -x "$BESM2_FMT" ] || die "besm2_fmt still not found/executable after build: $BESM2_FMT"

HAVE_RST=1
if [ -z "${BESM2_RST:-}" ]; then
  if command -v besm2-rst >/dev/null 2>&1; then
    BESM2_RST="$(command -v besm2-rst)"
    log "WARNING: BESM2_RST not set, falling back to PATH: $BESM2_RST"
    log "WARNING: this may be a stale build -- set BESM2_RST explicitly to a" \
        "freshly-built besm2-rst to be sure the comparison is current."
  else
    log "WARNING: no besm2-rst found (set BESM2_RST) -- report will be" \
        "besm2_fmt-only, no comparison"
    HAVE_RST=0
    BESM2_RST=""
  fi
elif [ ! -x "$BESM2_RST" ]; then
  die "BESM2_RST is set but not executable: $BESM2_RST"
fi

mkdir -p "$BENCH_DIR"

# ---------------------------------------------------------------
# Fixture generation
# ---------------------------------------------------------------

# One YAML document containing a BENCH_ENTITIES-entity sequence --
# strips every "---" marker but the first before repeating the body,
# so this is genuinely one document, not BENCH_ENTITIES of them (see
# the header comment/COMPARISON.md for why that distinction matters).
gen_multi_entity () {
  local n="$1" out="$2" body
  body="$(mktemp)"
  tail -n +2 "$BENCH_SOURCE" > "$body"
  { echo "---"; for ((i = 0; i < n; i++)); do cat "$body"; done; } > "$out"
  rm -f "$body"
}

# BENCH_ENTITIES separate "---"-delimited documents, each a
# one-entity sequence -- i.e. exactly what naively concatenating
# BENCH_SOURCE N times produces, since it already carries its own
# leading "---".
gen_multi_doc () {
  local n="$1" out="$2"
  : > "$out"
  for ((i = 0; i < n; i++)); do cat "$BENCH_SOURCE" >> "$out"; done
}

MULTI_ENTITY_FILE="$BENCH_DIR/bench-multi-entity-$BENCH_ENTITIES.yaml"
MULTI_DOC_FILE="$BENCH_DIR/bench-multi-doc-$BENCH_ENTITIES.yaml"

log "generating $BENCH_ENTITIES-entity fixtures into $BENCH_DIR ..."
gen_multi_entity "$BENCH_ENTITIES" "$MULTI_ENTITY_FILE"
gen_multi_doc "$BENCH_ENTITIES" "$MULTI_DOC_FILE"

ENTITY_NAME="$(sed -n 's/^- name: *//p' "$BENCH_SOURCE" | head -n 1)"
[ -n "$ENTITY_NAME" ] || die "couldn't extract the entity name from $BENCH_SOURCE"

# ---------------------------------------------------------------
# Timing helpers
# ---------------------------------------------------------------

MODES=("grid:-s" "terse:-s -t" "hmm:-s -H" "raw-ms:-s -m")

# Mean wall-clock ms/invocation over BENCH_N runs of `prog flags file`.
time_n () {
  local prog="$1" flags="$2" file="$3" start end
  # shellcheck disable=SC2086
  "$prog" $flags "$file" >/dev/null   # warm the page cache
  start=$(date +%s.%N)
  for ((i = 0; i < BENCH_N; i++)); do
    # shellcheck disable=SC2086
    "$prog" $flags "$file" >/dev/null
  done
  end=$(date +%s.%N)
  awk -v s="$start" -v e="$end" -v n="$BENCH_N" \
    'BEGIN { printf "%.3f", (e - s) * 1000 / n }'
}

# Single run of `prog flags file`, capturing seconds and max RSS (KB)
# via GNU time, plus a count of ENTITY_NAME occurrences in the output
# (how many entities the tool actually formatted) -- writes the tool's
# output to a temp file rather than a shell variable, since a
# BENCH_ENTITIES-entity run's output can run to several MB.
time_one () {
  local prog="$1" flags="$2" file="$3" tf of secs rss count
  tf="$(mktemp)"
  of="$(mktemp)"
  # shellcheck disable=SC2086
  /usr/bin/time -f "%e %M" -o "$tf" "$prog" $flags "$file" > "$of"
  read -r secs rss < "$tf"
  rm -f "$tf"
  count="$(command grep -c -F "$ENTITY_NAME" "$of" || true)"
  rm -f "$of"
  printf '%s\t%s\t%s' "$secs" "$rss" "$count"
}

# ---------------------------------------------------------------
# Report
# ---------------------------------------------------------------

CPU_MODEL="$(command grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ *//')"
NPROC="$(nproc 2>/dev/null || echo '?')"
KERNEL="$(uname -srm)"

echo "# besm2_fmt vs besm2-rst benchmark"
echo
echo "Generated: $(date -u +'%Y-%m-%d %H:%M:%S UTC') by \`tools/benchmark.sh\`."
echo
echo "- Machine: ${CPU_MODEL:-unknown CPU}, $NPROC threads, $KERNEL"
echo "- \`besm2_fmt\`: \`$BESM2_FMT\`"
if [ "$HAVE_RST" -eq 1 ]; then
  echo "- \`besm2-rst\`: \`$BESM2_RST\`"
else
  echo "- \`besm2-rst\`: not found -- besm2_fmt-only report, no comparison"
fi
echo "- \`BENCH_N\`=$BENCH_N, \`BENCH_ENTITIES\`=$BENCH_ENTITIES, \`BENCH_SOURCE\`=$BENCH_SOURCE"
echo

echo "## Per-invocation overhead (N=$BENCH_N runs, \`$(basename "$BENCH_SOURCE")\`)"
echo
if [ "$HAVE_RST" -eq 1 ]; then
  echo "| Mode | besm2-rst | besm2_fmt | speedup |"
  echo "|---|---|---|---|"
else
  echo "| Mode | besm2_fmt |"
  echo "|---|---|"
fi
for m in "${MODES[@]}"; do
  mode="${m%%:*}"; flags="${m#*:}"
  fmt_ms=$(time_n "$BESM2_FMT" "$flags" "$BENCH_SOURCE")
  if [ "$HAVE_RST" -eq 1 ]; then
    rst_ms=$(time_n "$BESM2_RST" "$flags" "$BENCH_SOURCE")
    speedup=$(awk -v r="$rst_ms" -v f="$fmt_ms" 'BEGIN { printf "%.1f", r / f }')
    echo "| $mode | ${rst_ms} ms | ${fmt_ms} ms | ${speedup}x |"
  else
    echo "| $mode | ${fmt_ms} ms |"
  fi
done
echo

echo "## Throughput: multi-entity document ($BENCH_ENTITIES entities, one YAML document)"
echo
echo "One \`---\` document containing a $BENCH_ENTITIES-entity sequence --"
echo "both tools process every entity; this is an apples-to-apples"
echo "comparison."
echo
if [ "$HAVE_RST" -eq 1 ]; then
  echo "| Mode | besm2-rst (entities) | besm2_fmt (entities) | speedup | besm2-rst RSS | besm2_fmt RSS |"
  echo "|---|---|---|---|---|---|"
else
  echo "| Mode | besm2_fmt (entities) | besm2_fmt RSS |"
  echo "|---|---|---|"
fi
for m in "${MODES[@]}"; do
  mode="${m%%:*}"; flags="${m#*:}"
  IFS=$'\t' read -r fmt_s fmt_rss fmt_count <<< "$(time_one "$BESM2_FMT" "$flags" "$MULTI_ENTITY_FILE")"
  if [ "$HAVE_RST" -eq 1 ]; then
    IFS=$'\t' read -r rst_s rst_rss rst_count <<< "$(time_one "$BESM2_RST" "$flags" "$MULTI_ENTITY_FILE")"
    speedup=$(awk -v r="$rst_s" -v f="$fmt_s" \
      'BEGIN { if (f > 0) printf "%.1fx", r / f; else print "n/a (besm2_fmt too fast to measure at this scale)" }')
    echo "| $mode | ${rst_s} s ($rst_count) | ${fmt_s} s ($fmt_count) | ${speedup} | ${rst_rss} KB | ${fmt_rss} KB |"
  else
    echo "| $mode | ${fmt_s} s ($fmt_count) | ${fmt_rss} KB |"
  fi
done
echo

echo "## Throughput: multi-document file ($BENCH_ENTITIES separate documents, one entity each)"
echo
echo "$BENCH_ENTITIES \`---\`-delimited YAML documents in one file, each a"
echo "one-entity sequence -- besm2-rst's \`yaml-load\` collapses a"
echo "multi-document stream to just the *last* document (a known bug in"
echo "besm2-rst.scm, not a besm2_fmt one -- see PLAN.md's former"
echo "\"Multi-document YAML files aren't handled\" open question), so its"
echo "entity count below is 1 regardless of \$BENCH_ENTITIES, while"
echo "besm2_fmt (via \`Document_Stream\`) processes all of them. This"
echo "section measures each tool's actual behavior on this file shape,"
echo "not an apples-to-apples per-entity comparison -- read the entity"
echo "counts alongside the timings."
echo
if [ "$HAVE_RST" -eq 1 ]; then
  echo "| Mode | besm2-rst (entities) | besm2_fmt (entities) | besm2-rst RSS | besm2_fmt RSS |"
  echo "|---|---|---|---|---|"
else
  echo "| Mode | besm2_fmt (entities) | besm2_fmt RSS |"
  echo "|---|---|---|"
fi
for m in "${MODES[@]}"; do
  mode="${m%%:*}"; flags="${m#*:}"
  IFS=$'\t' read -r fmt_s fmt_rss fmt_count <<< "$(time_one "$BESM2_FMT" "$flags" "$MULTI_DOC_FILE")"
  if [ "$HAVE_RST" -eq 1 ]; then
    IFS=$'\t' read -r rst_s rst_rss rst_count <<< "$(time_one "$BESM2_RST" "$flags" "$MULTI_DOC_FILE")"
    echo "| $mode | ${rst_s} s ($rst_count) | ${fmt_s} s ($fmt_count) | ${rst_rss} KB | ${fmt_rss} KB |"
  else
    echo "| $mode | ${fmt_s} s ($fmt_count) | ${fmt_rss} KB |"
  fi
done

log "done."
