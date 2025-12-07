TESTS := $(shell find sim -name "*_tb.v")
RTL   := $(shell find src -name "*.v")

# main has VHDL modules
EXCLUDE_TESTS := sim/main_tb.v
EXCLUDE_RTL = src/main.v

TESTS := $(filter-out $(EXCLUDE_TESTS), $(TESTS))
RTL := $(filter-out $(EXCLUDE_RTL), $(RTL))

.PHONY: sim

# args need to have a trailing newline (TODO: fix)
sim:
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