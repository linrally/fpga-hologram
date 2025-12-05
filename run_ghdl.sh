#!/bin/bash
# Quick script to run GHDL simulation and open GTKWave

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}GHDL Simulation Script${NC}"
echo "===================="

# Check if GHDL is installed
if ! command -v ghdl &> /dev/null; then
    echo "Error: GHDL is not installed."
    echo "Install with: sudo apt-get install ghdl gtkwave (Ubuntu/Debian)"
    echo "Or: brew install ghdl gtkwave (macOS)"
    exit 1
fi

# Check if GTKWave is installed
if ! command -v gtkwave &> /dev/null; then
    echo "Warning: GTKWave is not installed. VCD file will be generated but not opened."
    GTKWAVE_AVAIL=false
else
    GTKWAVE_AVAIL=true
fi

# Create work directory
mkdir -p work
mkdir -p sim

echo -e "${GREEN}Step 1: Compiling VHDL files...${NC}"

# Compile in dependency order
ghdl -a --std=08 --ieee=synopsys --workdir=work fpga-neopixel-main/src/controller/pixel_controller.vhd
ghdl -a --std=08 --ieee=synopsys --workdir=work fpga-neopixel-main/src/controller/strip_controller.vhd
ghdl -a --std=08 --ieee=synopsys --workdir=work fpga-neopixel-main/src/controller/signal_controller.vhd
ghdl -a --std=08 --ieee=synopsys --workdir=work fpga-neopixel-main/src/controller/neopixel_controller.vhd
ghdl -a --std=08 --ieee=synopsys --workdir=work src/top_neopixel.vhd
ghdl -a --std=08 --ieee=synopsys --workdir=work sim/top_neopixel_tb.vhd

if [ $? -ne 0 ]; then
    echo "Error: Compilation failed!"
    exit 1
fi

echo -e "${GREEN}Step 2: Elaborating testbench...${NC}"
ghdl -e --std=08 --ieee=synopsys --workdir=work top_neopixel_tb

if [ $? -ne 0 ]; then
    echo "Error: Elaboration failed!"
    exit 1
fi

echo -e "${GREEN}Step 3: Running simulation...${NC}"
ghdl -r --std=08 --ieee=synopsys --workdir=work top_neopixel_tb \
    --vcd=sim/top_neopixel.vcd --stop-time=2sec

if [ $? -ne 0 ]; then
    echo "Error: Simulation failed!"
    exit 1
fi

echo -e "${GREEN}Simulation complete!${NC}"
echo "VCD file: sim/top_neopixel.vcd"

if [ "$GTKWAVE_AVAIL" = true ]; then
    echo -e "${GREEN}Opening GTKWave...${NC}"
    gtkwave sim/top_neopixel.vcd &
else
    echo "To view waveforms, install GTKWave and run:"
    echo "  gtkwave sim/top_neopixel.vcd"
fi


