TESTS := $(shell find sim -name "*_tb.v")
RTL   := $(shell find src -name "*.v")

# main has VHDL modules
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

psim: # processor simulation
	@mkdir -p sim/build; \
	args="sim/proc/Wrapper_tb.args"; \
	tb="sim/proc/Wrapper_tb.v"; \
	echo "Running processor tests..."; \
	while read arg; do \
		[ -z "$$arg" ] && continue; \
		sfile="$$arg"; \
		memfile="$${sfile%.s}.mem"; \
		echo "================================================"; \
		echo "Assembling $$sfile -> $$memfile"; \
		python3 assembler/assemble.py $$sfile -o $$memfile || exit 1; \
		testname=$$(basename $$sfile .s); \
		base="Wrapper_tb_$${testname}"; \
		echo "Compiling $$tb with $$memfile"; \
		echo "================================================"; \
		iverilog -o sim/build/$$base -s Wrapper_tb \
			-PWrapper_tb.INSTR_FILE=\"$$memfile\" \
			$(RTL) $$tb || exit 1; \
		bin=$$(pwd)/sim/build/$$base; \
		echo "Running $$base..."; \
		out=$$( vvp $$bin 2>&1 ); \
		status=$$?; \
		echo "$$out" | grep -v '^VCD'; \
		if [ $$status -ne 0 ]; then \
			echo "\033[1;31mFAILED on $$sfile in $$base\033[0m"; \
			exit 1; \
		fi; \
	done < $$args; \
	echo "\033[1;32mProcessor tests passed!\033[0m"

assemble: 
	python3 assembler/assemble.py src/main.s -o src/main.mem