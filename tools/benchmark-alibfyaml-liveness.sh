#!/bin/bash
# tools/benchmark-alibfyaml-liveness.sh - compares two besm2_fmt builds
# that differ ONLY in which alibfyaml commit they're linked against:
# one built before alibfyaml's Node/Document liveness enforcement change,
# one built after. Same measurement shape as tools/benchmark.sh (see its
# own header comment for the full methodology and Linux/GNU-coreutils
# requirements this script shares) but with exactly two fixed variants
# (old/new) instead of the besm2-rst family, since both binaries take
# identical besm2_fmt flags -- no per-variant RST_FLAGS-style table
# needed.
#
# All progress/status/warning messages go to stderr; the Markdown report
# goes to stdout only -- so `tools/benchmark-alibfyaml-liveness.sh > REPORT.md`
# captures a clean report while progress stays visible on the terminal.
#
# Environment variables (BESM2_FMT_OLD/BESM2_FMT_NEW are required; the
# rest match tools/benchmark.sh's defaults exactly, for numbers directly
# comparable to PERFORMANCE-COMPARISON.md):
#   BESM2_FMT_OLD  Path to a besm2_fmt binary built against alibfyaml
#                  BEFORE the liveness-enforcement change. Required.
#   BESM2_FMT_NEW  Path to a besm2_fmt binary built against alibfyaml
#                  AFTER the liveness-enforcement change. Required.
#   BENCH_N        Per-invocation-overhead run count. Default: 200.
#   BENCH_ENTITIES Entity count for the throughput fixtures. Default:
#                  2000.
#   BENCH_SOURCE   The single-entity, single-document YAML fixture used
#                  as the basis for both the per-invocation-overhead
#                  test and the generated throughput fixtures. Must
#                  itself start with a "---" document marker. Default:
#                  test-data/enyon-boase-2e.yaml.
#
# Before timing anything, this script diffs BESM2_FMT_OLD's and
# BESM2_FMT_NEW's output against every test-data/*.yaml fixture, across
# all four output modes -- refuses to produce timing numbers at all if
# they ever disagree, since a speed comparison between two builds that
# don't actually agree on the answer isn't a comparison worth reporting.
#
# Generated throughput fixtures are written under build/ (already
# gitignored) and regenerated fresh on every run.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BENCH_N="${BENCH_N:-200}"
BENCH_ENTITIES="${BENCH_ENTITIES:-2000}"
BENCH_SOURCE="${BENCH_SOURCE:-$ROOT/test-data/enyon-boase-2e.yaml}"
BENCH_DIR="$ROOT/build"

log () { echo "benchmark-alibfyaml-liveness.sh: $*" >&2; }
die () { echo "benchmark-alibfyaml-liveness.sh: error: $*" >&2; exit 1; }

relpath () {
  local abs
  abs="$(realpath -m "$1" 2>/dev/null)" || { echo "$1"; return; }
  case "$abs" in
    "$ROOT"/*) echo "./${abs#"$ROOT"/}" ;;
    "$ROOT") echo "." ;;
    *) echo "$abs" ;;
  esac
}

# ---------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------

[ -n "${BESM2_FMT_OLD:-}" ] || die "BESM2_FMT_OLD must be set (path to a pre-liveness-fix build)"
[ -n "${BESM2_FMT_NEW:-}" ] || die "BESM2_FMT_NEW must be set (path to a post-liveness-fix build)"
[ -x "$BESM2_FMT_OLD" ] || die "BESM2_FMT_OLD is not executable: $BESM2_FMT_OLD"
[ -x "$BESM2_FMT_NEW" ] || die "BESM2_FMT_NEW is not executable: $BESM2_FMT_NEW"

command -v awk >/dev/null || die "awk not found on PATH"
/usr/bin/time -f "%e %M" true >/dev/null 2>/tmp/benchmark_alibfyaml_time_check.$$ \
  || die "GNU time (/usr/bin/time, supporting -f) not found -- required for RSS measurement"
rm -f /tmp/benchmark_alibfyaml_time_check.$$
case "$(date +%s.%N)" in
  [0-9]*.[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) : ;;
  *) die "date +%s.%N doesn't produce sub-second precision -- need GNU date" ;;
esac
[ -f "$BENCH_SOURCE" ] || die "BENCH_SOURCE not found: $BENCH_SOURCE"
head -n 1 "$BENCH_SOURCE" | command grep -q '^---$' \
  || die "BENCH_SOURCE must start with a '---' document marker: $BENCH_SOURCE"

mkdir -p "$BENCH_DIR"

MODES=("grid:-s" "terse:-s -t" "hmm:-s -H" "raw-ms:-s -m")

# ---------------------------------------------------------------
# Correctness gate: refuse to time a mismatch
# ---------------------------------------------------------------

log "checking old/new output agreement across test-data/*.yaml ..."
mismatch=0
for f in "$ROOT"/test-data/*.yaml; do
  for m in "${MODES[@]}"; do
    flags="${m#*:}"
    # shellcheck disable=SC2086
    a="$("$BESM2_FMT_OLD" $flags "$f" 2>&1)"
    # shellcheck disable=SC2086
    b="$("$BESM2_FMT_NEW" $flags "$f" 2>&1)"
    if [ "$a" != "$b" ]; then
      log "MISMATCH: $(basename "$f") [$flags]"
      mismatch=1
    fi
  done
done
[ "$mismatch" -eq 0 ] || die "old/new output disagree -- refusing to report timing for a changed answer"
log "old/new agree byte-for-byte on every test-data fixture and mode."

# ---------------------------------------------------------------
# Fixture generation (identical to tools/benchmark.sh's own)
# ---------------------------------------------------------------

gen_multi_entity () {
  local n="$1" out="$2" body
  body="$(mktemp)"
  tail -n +2 "$BENCH_SOURCE" > "$body"
  { echo "---"; for ((i = 0; i < n; i++)); do cat "$body"; done; } > "$out"
  rm -f "$body"
}

gen_multi_doc () {
  local n="$1" out="$2"
  : > "$out"
  for ((i = 0; i < n; i++)); do cat "$BENCH_SOURCE" >> "$out"; done
}

MULTI_ENTITY_FILE="$BENCH_DIR/bench-alibfyaml-multi-entity-$BENCH_ENTITIES.yaml"
MULTI_DOC_FILE="$BENCH_DIR/bench-alibfyaml-multi-doc-$BENCH_ENTITIES.yaml"

log "generating $BENCH_ENTITIES-entity fixtures into $BENCH_DIR ..."
gen_multi_entity "$BENCH_ENTITIES" "$MULTI_ENTITY_FILE"
gen_multi_doc "$BENCH_ENTITIES" "$MULTI_DOC_FILE"

ENTITY_NAME="$(sed -n 's/^- name: *//p' "$BENCH_SOURCE" | head -n 1)"
[ -n "$ENTITY_NAME" ] || die "couldn't extract the entity name from $BENCH_SOURCE"

# ---------------------------------------------------------------
# Timing helpers (identical to tools/benchmark.sh's own)
# ---------------------------------------------------------------

time_n () {
  local prog="$1" flags="$2" file="$3" start end
  # shellcheck disable=SC2086
  "$prog" $flags "$file" >/dev/null
  start=$(date +%s.%N)
  for ((i = 0; i < BENCH_N; i++)); do
    # shellcheck disable=SC2086
    "$prog" $flags "$file" >/dev/null
  done
  end=$(date +%s.%N)
  awk -v s="$start" -v e="$end" -v n="$BENCH_N" \
    'BEGIN { printf "%.3f", (e - s) * 1000 / n }'
}

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
# Table-printing helpers
# ---------------------------------------------------------------

CODES=(old new)
declare -A BIN
BIN[old]="$BESM2_FMT_OLD"
BIN[new]="$BESM2_FMT_NEW"

print_grid () {
  local title="$1"
  local -n vals="$2"
  local header="| Build |" sep="|---|" m mode code row
  for m in "${MODES[@]}"; do mode="${m%%:*}"; header+=" $mode |"; sep+="---|"; done
  echo "$title"
  echo
  echo "$header"
  echo "$sep"
  for code in "${CODES[@]}"; do
    row="| $code |"
    for m in "${MODES[@]}"; do
      mode="${m%%:*}"
      row+=" ${vals[$code:$mode]:-} |"
    done
    echo "$row"
  done
  echo
}

# One row: new/old ratio per mode (>1.0 means new is slower).
print_overhead_row () {
  local title="$1"
  local -n raw="$2"
  local header="| |" sep="|---|" m mode row v
  for m in "${MODES[@]}"; do mode="${m%%:*}"; header+=" $mode |"; sep+="---|"; done
  echo "$title"
  echo
  echo "$header"
  echo "$sep"
  row="| new/old |"
  for m in "${MODES[@]}"; do
    mode="${m%%:*}"
    v=$(awk -v o="${raw[old:$mode]}" -v n="${raw[new:$mode]}" \
      'BEGIN { if (o > 0) printf "%+.1f%%", (n - o) * 100.0 / o; else print "n/a" }')
    row+=" $v |"
  done
  echo "$row"
  echo
}

# ---------------------------------------------------------------
# Report
# ---------------------------------------------------------------

CPU_MODEL="$(command grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ *//')"
NPROC="$(nproc 2>/dev/null || echo '?')"
KERNEL="$(uname -srm)"

echo "# besm2_fmt: alibfyaml Node/Document liveness enforcement -- performance impact"
echo
echo "Generated: $(date -u +'%Y-%m-%d %H:%M:%S UTC') by \`tools/benchmark-alibfyaml-liveness.sh\`."
echo
echo "- Machine: ${CPU_MODEL:-unknown CPU}, $NPROC threads, $KERNEL"
echo "- \`BENCH_N\`=$BENCH_N, \`BENCH_ENTITIES\`=$BENCH_ENTITIES, \`BENCH_SOURCE\`=$(relpath "$BENCH_SOURCE")"
echo "- \`old\`: besm2_fmt linked against alibfyaml BEFORE the liveness-enforcement change: \`$(relpath "$BESM2_FMT_OLD")\`"
echo "- \`new\`: besm2_fmt linked against alibfyaml AFTER the liveness-enforcement change: \`$(relpath "$BESM2_FMT_NEW")\`"
echo
echo "Both builds confirmed to produce byte-identical output on every"
echo "\`test-data/*.yaml\` fixture, across all four output modes, before"
echo "any timing below was taken."
echo

declare -A TIME_MS SECS_ENTITY RSS_ENTITY COUNT_ENTITY SECS_DOC RSS_DOC COUNT_DOC

echo "## Per-invocation overhead (N=$BENCH_N runs, \`$(basename "$BENCH_SOURCE")\`)"
echo
for code in "${CODES[@]}"; do
  for m in "${MODES[@]}"; do
    mode="${m%%:*}"; flags="${m#*:}"
    TIME_MS["$code:$mode"]="$(time_n "${BIN[$code]}" "$flags" "$BENCH_SOURCE") ms"
  done
done
print_grid "Mean time per invocation" TIME_MS
declare -A TIME_MS_RAW
for k in "${!TIME_MS[@]}"; do TIME_MS_RAW[$k]="${TIME_MS[$k]% ms}"; done
print_overhead_row "new vs. old (positive = new is slower)" TIME_MS_RAW

echo "## Throughput: multi-entity document ($BENCH_ENTITIES entities, one YAML document)"
echo
echo "One \`---\` document containing a $BENCH_ENTITIES-entity sequence --"
echo "stresses Node creation/navigation (Value/Iterate, each a Wrap call)"
echo "within a SINGLE Document."
echo
for code in "${CODES[@]}"; do
  for m in "${MODES[@]}"; do
    mode="${m%%:*}"; flags="${m#*:}"
    IFS=$'\t' read -r s rss count <<< \
      "$(time_one "${BIN[$code]}" "$flags" "$MULTI_ENTITY_FILE")"
    SECS_ENTITY["$code:$mode"]="$s s"
    RSS_ENTITY["$code:$mode"]="$rss KB"
    COUNT_ENTITY["$code:$mode"]="$count"
  done
done
print_grid "Time" SECS_ENTITY
declare -A SECS_ENTITY_RAW
for k in "${!SECS_ENTITY[@]}"; do SECS_ENTITY_RAW[$k]="${SECS_ENTITY[$k]% s}"; done
print_overhead_row "new vs. old (positive = new is slower)" SECS_ENTITY_RAW
print_grid "Entities processed (sanity check -- should read $BENCH_ENTITIES everywhere)" COUNT_ENTITY
print_grid "Peak RSS" RSS_ENTITY

echo "## Throughput: multi-document file ($BENCH_ENTITIES separate documents, one entity each)"
echo
echo "$BENCH_ENTITIES \`---\`-delimited YAML documents in one file, each a"
echo "one-entity sequence, read via \`Document_Stream\` -- stresses Document"
echo "creation/destruction (one Owner_Liveness alloc + Mark_Dead per"
echo "document in the \`new\` build) instead of Node navigation volume."
echo
for code in "${CODES[@]}"; do
  for m in "${MODES[@]}"; do
    mode="${m%%:*}"; flags="${m#*:}"
    IFS=$'\t' read -r s rss count <<< \
      "$(time_one "${BIN[$code]}" "$flags" "$MULTI_DOC_FILE")"
    SECS_DOC["$code:$mode"]="$s s"
    RSS_DOC["$code:$mode"]="$rss KB"
    COUNT_DOC["$code:$mode"]="$count"
  done
done
print_grid "Time" SECS_DOC
declare -A SECS_DOC_RAW
for k in "${!SECS_DOC[@]}"; do SECS_DOC_RAW[$k]="${SECS_DOC[$k]% s}"; done
print_overhead_row "new vs. old (positive = new is slower)" SECS_DOC_RAW
print_grid "Entities processed" COUNT_DOC
print_grid "Peak RSS" RSS_DOC

log "done."
