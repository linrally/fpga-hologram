TESTS := $(shell find . -name "*_tb.v")
RTL := $(shell find . -name "*.v" ! -name "*_tb.v")

.PHONY: sim

sim:
	@for tb in $(TESTS); do \
		base=$$(basename $$tb .v); \
		echo "Running $$tb..."; \
		iverilog -o sim/$$base $(RTL) $$tb || exit 1; \
		vvp sim/$$base || exit 1; \
	done
	@echo "All tests passed!"

