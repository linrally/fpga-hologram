TESTS := $(shell find sim -name "*_tb.v")
RTL   := $(shell find src -name "*.v")

# main has VHDL modules
EXCLUDE_TESTS := sim/main_tb.v
EXCLUDE_RTL = src/main.v

TESTS := $(filter-out $(EXCLUDE_TESTS), $(TESTS))
RTL := $(filter-out $(EXCLUDE_RTL), $(RTL))

.PHONY: sim

sim:
	@for tb in $(TESTS); do \
		base=$$(basename $$tb .v); \
		echo "Running $$tb..."; \
		iverilog -o sim/$$base $(RTL) $$tb || exit 1; \
		vvp sim/$$base || exit 1; \
	done
	@echo "All tests passed!"

