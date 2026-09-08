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

# -n/--unicode-minus comparison variants: same reST-grid and tbl
# output as above, but with Unicode MINUS SIGN instead of ASCII
# hyphen-minus for negative numbers (defect points, and
# enhancement/limiter signs), for side-by-side comparison against the
# default hyphen-minus output. There's no unicode-minus variant of
# terse or h-m-m output -- both render defect points as a "N BP"/
# "N CP" suffix (Format_*.Label_Points), never a sign glyph, so -n
# changes nothing there. h-m-m itself (-H/--hmm) isn't reST at all
# (a tab-indented outline), so pandoc can't turn it into a PDF the way
# it can grid/terse/tbl -- not built here, matching besm-tools'
# GNUmakefile, which doesn't build h-m-m output either.
TEST_UNICODE_MINUS_OUTPUT=$(foreach f,$(notdir $(TEST_DATA)),build/$(addsuffix -unicode-minus.gen.rst,$(basename $(f))))
TEST_UNICODE_MINUS_TBLOUTPUT=$(foreach f,$(notdir $(TEST_DATA)),build/$(addsuffix -tbl-unicode-minus.gen.rst,$(basename $(f))))

# This is the list of letter-sized PDFs for every variant above.
TEST_LETTEROUTPUT=\
	$(foreach f,$(notdir $(TEST_DATA)),build/$(addsuffix .ms.pdf,$(basename $(f)))) \
	$(foreach f,$(notdir $(TEST_DATA)),build/$(addsuffix -terse.ms.pdf,$(basename $(f)))) \
	$(foreach f,$(notdir $(TEST_DATA)),build/$(addsuffix -tbl.ms.pdf,$(basename $(f)))) \
	$(foreach f,$(notdir $(TEST_DATA)),build/$(addsuffix -unicode-minus.ms.pdf,$(basename $(f)))) \
	$(foreach f,$(notdir $(TEST_DATA)),build/$(addsuffix -tbl-unicode-minus.ms.pdf,$(basename $(f))))

.PHONY: all rst pdf test benchmark clean testclean

all: $(PROGRAM)

$(PROGRAM): $(wildcard src/*.ads src/*.adb) besm2_fmt.gpr
	gprbuild -p -P besm2_fmt.gpr

rst: $(PROGRAM) \
	$(TEST_OUTPUT) $(TEST_TERSEOUTPUT) $(TEST_TBLOUTPUT) \
	$(TEST_UNICODE_MINUS_OUTPUT) $(TEST_UNICODE_MINUS_TBLOUTPUT)

pdf: rst $(TEST_LETTEROUTPUT)

test:
	cd test && gprbuild -p -P test.gpr && ./test_text_layout

# Reproduces COMPARISON.md's besm2_fmt-vs-besm2-rst performance
# numbers -- see tools/benchmark.sh's header comment for the
# BESM2_RST/BENCH_N/BENCH_ENTITIES/BENCH_SOURCE environment variables
# it accepts. Prints its Markdown report to stdout; redirect it
# yourself (e.g. `make benchmark > /tmp/report.md`) to capture one.
benchmark: $(PROGRAM)
	./tools/benchmark.sh

build/%.gen.rst : test-data/%.yaml $(PROGRAM)
	./$(PROGRAM) -s $< >$@

build/%-terse.gen.rst : test-data/%.yaml $(PROGRAM)
	./$(PROGRAM) -s -t $< >$@ # terse

build/%-tbl.gen.rst : test-data/%.yaml $(PROGRAM)
	./$(PROGRAM) -s -m $< >$@ # ms tables

build/%-unicode-minus.gen.rst : test-data/%.yaml $(PROGRAM)
	./$(PROGRAM) -s -n $< >$@ # unicode minus sign

build/%-tbl-unicode-minus.gen.rst : test-data/%.yaml $(PROGRAM)
	./$(PROGRAM) -s -m -n $< >$@ # ms tables, unicode minus sign

#MS_COLUMNS=-V twocolumns
build/%.ms.pdf : build/%.gen.rst
	pandoc -r rst -w ms --template=tkb $(MS_COLUMNS) -o $@ $<

clean: testclean
	-rm -f $(PROGRAM)

testclean:
	-rm -v build/*.gen.rst build/*.ms.pdf build/bench-*.yaml

.PRECIOUS: \
	build/%.gen.rst build/%-terse.gen.rst build/%-tbl.gen.rst \
	build/%-unicode-minus.gen.rst build/%-tbl-unicode-minus.gen.rst

print-%  : ; @echo $* = $($*)
