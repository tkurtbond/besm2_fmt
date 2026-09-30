#!/usr/bin/env bash
# Golden-output tests.  Run from the repo root.
#
#   test/golden.sh check [PROGRAM]      compare PROGRAM's output (default
#                                       ./besm2_fmt) with test/golden/
#   test/golden.sh generate [PROGRAM]   write the golden files that are
#                                       missing, from PROGRAM's output
#   test/golden.sh regenerate [PROGRAM] rewrite every golden file
#
# The cases are in test/golden.cases.  Never edit a golden file by
# hand: after a deliberate change to the output, regenerate and review
# the change with git diff.
#
# check prints ok/FAIL per case, with a diff for a failure, and exits 1
# if any failed.

set -u
mode=${1:-check}
prog=${2:-./besm2_fmt}
cases=test/golden.cases
golden=test/golden
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failed=0 count=0

case $mode in
  check|generate|regenerate) ;;
  *) echo "usage: test/golden.sh check|generate|regenerate [PROGRAM]" >&2; exit 2 ;;
esac
mkdir -p "$golden"

# run OUT FILES...: run $prog as case $modes says, with $flags, writing
# what is compared to OUT; return its exit status.
run() {
  local o=$1 st; shift
  local in=/dev/null
  if [[ $modes == *:stdin:* ]]; then in=$1; set --; fi
  if [[ $modes == *:file:* ]]; then
    rm -f "$tmp/o"
    # $flags is split into words on purpose.
    # shellcheck disable=SC2086
    "$prog" $flags -o "$tmp/o" "$@" >"$o" 2>&1 <"$in"; st=$?
    { echo "==== -o file ===="; cat "$tmp/o" 2>/dev/null; } >>"$o"
  elif [[ $modes == *:stdout:* ]]; then
    # shellcheck disable=SC2086
    "$prog" $flags "$@" >"$o" 2>/dev/null <"$in"; st=$?
  else
    # shellcheck disable=SC2086
    "$prog" $flags "$@" >"$o" 2>&1 <"$in"; st=$?
  fi
  return $st
}

# compare LABEL: report ok or FAIL for $tmp/out (exit $status) against
# $out.
compare() {
  local label=$1
  if [ ! -e "$out" ]; then
    echo "FAIL - $label: no golden file (test/golden.sh generate)"; failed=$((failed + 1))
  elif [ $status -ne 0 ]; then
    echo "FAIL - $label ($flags): exit $status"; failed=$((failed + 1))
  elif ! cmp -s "$out" "$tmp/out"; then
    echo "FAIL - $label ($flags)"; diff "$out" "$tmp/out" | head -20 | sed 's/^/    /'
    failed=$((failed + 1))
  else
    echo "ok   - $label ($flags)"
  fi
}

shopt -s extglob
while read -r modelist id pattern flags; do
  case $modelist in ''|'#'*) continue ;; esac
  modes=:$modelist:
  # $pattern is a glob on purpose.
  # shellcheck disable=SC2206
  fixtures=(test/data/$pattern.yaml)
  [ -e "${fixtures[0]}" ] || { echo "golden.sh: no fixture matches $pattern" >&2; exit 2; }
  if [[ $modes == *:all:* ]]; then
    groups=("${fixtures[*]}")
  else
    groups=("${fixtures[@]}")
  fi
  for g in "${groups[@]}"; do
    # shellcheck disable=SC2206
    files=($g)
    if [[ $modes == *:all:* ]]; then
      out=$golden/$id.out; label=$id
    else
      base=$(basename "${files[0]}" .yaml); out=$golden/$base.$id.out; label="$base $id"
    fi
    if [ "$mode" = check ]; then
      run "$tmp/out" "${files[@]}"; status=$?
      compare "$label"
    elif [ "$mode" = regenerate ] || [ ! -e "$out" ]; then
      count=$((count + 1))
      run "$out" "${files[@]}"; status=$?
      if [ $status -ne 0 ]; then
        echo "golden.sh: $prog $flags ${files[*]} exited $status" >&2; exit 2
      fi
      echo "wrote $out"
    fi
  done
done <"$cases"

if [ "$mode" != check ]; then
  echo "Wrote $count golden files to $golden/."
elif [ $failed -eq 0 ]; then
  echo "All checks passed."
else
  echo "$failed check(s) failed."; exit 1
fi
