SHELL=bash

PROGRAM=besm2_fmt

TEST_DATA=$(wildcard test-data/*.yaml)

# This is the list of generated reST files using reST grid tables
# (Format_Grid, the default output).
TEST_OUTPUT=$(foreach f,$(notdir $(TEST_DATA)),build/$(addsuffix .gen.rst,$(basename $(f))))

# This is the list of generated reST files using terse output
# (-t/--terse).
TEST_TERSEOUTPUT=$(foreach f,$(notdir $(TEST_DATA)),build/$(addsuffix -terse.gen.rst,$(basename $(f))))

# This is the list of generated reST files using TBL tables in a raw
# ms block (-m/--raw-ms-tables).
TEST_TBLOUTPUT=$(foreach f,$(notdir $(TEST_DATA)),build/$(addsuffix -tbl.gen.rst,$(basename $(f))))

# -n/--no-unicode-minus comparison variants: same reST-grid and tbl
# output as above, but with ASCII hyphen-minus instead of the default
# Unicode MINUS SIGN for negative numbers (defect points, and
# enhancement/limiter signs), for side-by-side comparison against the
# default output. (besm2-rst's -n is the other way round, turning the
# Unicode minus on; these were once misnamed -unicode-minus for that
# reason.) There's no ascii-minus variant of terse or h-m-m output --
# both render defect points as a "N BP"/"N CP" suffix
# (Format_*.Label_Points), never a sign glyph, so -n changes nothing
# there. h-m-m itself (-H/--hmm) isn't reST at all
# (a tab-indented outline), so pandoc can't turn it into a PDF the way
# it can grid/terse/tbl -- not built here, matching besm-tools'
# GNUmakefile, which doesn't build h-m-m output either.
TEST_ASCII_MINUS_OUTPUT=$(foreach f,$(notdir $(TEST_DATA)),build/$(addsuffix -ascii-minus.gen.rst,$(basename $(f))))
TEST_ASCII_MINUS_TBLOUTPUT=$(foreach f,$(notdir $(TEST_DATA)),build/$(addsuffix -tbl-ascii-minus.gen.rst,$(basename $(f))))

# This is the list of letter-sized PDFs for every variant above.
TEST_LETTEROUTPUT=\
	$(foreach f,$(notdir $(TEST_DATA)),build/$(addsuffix .ms.pdf,$(basename $(f)))) \
	$(foreach f,$(notdir $(TEST_DATA)),build/$(addsuffix -terse.ms.pdf,$(basename $(f)))) \
	$(foreach f,$(notdir $(TEST_DATA)),build/$(addsuffix -tbl.ms.pdf,$(basename $(f)))) \
	$(foreach f,$(notdir $(TEST_DATA)),build/$(addsuffix -ascii-minus.ms.pdf,$(basename $(f)))) \
	$(foreach f,$(notdir $(TEST_DATA)),build/$(addsuffix -tbl-ascii-minus.ms.pdf,$(basename $(f))))

# PDF renderings of the two top-level comparison docs (performance,
# source size), via pandoc's ms writer (like the reST test output
# below) rather than its LaTeX default.
COMPARISON_PDFS=build/PERFORMANCE-COMPARISON.ms.pdf build/SOURCE-COMPARISON.ms.pdf

# HTML renderings of the same two comparison docs.
COMPARISON_HTML=build/PERFORMANCE-COMPARISON.html build/SOURCE-COMPARISON.html

.PHONY: all rst pdf test golden golden-regenerate benchmark benchmark-alibfyaml-liveness pdf-comparison html-comparison install clean testclean

all: $(PROGRAM)

# Always ask gprbuild, which relinks only if something changed,
# including in the Arg_Parser and alibfyaml libraries, which make
# can't see. (FORCE isn't .PHONY, so what depends on $(PROGRAM) is
# remade only if gprbuild actually relinked it.) Those libraries come
# from GPR_PROJECT_PATH: to build against their source checkouts
# instead of the installed copies, use e.g.
#   make GPR_PROJECT_PATH=$$HOME/Repos/Ada/arg_parser:$$HOME/Repos/Ada/alibfyaml
$(PROGRAM): FORCE
	gprbuild -p -P besm2_fmt.gpr

FORCE:

# Installs $(PROGRAM) under $HOME/local (besm2_fmt.gpr's Install
# package Prefix) via gprinstall.
install:
	gprbuild $(GPROPTS) -p -P besm2_fmt.gpr
	gprinstall --mode=usage --install-name=besm2_fmt -f $(GPROPTS) -P besm2_fmt.gpr

rst: $(PROGRAM) \
	$(TEST_OUTPUT) $(TEST_TERSEOUTPUT) $(TEST_TBLOUTPUT) \
	$(TEST_ASCII_MINUS_OUTPUT) $(TEST_ASCII_MINUS_TBLOUTPUT)

pdf: rst $(TEST_LETTEROUTPUT)

# Unit tests, then golden-output tests (test/golden.sh, with the cases
# in test/golden.cases), then command-line tests (test/cli.sh).
test: $(PROGRAM)
	cd test && gprbuild -p -P test.gpr && ./test_text_layout
	test/golden.sh check ./$(PROGRAM)
	test/cli.sh ./$(PROGRAM)

# Write the golden files that are missing (for new cases in
# test/golden.cases) from ./$(PROGRAM)'s output. Review them before
# committing.
golden: $(PROGRAM)
	test/golden.sh generate ./$(PROGRAM)

# Rewrite every golden file, after a deliberate change to the output;
# review the changes with git diff.
golden-regenerate: $(PROGRAM)
	test/golden.sh regenerate ./$(PROGRAM)

# Reproduces PERFORMANCE-COMPARISON.md's besm2_fmt-vs-besm2-rst-family
# performance numbers -- see tools/benchmark.sh's header comment for the
# BESM2_RST/BESM2_RST_F/BESM2_RST_E/BESM2_RST_FE/BENCH_N/BENCH_ENTITIES/
# BENCH_SOURCE environment variables it accepts (each besm2-rst-family
# binary is independently optional). Prints its Markdown report to
# stdout; redirect it yourself (e.g. `make benchmark > /tmp/report.md`)
# to capture one.
benchmark: $(PROGRAM)
	./tools/benchmark.sh

# Reproduces ALIBFYAML-LIVENESS-PERFORMANCE.md's numbers -- compares
# this build of besm2_fmt (BESM2_FMT_NEW, defaulting to $(PROGRAM),
# built here if missing) against BESM2_FMT_OLD, a besm2_fmt binary
# already built against a different alibfyaml commit (there's no
# sensible default for this one -- building it requires a separate
# alibfyaml checkout at that other commit, outside this repo; see
# ALIBFYAML-LIVENESS-PERFORMANCE.md's "Reproducing this" section for
# the exact recipe). See tools/benchmark-alibfyaml-liveness.sh's own
# header comment for BENCH_N/BENCH_ENTITIES/BENCH_SOURCE too. Prints
# its Markdown report to stdout; redirect it yourself (e.g.
# `make benchmark-alibfyaml-liveness > /tmp/report.md`) to capture one.
benchmark-alibfyaml-liveness: $(PROGRAM)
	BESM2_FMT_NEW=$${BESM2_FMT_NEW:-./$(PROGRAM)} ./tools/benchmark-alibfyaml-liveness.sh

pdf-comparison: $(COMPARISON_PDFS)

html-comparison: $(COMPARISON_HTML)

build/%.gen.rst : test-data/%.yaml $(PROGRAM)
	./$(PROGRAM) -s $< >$@

build/%-terse.gen.rst : test-data/%.yaml $(PROGRAM)
	./$(PROGRAM) -s -t $< >$@ # terse

build/%-tbl.gen.rst : test-data/%.yaml $(PROGRAM)
	./$(PROGRAM) -s -m $< >$@ # ms tables

build/%-ascii-minus.gen.rst : test-data/%.yaml $(PROGRAM)
	./$(PROGRAM) -s -n $< >$@ # ASCII minus sign

build/%-tbl-ascii-minus.gen.rst : test-data/%.yaml $(PROGRAM)
	./$(PROGRAM) -s -m -n $< >$@ # ms tables, ASCII minus sign

#MS_COLUMNS=-V twocolumns
build/%.ms.pdf : build/%.gen.rst
	pandoc -r rst -w ms --template=tkb $(MS_COLUMNS) -o $@ $<

build/PERFORMANCE-COMPARISON.ms.pdf : PERFORMANCE-COMPARISON.md
	pandoc -r markdown -w ms --template=tkb -o $@ $<

build/SOURCE-COMPARISON.ms.pdf : SOURCE-COMPARISON.md
	pandoc -r markdown -w ms --template=tkb -o $@ $<

build/PERFORMANCE-COMPARISON.html : PERFORMANCE-COMPARISON.md
	pandoc -s -r markdown -w html -o $@ $<

build/SOURCE-COMPARISON.html : SOURCE-COMPARISON.md
	pandoc -s -r markdown -w html -o $@ $<

clean: testclean
	-rm -f $(PROGRAM)

testclean:
	-rm -v build/*.gen.rst build/*.ms.pdf build/*.html build/bench-*.yaml

.PRECIOUS: \
	build/%.gen.rst build/%-terse.gen.rst build/%-tbl.gen.rst \
	build/%-ascii-minus.gen.rst build/%-tbl-ascii-minus.gen.rst

print-%  : ; @echo $* = $($*)
