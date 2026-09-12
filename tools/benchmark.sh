#!/bin/bash
# tools/benchmark.sh - reproduces PERFORMANCE-COMPARISON.md's
# besm2_fmt-vs-besm2-rst-family performance numbers.
#
# All progress/status/warning messages go to stderr; the Markdown
# report goes to stdout only -- so `tools/benchmark.sh > PERFORMANCE-COMPARISON.md`
# (or `make benchmark > PERFORMANCE-COMPARISON.md`) captures a clean report while
# progress stays visible on the terminal.
#
# Requires (Linux/GNU-coreutils specific, not portable to macOS/BSD):
#   - GNU time (/usr/bin/time, for the `-f "%e %M"` format -- bash's
#     builtin `time` and BSD/macOS `time` don't support this)
#   - GNU date (for `date +%s.%N` sub-second precision)
#   - GNU realpath (for the report header's `-m`/`--relative-to`-style
#     path display)
#   - gprbuild, awk (standard on this project's dev machine already)
#   - bash 4.3+ (associative arrays and `local -n` namerefs)
#
# The report header shows `besm2_fmt`/`BENCH_SOURCE` as a repo-relative
# path (e.g. `./besm2_fmt`, `./test-data/enyon-boase-2e.yaml`) when
# they resolve to something inside this checkout -- true by default,
# since besm2_fmt and test-data/ are both built/shipped as part of
# this repo -- and falls back to the absolute path otherwise (an
# env-var override pointing elsewhere). Every besm2-rst-family binary
# is always shown as an absolute path, since none of them are part of
# this repo.
#
# Environment variables (all optional):
#   BESM2_FMT      Path to the besm2_fmt binary. Default: ./besm2_fmt
#                  relative to the repo root, built via `gprbuild` if
#                  missing.
#   BESM2_RST      Path to a besm2-rst binary (from besm-tools) to
#                  compare against -- also the basis for the "fyaml"
#                  variant (besm2-rst -f/--fyaml is the same binary,
#                  no separate path needed). If unset, falls back to
#                  `PATH` -- but that fallback is NOT trusted silently:
#                  it warns loudly on stderr and the resolved path is
#                  printed in the report header, since a PATH-installed
#                  besm2-rst can easily be stale (built before a fix
#                  landed in besm-tools). If no besm2-rst can be found
#                  at all, both the "yaml" and "fyaml" variants are
#                  skipped (see below).
#   BESM2_RST_F    Path to a besm2-rst-f binary (besm2-rst refactored
#                  onto slibfyaml's handle/tree API directly -- the
#                  "tree" variant). No PATH fallback: unset means
#                  skipped, silently other than a note on stderr.
#   BESM2_RST_E    Path to a besm2-rst-e binary (besm2-rst refactored
#                  onto besm-entities' shared record -- the "entity"
#                  variant). Same unset-means-skipped behavior.
#   BESM2_RST_FE   Path to a besm2-rst-f-e binary (besm2-rst-f
#                  refactored the same way -- the "etree" variant).
#                  Same unset-means-skipped behavior.
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
# Every besm2-rst-family variant is independently optional -- set
# however many of BESM2_RST/BESM2_RST_F/BESM2_RST_E/BESM2_RST_FE you
# have built, and the report adapts to however many are available,
# down to zero (besm2_fmt-only mode, no comparison columns). Tables
# are laid out with one row per program and one column per output
# mode, precisely so that adding another variant (as this script's
# BESM2_RST_F/E/FE did) only adds a row -- the tables never get wider.
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

# Prints $1 relative to $ROOT (as "./..." ) when it names something
# inside this repo -- e.g. the default $ROOT/besm2_fmt or
# $ROOT/test-data/... -- so the report doesn't hard-code this
# checkout's absolute path for things the repo itself builds/ships.
# Anything outside $ROOT (an env-var override pointing elsewhere, or
# any besm2-rst-family binary, which are always external) prints as
# the absolute path it resolves to.
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

# ---------------------------------------------------------------
# besm2-rst variant resolution
# ---------------------------------------------------------------
# Each code below is one program invocation benchmarked against
# besm2_fmt, matching the codes used in besm-tools' own extended
# benchmark (BESM/Tools/RPG's benchmark-fyaml.rst): "yaml"/"fyaml" are
# one binary (besm2-rst) with/without -f/--fyaml; "tree"/"entity"/
# "etree" are three separate binaries (besm2-rst-f/besm2-rst-e/
# besm2-rst-f-e). Any not set/executable are skipped -- see the header
# comment above for exactly which env var controls which.

declare -A RST_BIN RST_FLAGS RST_LABEL
RST_ORDER=()

if [ -z "${BESM2_RST:-}" ]; then
  if command -v besm2-rst >/dev/null 2>&1; then
    BESM2_RST="$(command -v besm2-rst)"
    log "WARNING: BESM2_RST not set, falling back to PATH: $BESM2_RST"
    log "WARNING: this may be a stale build -- set BESM2_RST explicitly to a" \
        "freshly-built besm2-rst to be sure the comparison is current."
  else
    log "note: no besm2-rst found (set BESM2_RST) -- 'yaml'/'fyaml' variants" \
        "skipped"
    BESM2_RST=""
  fi
elif [ ! -x "$BESM2_RST" ]; then
  die "BESM2_RST is set but not executable: $BESM2_RST"
fi

if [ -n "$BESM2_RST" ]; then
  RST_ORDER+=(yaml fyaml)
  RST_BIN[yaml]="$BESM2_RST";   RST_FLAGS[yaml]="";   RST_LABEL[yaml]="besm2-rst"
  RST_BIN[fyaml]="$BESM2_RST";  RST_FLAGS[fyaml]="-f"; RST_LABEL[fyaml]="besm2-rst -f/--fyaml"
fi

# Adds one single-binary variant (code, its env var's name, and the
# label to show in the report) if that env var is set -- unset means
# silently skipped (a one-line note on stderr), since none of these
# have a PATH-install convention worth trusting the way besm2-rst's
# does above.
add_variant () {
  local code="$1" var="$2" label="$3" path
  path="${!var:-}"
  if [ -z "$path" ]; then
    log "note: $var not set -- '$code' variant skipped"
    return
  fi
  [ -x "$path" ] || die "$var is set but not executable: $path"
  RST_ORDER+=("$code")
  RST_BIN[$code]="$path"; RST_FLAGS[$code]=""; RST_LABEL[$code]="$label"
}
add_variant tree   BESM2_RST_F  "besm2-rst-f"
add_variant entity BESM2_RST_E  "besm2-rst-e"
add_variant etree  BESM2_RST_FE "besm2-rst-f-e"

RST_BIN[besm2_fmt]="$BESM2_FMT"; RST_FLAGS[besm2_fmt]=""; RST_LABEL[besm2_fmt]="besm2_fmt"
ALL_CODES=("${RST_ORDER[@]}" besm2_fmt)

mkdir -p "$BENCH_DIR"

# ---------------------------------------------------------------
# Fixture generation
# ---------------------------------------------------------------

# One YAML document containing a BENCH_ENTITIES-entity sequence --
# strips every "---" marker but the first before repeating the body,
# so this is genuinely one document, not BENCH_ENTITIES of them (see
# the header comment/PERFORMANCE-COMPARISON.md for why that distinction matters).
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
# Table-printing helpers
# ---------------------------------------------------------------
# Every table below has one row per program (a code in $1, e.g.
# "${ALL_CODES[*]}" or "${RST_ORDER[*]}") and one column per output
# mode -- see the header comment for why (adding a variant only adds a
# row). $2 is an associative array (by name, via nameref) of
# "code:mode" -> already-formatted cell text.

print_grid () {
  local title="$1" codes="$2"
  local -n vals="$3"
  local header="| Program |" sep="|---|" m mode code row
  for m in "${MODES[@]}"; do mode="${m%%:*}"; header+=" $mode |"; sep+="---|"; done
  echo "$title"
  echo
  echo "$header"
  echo "$sep"
  for code in $codes; do
    row="| ${RST_LABEL[$code]} |"
    for m in "${MODES[@]}"; do
      mode="${m%%:*}"
      row+=" ${vals[$code:$mode]:-} |"
    done
    echo "$row"
  done
  echo
}

# Same shape, but each cell is besm2_fmt's speedup over that row's
# program (raw_vals[code:mode] / raw_vals[besm2_fmt:mode]) -- only
# meaningful for the besm2-rst-family rows, so $2 should be
# "${RST_ORDER[*]}", never including besm2_fmt itself.
print_speedup_grid () {
  local title="$1" codes="$2"
  local -n raw="$3"
  local header="| Program |" sep="|---|" m mode code row s
  for m in "${MODES[@]}"; do mode="${m%%:*}"; header+=" $mode |"; sep+="---|"; done
  echo "$title"
  echo
  echo "$header"
  echo "$sep"
  for code in $codes; do
    row="| ${RST_LABEL[$code]} |"
    for m in "${MODES[@]}"; do
      mode="${m%%:*}"
      s=$(awk -v r="${raw[$code:$mode]}" -v f="${raw[besm2_fmt:$mode]}" \
        'BEGIN { if (f > 0) printf "%.1fx", r / f; else print "n/a (besm2_fmt too fast to measure)" }')
      row+=" $s |"
    done
    echo "$row"
  done
  echo
}

# ---------------------------------------------------------------
# Report
# ---------------------------------------------------------------

CPU_MODEL="$(command grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ *//')"
NPROC="$(nproc 2>/dev/null || echo '?')"
KERNEL="$(uname -srm)"

echo "# besm2_fmt vs besm2-rst-family benchmark"
echo
echo "Generated: $(date -u +'%Y-%m-%d %H:%M:%S UTC') by \`tools/benchmark.sh\`."
echo
echo "- Machine: ${CPU_MODEL:-unknown CPU}, $NPROC threads, $KERNEL"
echo "- \`BENCH_N\`=$BENCH_N, \`BENCH_ENTITIES\`=$BENCH_ENTITIES, \`BENCH_SOURCE\`=$(relpath "$BENCH_SOURCE")"
echo
echo "Programs compared below:"
echo
for code in "${ALL_CODES[@]}"; do
  case "$code" in
    yaml)      echo "- \`yaml\`: \`besm2-rst\` (default, yaml egg): \`$BESM2_RST\`" ;;
    fyaml)     echo "- \`fyaml\`: \`besm2-rst -f\`/\`--fyaml\` (slibfyaml egg, eager decode): \`$BESM2_RST\`" ;;
    tree)      echo "- \`tree\`: \`besm2-rst-f\` (slibfyaml handle/tree API): \`${RST_BIN[tree]}\`" ;;
    entity)    echo "- \`entity\`: \`besm2-rst-e\` (yaml egg, shared entity record): \`${RST_BIN[entity]}\`" ;;
    etree)     echo "- \`etree\`: \`besm2-rst-f-e\` (handle/tree, shared entity record): \`${RST_BIN[etree]}\`" ;;
    besm2_fmt) echo "- \`besm2_fmt\`: this project: \`$(relpath "$BESM2_FMT")\`" ;;
  esac
done
if [ "${#RST_ORDER[@]}" -eq 0 ]; then
  echo
  echo "No besm2-rst-family binary was found -- besm2_fmt-only report, no comparison."
fi
echo

declare -A TIME_MS SECS_ENTITY RSS_ENTITY COUNT_ENTITY SECS_DOC RSS_DOC COUNT_DOC

echo "## Per-invocation overhead (N=$BENCH_N runs, \`$(basename "$BENCH_SOURCE")\`)"
echo
for code in "${ALL_CODES[@]}"; do
  for m in "${MODES[@]}"; do
    mode="${m%%:*}"; flags="${m#*:}"
    TIME_MS["$code:$mode"]="$(time_n "${RST_BIN[$code]}" "$flags ${RST_FLAGS[$code]}" "$BENCH_SOURCE") ms"
  done
done
print_grid "Mean time per invocation" "${ALL_CODES[*]}" TIME_MS
if [ "${#RST_ORDER[@]}" -gt 0 ]; then
  print_speedup_grid "besm2_fmt's speedup over each" "${RST_ORDER[*]}" TIME_MS
fi

echo "## Throughput: multi-entity document ($BENCH_ENTITIES entities, one YAML document)"
echo
echo "One \`---\` document containing a $BENCH_ENTITIES-entity sequence --"
echo "every program processes every entity; this is an apples-to-apples"
echo "comparison."
echo
for code in "${ALL_CODES[@]}"; do
  for m in "${MODES[@]}"; do
    mode="${m%%:*}"; flags="${m#*:}"
    IFS=$'\t' read -r s rss count <<< \
      "$(time_one "${RST_BIN[$code]}" "$flags ${RST_FLAGS[$code]}" "$MULTI_ENTITY_FILE")"
    SECS_ENTITY["$code:$mode"]="$s s"
    RSS_ENTITY["$code:$mode"]="$rss KB"
    COUNT_ENTITY["$code:$mode"]="$count"
  done
done
print_grid "Time" "${ALL_CODES[*]}" SECS_ENTITY
print_grid "Entities processed (sanity check -- should read $BENCH_ENTITIES everywhere)" \
  "${ALL_CODES[*]}" COUNT_ENTITY
print_grid "Peak RSS" "${ALL_CODES[*]}" RSS_ENTITY
if [ "${#RST_ORDER[@]}" -gt 0 ]; then
  declare -A SECS_ENTITY_RAW
  for k in "${!SECS_ENTITY[@]}"; do SECS_ENTITY_RAW[$k]="${SECS_ENTITY[$k]% s}"; done
  print_speedup_grid "besm2_fmt's speedup over each" "${RST_ORDER[*]}" SECS_ENTITY_RAW
fi

echo "## Throughput: multi-document file ($BENCH_ENTITIES separate documents, one entity each)"
echo
echo "$BENCH_ENTITIES \`---\`-delimited YAML documents in one file, each a"
echo "one-entity sequence. besm2_fmt (via \`Document_Stream\`) processes"
echo "all of them; every besm2-rst-family variant reads only 1 entity"
echo "below regardless of \$BENCH_ENTITIES -- documented for \`yaml\`/"
echo "\`fyaml\` as a \`yaml-load\`/\`(slibfyaml scheme)\` bug in besm2-rst.scm"
echo "(not a besm2_fmt one -- see PLAN.md's former \"Multi-document YAML"
echo "files aren't handled\" open question) that collapses a"
echo "multi-document stream to a single document; \`tree\`/\`entity\`/"
echo "\`etree\` measure the same way here, though besm2-rst-f/-e/-f-e"
echo "never claimed streaming support in the first place, so this isn't"
echo "necessarily the identical root cause, just the identical observed"
echo "behavior on this file shape. This section measures each program's"
echo "actual behavior here, not an apples-to-apples per-entity"
echo "comparison -- read the entity counts alongside the timings."
echo
for code in "${ALL_CODES[@]}"; do
  for m in "${MODES[@]}"; do
    mode="${m%%:*}"; flags="${m#*:}"
    IFS=$'\t' read -r s rss count <<< \
      "$(time_one "${RST_BIN[$code]}" "$flags ${RST_FLAGS[$code]}" "$MULTI_DOC_FILE")"
    SECS_DOC["$code:$mode"]="$s s"
    RSS_DOC["$code:$mode"]="$rss KB"
    COUNT_DOC["$code:$mode"]="$count"
  done
done
print_grid "Time" "${ALL_CODES[*]}" SECS_DOC
print_grid "Entities processed" "${ALL_CODES[*]}" COUNT_DOC
print_grid "Peak RSS" "${ALL_CODES[*]}" RSS_DOC

log "done."
