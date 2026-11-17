# besm2_fmt - Read YAML files representing  BESM 2nd Edition characters and output them in various formats

This is a port of the besm-rst.scm program I wrote earlier.

## Building and testing

It needs [arg_parser](https://github.com/tkurtbond/arg_parser) and
[alibfyaml](https://github.com/tkurtbond/alibfyaml), found through
`GPR_PROJECT_PATH`.

```sh
make            # build ./besm2_fmt
make test       # unit tests, golden-output tests, command-line tests
make golden     # write golden files for new cases in test/golden.cases
```

After a deliberate change to the output, `make golden-regenerate`
rewrites every golden file in `test/golden/`; review the changes with
`git diff` before committing them.

## BESM and the rulebook

*Big Eyes, Small Mouth*, Second Edition Revised, is © 2002 Guardians
of Order, Inc. BESM and the Tri-Stat System now belong to Dyskami
Publishing Company, whose Tri-Stat® System is a registered trademark.
This project is not affiliated with or endorsed by either. It formats
character files that you write, and holds no text from the rules.

The test fixtures in `test/data/` and `test-data/` are characters made
for the tests, except for the FV2021 Coleopteran mecha, converted from
a sample in *Big Robots, Cool Starships* (© 1999 Guardians of Order)
so that the output can be checked against it; its description is
paraphrased.
