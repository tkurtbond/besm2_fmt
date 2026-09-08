--  BESM2_Fmt - root package of the besm2_fmt program, an Ada port of
--  besm2-rst.scm converting a YAML BESM 2E character/template/item
--  file into reStructuredText. See PLAN.md.
--
--  Exists to anchor the BESM2_Fmt.* child packages (BESM2_Fmt.Config,
--  BESM2_Fmt.Cli, ...) -- a child unit's parent must itself be a real
--  library unit. The executable entry point is the separately-named
--  procedure BESM2_Fmt_Main (src/besm2_fmt_main.adb): a library unit
--  can't be both this package (for its children) and a procedure.

package BESM2_Fmt is

end BESM2_Fmt;
