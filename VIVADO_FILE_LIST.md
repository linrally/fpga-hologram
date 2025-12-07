# Vivado Synthesis File List

This document lists all files that need to be included in your Vivado project for synthesis.

## Required Files for Synthesis

### 1. Top-Level Module
- **`src/main.v`** - Main top-level module (entry point)

### 2. Verilog Source Files
- **`src/breakbeam_sync_debounce.v`** - Break-beam signal synchronization and debouncing
- **`src/theta_from_breakbeam.v`** - Angular position calculation from break-beam pulses
- **`src/ROM.v`** - ROM memory module (used for texture and cube data)

### 3. VHDL Source Files (NeoPixel Controller)
- **`src/controller/neopixel_controller.vhd`** - Top-level NeoPixel controller entity
- **`src/controller/strip_controller.vhd`** - Strip-level controller component
- **`src/controller/pixel_controller.vhd`** - Pixel-level controller component
- **`src/controller/signal_controller.vhd`** - PWM signal generation component

### 4. Memory Initialization Files
These files are loaded by the ROM module using `$readmemh()`:
- **`src/texture.mem`** - Globe texture data (hex format)
- **`src/cube.mem`** - Cube wireframe data (hex format)

**Important:** These `.mem` files must be in the same directory as `ROM.v` or you need to adjust the path in the ROM instantiation in `main.v`.

### 5. Constraints File
- **`constraints/constraints.xdc`** - Pin assignments and timing constraints

## Files NOT Needed for Synthesis

The following files are for simulation/testing only and should NOT be included:
- All `*_tb.v` files (testbenches)
- `src/RAM.v` (not used in current design)
- `src/proc/*` files (processor files - not used in current ROM-based design)
- `src/pov_peripheral.v` (not used)
- `src/cube_prog.mem` (program memory - not used in ROM mode)
- `sim/` directory (simulation files)

## Vivado Project Setup Steps

1. **Create/Open Project**: Open `build/hologram.xpr` or create a new project

2. **Add Verilog Sources**:
   - `src/main.v`
   - `src/breakbeam_sync_debounce.v`
   - `src/theta_from_breakbeam.v`
   - `src/ROM.v`

3. **Add VHDL Sources**:
   - `src/controller/neopixel_controller.vhd`
   - `src/controller/strip_controller.vhd`
   - `src/controller/pixel_controller.vhd`
   - `src/controller/signal_controller.vhd`

4. **Add Memory Files** (as design sources, not constraints):
   - `src/texture.mem`
   - `src/cube.mem`
   
   **Note:** Vivado needs these files to be accessible during synthesis. You may need to:
   - Copy them to the project directory, OR
   - Add them as "Design Sources" so Vivado knows to include them, OR
   - Ensure the paths in `ROM.v` are relative to where Vivado runs synthesis

5. **Add Constraints**:
   - `constraints/constraints.xdc`

6. **Set Top Module**: Set `main` as the top module

## Memory File Path Issue

The `ROM.v` module uses:
```verilog
$readmemh("texture.mem", MemoryArray);
$readmemh("cube.mem", MemoryArray);
```

These paths are relative. In Vivado, you may need to:
- Ensure the memory files are in the same directory as `ROM.v` when synthesis runs, OR
- Modify the paths in `main.v` to use absolute paths or paths relative to the Vivado project directory

## Mixed Language (Verilog + VHDL)

Vivado supports mixed-language projects. Make sure:
- Verilog files are added as Verilog sources
- VHDL files are added as VHDL sources
- The top module (`main.v`) is Verilog, which instantiates the VHDL entity `neopixel_controller`

