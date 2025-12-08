TESTS := $(shell find sim -name "*_tb.v")
RTL   := $(shell find src -name "*.v")

# main has VHDL modules
# wrapper is a processor test
EXCLUDE_TESTS := sim/main_tb.v sim/proc/Wrapper_tb.v 
EXCLUDE_RTL = src/main.v
TESTS := $(filter-out $(EXCLUDE_TESTS), $(TESTS))
RTL := $(filter-out $(EXCLUDE_RTL), $(RTL))

.PHONY: sim

# args need to have a trailing newline (TODO: fix)

sim: # simulate verilog
	@mkdir -p sim/build; \
	for tb in $(TESTS); do \
		base=$$(basename $$tb .v); \
		dir=$$(dirname $$tb); \
        args="$$dir/$$base.args"; \
		echo "================================================"; \
		echo "$$tb..."; \
		echo "================================================"; \
		iverilog -o sim/build/$$base $(RTL) $$tb || exit 1; \
		bin=$$(pwd)/sim/build/$$base; \
		if [ -f "$$args" ]; then \
			echo "Found args $$args"; \
			while read arg; do \
				[ -z "$$arg" ] && continue; \
				echo "Running $$base test=$$arg..."; \
                out=$$( cd $$dir && vvp $$bin +test=$$arg 2>&1 ); \
                status=$$?; \
                echo "$$out" | grep -v '^VCD'; \
                if [ $$status -ne 0 ]; then \
                    echo "\033[1;31mFAILED on $$arg in $$base\033[0m"; \
                    exit 1; \
                fi; \
			done < $$args; \
		else \
			echo "Running $$base..."; \
            out=$$( cd $$dir && vvp $$bin 2>&1 ); \
            status=$$?; \
            echo "$$out" | grep -v '^VCD'; \
            if [ $$status -ne 0 ]; then \
                echo "\033[1;31mFAILED $$base\033[0m"; \
                exit 1; \
            fi; \
		fi; \
	done
	@echo "\033[1;32mAll tests passed!\033[0m"

asim:
	@mkdir -p sim/build; \
	echo "Running assembly tests..."; \
	for tbfile in $$(find sim/asm-tests -name "*_tb.v"); do \
		tbname=$$(basename $$tbfile .v); \
		topmod=$$tbname; \
		argsfile="sim/asm-tests/$${tbname}.args"; \
		echo "================================================"; \
		echo "$$tbname (top module $$topmod)"; \
		echo "================================================"; \
		if [ ! -f $$argsfile ]; then \
			echo "No args file $$argsfile, skipping."; \
			continue; \
		fi; \
		while read sfile; do \
			[ -z "$$sfile" ] && continue; \
			memfile="$${sfile%.s}.mem"; \
			echo "Assembling $$sfile -> $$memfile"; \
			python3 assembler/assemble.py $$sfile -o $$memfile || exit 1; \
			base="${tbname}_$$(basename $$sfile .s)"; \
			echo "Compiling $$tbfile with program $$sfile"; \
			iverilog -o sim/build/$$base \
				-s $$topmod \
				-P$${topmod}.INSTR_FILE=\"$$memfile\" \
				$(RTL) $$tbfile || exit 1; \
			echo "Running $$base"; \
			out=$$(vvp sim/build/$$base 2>&1); \
			echo "$$out" | grep -v '^VCD'; \
		done < $$argsfile; \
	done; \
	echo "\033[1;32mAll tests passed!\033[0m"


assemble: 
	python3 assembler/assemble.py src/main.s -o src/main.mem