TESTS := $(shell find . -name "*_tb.v")
RTL := $(shell find . -name "*.v" ! -name "*_tb.v")

.PHONY: sim

sim:
	@for tb in $(TESTS); do \
		echo "Running $$tb..."; \
		iverilog -o sim/sim $(RTL) $$tb || exit 1; \
		vvp sim/sim || exit 1; \
	done
	@echo "All tests passed!"

