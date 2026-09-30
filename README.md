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
