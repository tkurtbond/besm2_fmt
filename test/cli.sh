#!/usr/bin/env bash
# Command-line handling of besm2_fmt: exit statuses, and a line of the
# output or error each case must contain.  Run from the repo root, as
# test/cli.sh [program]; prints ok/FAIL per case and exits 1 if any
# failed.  Adapted from the Oberon-2 port's test/cli.sh.
#
# Statuses: help 1, command-line mistakes 2, an output file that can't
# be created or written 1, bad input files 0 (reported, and the run
# goes on with the next file).

prog=${1:-./besm2_fmt}
data=test/data
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failed=0

fail() {
  local file
  echo "FAIL - $1"; shift
  for file in "$@"; do sed "s/^/    $(basename "$file"): /" "$file"; done
  failed=$((failed + 1))
}

# check LABEL STATUS PATTERN [ARGS...]: run prog ARGS with stdin from
# /dev/null, stdout and stderr together; require exit STATUS and a line
# matching the grep -E PATTERN (skipped if PATTERN is empty).
check() {
  local label=$1 want=$2 pattern=$3; shift 3
  "$prog" "$@" </dev/null >"$tmp/out" 2>&1
  local got=$?
  if [ "$got" -ne "$want" ]; then
    fail "$label: exit $got, not $want" "$tmp/out"
  elif [ -n "$pattern" ] && ! grep -qE -- "$pattern" "$tmp/out"; then
    fail "$label: no line matching /$pattern/" "$tmp/out"
  else
    echo "ok   - $label"
  fi
}

# check_err LABEL STATUS PATTERN [ARGS...]: as check, but PATTERN must
# be in standard error (or, if PATTERN is empty, standard error must be
# empty), and standard output must be empty.
check_err() {
  local label=$1 want=$2 pattern=$3; shift 3
  "$prog" "$@" </dev/null >"$tmp/out" 2>"$tmp/err"
  local got=$?
  if [ "$got" -ne "$want" ]; then
    fail "$label: exit $got, not $want" "$tmp/out" "$tmp/err"
  elif [ -z "$pattern" ] && [ -s "$tmp/err" ]; then
    fail "$label: something went to standard error" "$tmp/err"
  elif [ -n "$pattern" ] && ! grep -qE -- "$pattern" "$tmp/err"; then
    fail "$label: no line matching /$pattern/ in standard error" "$tmp/err"
  elif [ -s "$tmp/out" ]; then
    fail "$label: something went to standard output" "$tmp/out"
  else
    echo "ok   - $label"
  fi
}

f=$data/enyon-boase-2e.yaml

# ---- options ----
check "-h shows the usage and exits 1" 1 '^-w ARG, --width=ARG +Width of table' -h
check "--help after a file still exits 1" 1 '^besm2_fmt \[options\] \[files\.\.\.\]$' "$f" --help
check_err "an unknown long option exits 2" 2 '^Unknown option --bogus$' --bogus "$f"
check_err "an unknown short option exits 2" 2 '^Unknown option -x$' -x "$f"
check_err "a missing option argument exits 2" 2 '^Argument Required for option -u$' -u
check_err "-u with two characters exits 2, processing nothing" 2 \
  '^Invalid value for option -u/--underliner: must be exactly one character, got "xx"$' -u xx "$f"
check_err "-U with two characters exits 2" 2 \
  'subunderliner: must be exactly one character, got "ab"$' -U ab "$f"
check_err "-u with an empty argument exits 2" 2 'got ""$' -u "" "$f"
check "-u= sets the underliner to =" 0 '^=+$' -u= "$f"
check_err "-w that isn't a number exits 2" 2 \
  '^Invalid value for option -w: "abc" is not an integer$' -w abc "$f"
check_err "-w 0 exits 2, processing nothing" 2 \
  '^Invalid value for option -w: "0" is not in range 25\.\.' -w 0 "$f"
check_err "-w 24 is too narrow and exits 2" 2 \
  '^Invalid value for option -w: "24" is not in range 25\.\.' -w 24 "$f"
check "-w 25 is accepted" 0 '' -w 25 "$f"
check "--width=72 is accepted" 0 '' --width=72 "$f"
check_err "-w -5 is a value, out of range" 2 \
  '^Invalid value for option -w: "-5" is not in range 25\.\.' -w -5 "$f"
check_err "--width -5 is a value, out of range" 2 \
  '^Invalid value for option --width: "-5" is not in range 25\.\.' --width -5 "$f"
check_err "-L -1 exits 2" 2 '^Invalid value for option -L: "-1" is not in range 0\.\.' -L -1 "$f"
check_err "-L that isn't a number exits 2" 2 '^Invalid value for option -L: "x" is not an integer$' -L x "$f"

# ---- files ----
check_err "-o to a directory that doesn't exist exits 1 with the OS reason" 1 \
  '^besm2_fmt: can.t create /nonexistent/dir/out: No such file or directory$' -o /nonexistent/dir/out "$f"
"$prog" "$f" nosuch.yaml "$f" </dev/null >"$tmp/out" 2>"$tmp/err"
status=$?
if [ $status -eq 0 ] && [ "$(cat "$tmp/err")" = "besm2_fmt: nosuch.yaml: No such file or directory" ] \
   && [ "$(grep -c '^Lieutenant Enyon Boase$' "$tmp/out")" -eq 2 ]; then
  echo "ok   - a missing file is reported with the OS reason and the run goes on, exit 0"
else
  fail "a missing file is reported with the OS reason and the run goes on, exit 0" "$tmp/err"
fi
check_err "a directory is reported, not taken for an empty file" 0 \
  '^besm2_fmt: test/data: Is a directory$' test/data
check_err "-- ends the options" 0 '^besm2_fmt: -t: No such file or directory$' -- -t

# ---- bad input ----
# A bad entity is reported, writes nothing, and ends its file; entities
# before it are written, and the run goes on with the next file.
printf -- '- name: Good\n- name: Bad\n  stats: [{name: B}]\n- name: Never\n' >"$tmp/bad.yaml"
"$prog" "$tmp/bad.yaml" "$data/composite-multi-doc-2e.yaml" >"$tmp/out" 2>&1
status=$?
if [ $status -eq 0 ] && grep -q 'Good' "$tmp/out" && ! grep -q 'Bad\|Never' "$tmp/out" \
   && grep -q 'error processing .*bad.yaml: missing required key "value"$' "$tmp/out" \
   && grep -q 'Coleopteran' "$tmp/out"; then
  echo "ok   - a bad entity ends its file, not the run, with status 0"
else
  fail "a bad entity ends its file, not the run, with status 0" "$tmp/out"
fi
printf -- '- 5\n' >"$tmp/shape.yaml"
check "an entity that isn't a mapping is an input error, not a halt" 0 \
  'error processing .*shape\.yaml: /0: not a mapping$' "$tmp/shape.yaml"
check "a customizer of one item is an input error, not a halt" 0 \
  'error processing .*shape-customizer-short\.yaml: /1/attributes/0/enhancements/0: customizer sequence too short$' \
  "$data/shape-customizer-short.yaml"
check "stats: with no value is an input error, not a halt" 0 \
  'error processing .*shape-null-stats\.yaml: /1/stats: not a sequence$' "$data/shape-null-stats.yaml"
printf -- '- {name: X, attributes: [{name: A, level: 1, points: 1, enhancements: Area}]}\n' >"$tmp/shape.yaml"
check "enhancements that aren't a sequence are an input error" 0 \
  '/0/attributes/0/enhancements: not a sequence$' "$tmp/shape.yaml"
printf -- '- {name: X, attributes: [{name: A, level: 1, points: 1, limiters: [[R, 1, [a]]]}]}\n' >"$tmp/shape.yaml"
check "an applies-to that isn't a scalar is an input error" 0 \
  '/0/attributes/0/limiters/0/2: not a scalar$' "$tmp/shape.yaml"
printf -- '- {name: X, skills: [Law]}\n' >"$tmp/shape.yaml"
check "a list item that isn't a mapping is an input error" 0 \
  '/0/skills/0: not a mapping$' "$tmp/shape.yaml"
printf -- '- 5\n' >"$tmp/shape.yaml"
"$prog" "$tmp/shape.yaml" "$f" >"$tmp/out" 2>/dev/null
if grep -q '^Lieutenant Enyon Boase$' "$tmp/out"; then
  echo "ok   - the file after one of the wrong shape is still processed"
else
  fail "the file after one of the wrong shape is still processed" "$tmp/out"
fi
check "YAML that doesn't parse is reported gcc style" 0 \
  '^besm2_fmt: error processing .*bad-yaml\.yaml: .*bad-yaml\.yaml:6:1: error: missing comma in flow mapping$' \
  "$data/bad-yaml.yaml"
check "a bad integer is reported" 0 \
  '^besm2_fmt: error processing .*bad-int\.yaml: not a valid integer: "lots"$' "$data/bad-int.yaml"
check "a missing key is reported" 0 \
  '^besm2_fmt: error processing .*bad-missing-key\.yaml: missing required key "points"$' "$data/bad-missing-key.yaml"
check "a bad customizer is reported with its path" 0 \
  'error processing .*bad-customizer-map\.yaml: /1/attributes/0/limiters/0: do not understand customizer$' \
  "$data/bad-customizer-map.yaml"
check_err "a file with no documents is not an error, and writes nothing" 0 '' "$data/edge-empty.yaml"
check "an empty document is an error" 0 \
  'expected a top-level YAML sequence of entities in .*bad-empty-doc\.yaml$' "$data/bad-empty-doc.yaml"
printf -- 'a: 1\n' >"$tmp/map.yaml"
check "a top level that isn't a sequence is reported" 0 \
  'expected a top-level YAML sequence of entities in .*map\.yaml$' "$tmp/map.yaml"

# ---- output errors ----
check_err "-o to /dev/full exits 1 with the OS reason" 1 \
  '^besm2_fmt: error writing output: No space left on device$' -o /dev/full "$f"
"$prog" "$f" >/dev/full 2>"$tmp/err"
if [ $? -eq 1 ] && grep -q '^besm2_fmt: error writing output: No space left on device$' "$tmp/err"; then
  echo "ok   - a full standard output exits 1 with the OS reason"
else
  fail "a full standard output exits 1 with the OS reason" "$tmp/err"
fi

# ---- standard input ----
printf -- '- [a\n' | "$prog" >/dev/null 2>"$tmp/err"
if grep -q '^besm2_fmt: error processing (stdin): (stdin):2:1: error: flow sequence without a closing bracket$' "$tmp/err"; then
  echo "ok   - YAML errors in standard input name it (stdin)"
else
  fail "YAML errors in standard input name it (stdin)" "$tmp/err"
fi
if "$prog" <"$f" | cmp -s - <("$prog" "$f"); then
  echo "ok   - no file names reads standard input"
else
  fail "no file names reads standard input"
fi

# -R/--hmm-root goes to standard output even under -o, as in
# besm2-rst.scm; everything else goes to the file.
"$prog" -H -R Root -L 2 -o "$tmp/file" "$f" >"$tmp/stdout" 2>&1
if [ "$(cat "$tmp/stdout")" = "$(printf '\t\tRoot')" ] && [ -s "$tmp/file" ] \
   && ! grep -q Root "$tmp/file"; then
  echo "ok   - -R goes to standard output under -o, the rest to the file"
else
  fail "-R goes to standard output under -o, the rest to the file" "$tmp/stdout"
fi

if [ "$failed" -eq 0 ]; then echo "All checks passed."; else echo "$failed check(s) failed."; exit 1; fi
