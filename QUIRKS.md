# besm2_fmt: quirks worth fixing

2026-09-30; done 2026-10-01

## Status

All six are fixed in all four programs, in the order the plan below
gives, each checked against the program before it:

| Program | Commits |
| --- | --- |
| besm2-rst, and besm2-rst-f, -e and -f-e (besm-tools) | `e7fdd75` |
| Ada (this repository) | `bf18fa4` (items 1–3), `afb25ce` (items 4–6) |
| Buffer port (obesm2_fmt) | `5a9ff04`, `3be8f1e` |
| Ropes port (obesm2_fmt2) | `3c6310a` (its catch-up with the Buffer port's step 14), `48154ad`, `4703413` |

The ADA-DIFFERENCES.md update is the Buffer port's step 15: section 5.1
lists these fixes, and section 4 gains the differences from besm2-rst
found on the way (4.6 to 4.9). The rest of this document is the plan as
written, with two corrections marked.

`golden.sh` didn't get a `fail` mode: a case that exits 1 ends its
golden file with a `==== exit 1 ====` line instead, since the bad-input
globs mix fixtures that do and don't exit 1.

## Overview

Six of the "quirks kept on purpose" (ADA-DIFFERENCES.md, section 5) are really defects, and each should be fixed the same way in all four programs:

- **besm2-rst**: Chicken Scheme, in besm-tools.
- **Ada**: besm2_fmt, this repository.
- **Buffer port**: the Oberon-2 port obesm2_fmt, with hand-rolled buffers (`Besm2Str`).
- **Ropes port**: obesm2_fmt2, a rewrite of the Buffer port with every string a `Ropes.Rope`.

Each was checked against the besm2-rst source and the first three binaries on 2026-09-30. The Ropes port was checked against its source on 2026-10-01: every item is in the same place as in the Buffer port, and the code is the same apart from strings. Where this document says "the ports", it means both Oberon-2 ports.

| # | Item | Programs | Golden output changes | Size |
| --- | --- | --- | --- | --- |
| 1 | `-R` root line goes to standard output under `-o` | all four | `o-R` case only | small |
| 2 | An error ends its file; exit status stays 0 | all four | `bad-*` cases; exit statuses | medium |
| 3 | `--help` exits 1 | all four | none (`cli.sh` only) | small |
| 4 | `-p`/`--page` affects only terse output | all four | new `-p` cases; `emph`, `ms-emph` | small |
| 5 | Raw ms: no blank line after `.TE` | all four | every multi-entity raw ms case | small |
| 6 | Raw ms prints TOTAL only when positive | all four | raw ms cases with a zero or negative total | small |

The other quirks stay: the skill total always shown (skills are never added into TOTAL), and whitespace differences that don't show in rendered reST or ms. Two are small separate decisions: `-d`/`--debug` (besm2-rst traces to standard error; Ada and the port ignore it) and `+-1` for a negative limiter value (no real data file has one).

## 1. The -R root line goes to standard output under -o

`besm2_fmt -H -R Root -o out.hmm file.yaml` writes the outline to `out.hmm` without its root node, and prints the root line on the terminal. The file is an outline with no top.

**Cause.** besm2-rst's `main` writes `*hmm-root*` before `with-output-to-file` redirects output. The Ada version copied the order on purpose (a comment in `besm2_fmt_main.adb` says so), and the port copied the Ada version. Your `000-todo.org` already lists it.

**Fix.**

- besm2-rst: move the `(when (and *hmm-output* *hmm-root*) …)` form inside what `with-output-to-file` runs, before `process-operands`.
- Ada: write the root line after `Set_Output (Output_File)`, and drop the comment defending the old order.
- Buffer port: write it through `Besm2Out` after `Besm2Out.ToFile`, and drop the AGENTS.md note that calls it the one exception to "all output goes through `Besm2Out`".
- Ropes port: the same move in `Besm2Fmt.Main`, and drop the comment above it. Its AGENTS.md has no such note.

**Tests.** The `o-R` golden case changes: the root line moves from standard output into the file. The `cli.sh` check "-R goes to standard output under -o" is reversed in all three test suites.

## 2. An error ends its file, and the exit status stays 0

After bad input the run still exits 0, so `make rst` quietly builds incomplete output. And one bad entity loses every entity after it in the same file.

**besm2-rst is inconsistent**, so there is no behaviour to be faithful to. Each case was run as `besm2-rst -t BAD.yaml enyon-boase-2e.yaml`:

| Bad input | besm2-rst | Ada and the ports now |
| --- | --- | --- |
| Missing key (`bad-missing-key`) | `besm2-rst: Unable to find "points" …`, exit 2, later files not processed | reported, next file, exit 0 |
| YAML syntax error (`bad-yaml`) | reported, next file, exit 0 | reported, next file, exit 0 |
| Bad integer (`bad-int`) | `(+) bad argument type`, next file, exit 0 | reported, next file, exit 0 |
| Bad customizer (`bad-customizer-map`) | reported, next file, exit 0 | reported, next file, exit 0 |
| Top level not a list (`bad-root`) | **nothing reported**, next file, exit 0 (see the correction below) | reported, next file, exit 0 |

> **Correction.** `bad-root`'s mapping is the file's second document,
> and besm2-rst reads only the first (ADA-DIFFERENCES.md, 4.4), so it
> never sees it. A single-document file whose top level is a mapping
> was reported, as a `(car) bad argument type` error.

**Fix, the same in all four:**

1. Exit 1 at the end of the run if any error was reported. (Status 2 stays for command-line mistakes.)
2. After a data error in an entity, report it and go on with the next entity in the same file.
3. A YAML syntax error still ends its file: libfyaml can't resume after one, and neither can Chicken's yaml egg.

> **Aside: to be confirmed.** This assumes bad input should give exit
> status 1 (2 stays for command-line mistakes), and that after a data
> error the run goes on with the next entity, not the next file. The
> alternative is to keep besm2-rst's status 2 for input errors too.

Per program:

- besm2-rst: make `must-exist` signal a condition instead of calling `die`, catch it per entity rather than per file, report a top level that isn't a list, and exit 1 at the end if anything was reported.
- Ada: catch `Data_Error` and `Missing_Key` around each entity in `Process_Entities`, set a flag, and `Set_Exit_Status (1)` at the end.
- Ports: the loaders already return `FALSE` with a message, so `ProcessDocument` goes on to the next entity instead of returning `FALSE`, and a flag set by `Report` and `ReportYaml` gives status 1 at the end of `Main`. A top level that isn't a sequence still ends its document. Both ports have the same `ProcessDocument`/`ProcessOne` loop, so the change is the same in each.

**Tests.** The `bad-*` golden cases with good entities or documents after the bad one change, since those are now written; `bad-yaml` and `bad-yaml-second-doc` don't. `golden.sh` requires every case to exit 0, so it needs a way to expect status 1, such as a new `fail` mode in `golden.cases`. The `cli.sh` checks that expect 0 after bad input change to 1.

## 3. --help exits 1

Asking for help is not an error, but all four programs exit 1 for `-h`/`--help`, so a script can't tell it from a failure.

| Program | Where `-h` usage goes | Exit status |
| --- | --- | --- |
| besm2-rst | standard error | 1 |
| Ada besm2_fmt | standard output | 1 |
| Buffer port | standard output | 1 |
| Ropes port | standard output | 1 |

besm2-rst's `usage` procedure always writes to standard error and always calls `(exit 1)`, whether `-h` or a parse error called it. Its usage text also ends with `Current argv: …`, a leftover debugging line.

**Fix.** An explicit `-h`/`--help` prints to standard output and exits 0; a command-line mistake still goes to standard error with status 2.

- besm2-rst: give `usage` a status and an output port; call it with standard output and 0 from the `-h` option. Consider dropping the `Current argv` line.
- Ada: exit 0 in the `Help_Requested` handler of `besm2_fmt_main.adb`.
- Ports: exit 0 in `Besm2Fmt.Main` when `Besm2Cli.helpShown` is set, and drop the comment that quotes besm2-rst's exit 1.

**Tests.** Only `cli.sh`: its two help checks expect 0 instead of 1, and the comment at its top saying that help exits 1.

## 4. -p only affects terse output

`-p`/`--page` is "Page after description.  (Only for ms output!)" in besm2-rst's usage: a page break after each entity's description, which shows only when the reST goes on to ms. But only the terse formatter uses it. In besm2-rst, the terse formatter (lines 606–609) writes the description and then, under `-p`,

```
.. raw:: ms

   .bp
```

So the break comes after the description, inside the entity, and only when the entity has a description and `-D` wasn't given. The grid and raw ms formatters write the description too (besm2-rst lines 415–417 and 981–984), as plain reST in both, but never look at the flag, so `-p` does nothing without `-t`. Ada and the ports copied this, and the golden cases `emph` (`-b -i -l -M -p`) and `ms-emph` (the same with `-m`) show it: their output has no page breaks.

> **Correction.** An earlier version of this section said `-p` was
> documented as "start each entity on a new page", and that terse
> writes the break before every entity after the first. Neither is
> true: the option, its help text, and all four programs put the
> break after the description.

**Fix.** Honour `-p` in every formatter that writes the description, in the same place as terse.

- Grid: write the same `.. raw:: ms` / `.bp` block right after the description.
- Raw ms: the same block, after the description and before the entity's own `.. raw:: ms` table block. The description is plain reST there, so the same block works.
- H-M-M: leave it alone; that output is an outline, not pages.

**Tests.** Regenerate the `emph` and `ms-emph` golden files and check that the only change is a page break after each description. The terse `t-page` and `t-page-D` cases shouldn't change. Add grid and raw ms cases with `-p -D` to show no break without a description.

## 5. No blank line after .TE

In raw ms output (`-m`), each entity is a `.. raw:: ms` block that ends with an indented `.TE`, and the next entity's title follows on the very next line:

```
   .TE
FV2021 Coleopteran
------------------
```

reStructuredText needs a blank line to end an explicit markup block. The result is the same in all four programs:

- **docutils** warns "Explicit markup ends without a blank line; unexpected unindent." at every entity boundary, then treats the title correctly.
- **pandoc** doesn't warn and keeps the content; the following text appears in its ms output.

So the output works, but every run through docutils gives one warning per entity, which hides real warnings.

**Fix.** Write one blank line after the `.TE` line, in besm2-rst, Ada and the ports (`Besm2RawMs.ProcessEntity`).

**Tests.** All the raw ms golden files change (`ms*`, `hmm-t-ms`, `bad-m`, `edge-m`, `files-m`, `o-files`), and the only difference should be one added blank line after each `.TE`. It's worth adding a check that `rst2html` on the `ms` output gives no warnings.

## 6. Raw ms prints TOTAL only when it is positive

The grid formatter always writes the entity's TOTAL row (besm2-rst.scm lines 495–497). The raw ms formatter wraps the same row in a test (lines 1075–1078):

```scheme
(when (> entity-total 0)
  (show #t *raw-prefix* "#" (tbold (points->string entity-total)) "#"
        (tbold "TOTAL") nl))
```

So an entity whose points total 0 or less (an item made only of defects, or an empty entity) has a TOTAL row in grid output but none in `-m` output. The terse formatter always shows the total too. None of the other TOTAL rows (STATS, ATTRIBUTES, DEFECTS, SKILL POINTS) has this test, so it looks like an oversight. Ada and the ports copied it (`Besm2RawMs.ProcessEntity`, with a comment quoting the Scheme).

**Fix.** Drop the `when` and always write the row, in all four programs, and the ports' comment.

**Tests.** Only raw ms golden files for entities with a total of 0 or less change, which probably means some of the `edge-m` and `bad-m` cases. Add a fixture with a negative total if none exists.

## Plan

**First, bring the Ropes port up to the Buffer port.** The Ropes port was forked from the Buffer port before its step 14 (obesm2_fmt a18b73a and 289ef95), and is missing it:

- `test/golden.cases`: the `bad` globs are `bad-*`, not `@(bad|shape)-*`, so the `shape-*` fixtures aren't golden cases; and `sort-ties` is still a `scheme` case, with no grid case. It has 356 golden files to the Buffer port's 363.
- `test/cli.sh`: no check that a directory given as a file is reported, or that a pipe given as a path is read whole.
- The comments in `Besm2Entities.Mod` and `Besm2Fmt.Mod` that still describe the Ada defects as current.
- Its binary (2026-09-30 13:06) predates olibfyaml's directory fix, so it needs rebuilding.

Do this as its own commit before the quirk fixes, so that `make compare` against the Buffer port and `make golden` from the Ada binary both pass on the starting point.

**Order.** Fix each item in besm2-rst first, then in Ada, then in the Buffer port, then in the Ropes port. Each program's reference is the one before it: the Ada golden files are checked against besm2-rst; both ports' `make golden` regenerates from the Ada binary; and the Ropes port's `make compare` checks standard output, standard error and status against the Buffer port's binary. So the programs stay in step at each stage, and the Buffer port must be fixed and rebuilt before `make compare` in the Ropes port means anything. After each item, all four should give identical output on every golden case.

**Two groups, two commits per repository** (three in the Ropes port, with the catch-up first).

1. **Command line and exit status** (items 1, 2 and 3). This changes how the programs behave, not what they write, so the golden files barely change. The tests that do change are in `cli.sh`: the `-R` check, the help checks, and every bad-input check that now expects status 1. `golden.sh` also needs a way for a case to expect status 1, since the `stdout bad*` and `files-bad` cases will no longer exit 0.
   The ports' `test/compare.sh` compares exit statuses too, so in the Ropes port it shows items 1–3 as differences until the Buffer port is fixed.
2. **Output** (items 4, 5 and 6). Only the formatters change. Regenerate (`make golden-regenerate` in Ada, `make golden` in the ports) and read the whole `git diff` of `test/golden/`: every change should be a page break after a description, a blank line after `.TE`, or a TOTAL row. The two ports' golden diffs should be identical.

The `sort-ties` golden files came from besm2-rst itself; regenerate them with the fixed besm2-rst, not with the Ada program.

**Documents.** Once the fixes are in, correct ADA-DIFFERENCES.md §5 ("Quirks kept on purpose"), which is in the Buffer port; the Ropes port's AGENTS.md defers to it rather than keeping a copy. Three of its bullets are wrong even now:

- "`-d`/`--debug` is accepted and does nothing" — in besm2-rst it traces to standard error through `dbg`/`dfmt`. Only Ada and the port ignore it, so this is a difference, not a quirk kept on purpose. (Not worth fixing; move it to the differences.)
- "`--help` exits 1, not 0" — true, but besm2-rst writes the usage to standard error and Ada and the port write it to standard output.
- "the run's exit status is still 0" — not for a missing key: besm2-rst `die`s with status 2 and processes none of the later files.

After the fixes, move items 1–6 out of §5 into a "fixed in all four" list, and keep in §5 only what is left: the whitespace differences, the skill total that is always shown, and `+-1`.

**Not in this plan.** `-d` in Ada and the port, `+-1` for negative counts-as values (no real data file has one), and Unicode folding and sorting, which is a separate decision.
