#!/usr/bin/env bash
# The -ext fixtures that are upgraded forms of -2e ones (PLAN.md's A4,
# in besm2_cg_po) print as the originals do: enyon-boase-ext.yaml
# byte for byte, and composite-ext.yaml except on the lines of its
# weapons, whose damage, Abilities and Disabilities moved from
# `details` to keys (and the second line of the original Rocket Pod's
# `details`, a block scalar, "Stoppable").  Run from the repo root, as test/upgraded.sh
# [program]; prints ok/FAIL per case and exits 1 if any failed.

prog=${1:-./besm2_fmt}
data=test/data
failed=0

for flags in "" -t -m -H -s "-t -s" "-H -s"; do
  if cmp -s <("$prog" $flags "$data/enyon-boase-2e.yaml" 2>&1) \
            <("$prog" $flags "$data/enyon-boase-ext.yaml" 2>&1); then
    echo "ok   - enyon-boase-ext prints as enyon-boase-2e with '$flags'"
  else
    echo "FAIL - enyon-boase-ext prints differently with '$flags'"
    failed=$((failed + 1))
  fi
done

for flags in -t -H; do
  other=$(diff <("$prog" $flags "$data/composite-2e.yaml" 2>&1) \
               <("$prog" $flags "$data/composite-ext.yaml" 2>&1) \
            | grep '^[<>]' | grep -v -e Weapon -e '^< Stoppable\. 1 MP)$')
  if [ -z "$other" ]; then
    echo "ok   - composite-ext differs from composite-2e only on the weapons with '$flags'"
  else
    echo "FAIL - composite-ext differs from composite-2e elsewhere with '$flags':"
    printf '%s\n' "$other" | sed 's/^/    /'
    failed=$((failed + 1))
  fi
done

if [ "$failed" -eq 0 ]; then echo "All checks passed."; else echo "$failed check(s) failed."; exit 1; fi
