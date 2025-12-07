# CPU Cube Integration Documentation

## Overview

This document describes the integration of the CPU-driven 3D rotating wireframe cube renderer into the existing POV display system. The system now supports two modes:

- **Mode 0 (Globe Mode)**: Displays a static texture from `texture.mem` ROM (existing functionality)
- **Mode 1 (CPU Cube Mode)**: CPU renders a 3D rotating wireframe cube using a memory-mapped POV peripheral

## Architecture

### Top-Level Integration (`src/main.v`)

The `main.v` module now integrates:

1. **Existing POV Path (Mode 0)**:
   - `breakbeam_sync_debounce.v` → `theta_from_breakbeam.v` → `ROM.v` (texture.mem) → Neopixel controllers

2. **CPU Subsystem (Mode 1)**:
   - CPU processor (`src/proc/processor.v`)
   - CPU instruction ROM (loads `cube_prog.mem`)
   - CPU data RAM (for general data and framebuffer)
   - POV peripheral (`src/pov_peripheral.v`) - memory-mapped framebuffer

3. **Mode Selection**:
   - Input `mode_sel` selects between globe (0) and CPU cube (1)
   - Multiplexes pixel color output to the Neopixel controller chain

### POV Peripheral (`src/pov_peripheral.v`)

The POV peripheral provides a memory-mapped interface for the CPU to write framebuffer data:

**Memory Map:**
- `0xFFFF0000` - `POV_COL_ADDR`: Column index to update [0-255]
- `0xFFFF0004` - `POV_PIXEL_DATA`: 24-bit RGB pixel data
- `0xFFFF0008` - `POV_WRITE`: Write trigger (any write latches pixel data into framebuffer)
- `0xFFFF000C` - `POV_STATUS`: Current column index (read-only)
- `0xFFFF0010` - `POV_CTRL`: Control register (reserved for future use)

**Usage Protocol:**
1. CPU writes column index to `POV_COL_ADDR`
2. CPU writes RGB pixel data to `POV_PIXEL_DATA`
3. CPU writes to `POV_WRITE` (any value) to trigger the write
4. The peripheral automatically outputs the framebuffer entry for the current angular position (`theta`)

**Framebuffer:**
- 256 columns (one per angular position)
- 24-bit RGB per column
- Automatically indexed by `theta` from `theta_from_breakbeam.v`

### Address Decoding

The CPU's data memory accesses are decoded in `main.v`:

- **RAM Access**: Addresses < 0xFFFF0000 go to CPU data RAM
- **POV Peripheral Access**: Addresses 0xFFFF0000-0xFFFF001F go to POV peripheral

## Assembly Program (`src/cube_pov.s`)

The assembly program `cube_pov.s` implements a 3D rotating wireframe cube renderer.

### Program Structure

1. **Initialization**:
   - Sets up base addresses (POV peripheral, data section)
   - Initializes cube vertices (8 vertices at corners of a cube from -1 to +1)
   - Initializes edge list (12 edges connecting vertices)

2. **Main Loop**:
   - Clears framebuffer
   - Rotates vertices (Y-axis rotation)
   - Projects 3D vertices to 1D column indices
   - Draws edges (lines between vertex pairs)
   - Copies framebuffer to POV peripheral
   - Increments rotation angle

### Fixed-Point Format

- **Vertices**: 16.16 fixed-point format
  - Bits [31:16] = integer part
  - Bits [15:0] = fractional part
  - Cube vertices range from -1.0 to +1.0, stored as -65536 to +65536

### Memory Layout (in CPU RAM)

- `0x1000-0x105F`: Original cube vertices (8 vertices × 3 coords × 4 bytes)
- `0x1060-0x11FF`: Rotated vertices (8 vertices × 3 coords × 4 bytes)
- `0x1200-0x121F`: Projected column indices (8 vertices × 4 bytes)
- `0x1220-0x127F`: Edge list (12 edges × 2 indices × 4 bytes)
- `0x1500-0x15FF`: Framebuffer (256 columns × 4 bytes)

### Register Usage

- `$1`: POV peripheral base address (0xFFFF0000)
- `$2`: Data section base address (0x1000)
- `$3`: Stack pointer
- `$4`: Current rotation angle
- `$5-$29`: Temporary/scratch registers
- `$30`: Reserved (exception register)
- `$31`: Reserved (return address)

## Building and Running

### 1. Assemble the CPU Program

The assembly file `src/cube_pov.s` needs to be assembled into a memory file `src/cube_prog.mem` using your course assembler:

```bash
# Example (adjust based on your assembler):
assemble cube_pov.s cube_prog.mem
```

The `.mem` file should be in hexadecimal format (one 32-bit instruction per line) as expected by `$readmemh` in `ROM.v`.

### 2. Update Constraints

The constraints file (`constraints/constraints.xdc`) has been updated to include:
- `mode_sel`: SW0 (switch 0) - selects between globe (0) and CPU cube (1)
- `cpu_reset`: SW1 (switch 1) - CPU reset signal (active high)

### 3. Synthesis

The design should synthesize with:
- `src/main.v` as the top-level module
- All CPU modules from `src/proc/`
- POV peripheral `src/pov_peripheral.v`
- Existing POV modules and VHDL controllers

### 4. Operation

1. **Globe Mode** (`mode_sel = 0`):
   - Set SW0 to LOW
   - System displays texture from `texture.mem` (existing behavior)

2. **CPU Cube Mode** (`mode_sel = 1`):
   - Set SW0 to HIGH
   - Press and release SW1 to reset CPU
   - CPU will start rendering the rotating cube
   - The cube rotates continuously around the Y-axis

## Instruction Set Notes

The CPU supports the following instructions (from `processor.v`):

**R-type (opcode 00000):**
- `add`, `sub`, `and`, `or` (ALU operations)
- `mult`, `div` (multiply/divide)
- `sll`, `sra` (shifts)

**I-type:**
- `addi` (add immediate)
- `lw` (load word)
- `sw` (store word)
- `bne` (branch if not equal)
- `blt` (branch if less than)

**J-type:**
- `j` (jump)
- `jal` (jump and link)
- `jr` (jump register)
- `setx` (set exception register)
- `bex` (branch if exception)

## Limitations and Future Improvements

1. **Rotation Math**: The current assembly program uses simplified rotation. A full implementation would:
   - Pre-compute sin/cos lookup tables
   - Use proper fixed-point matrix multiplication
   - Support rotation around multiple axes

2. **Performance**: The CPU runs at the system clock (100 MHz). For smoother animation, consider:
   - Optimizing the rendering loop
   - Using hardware acceleration for rotation math
   - Adding a frame rate control mechanism

3. **Visual Enhancements**:
   - Add color gradients
   - Implement depth shading
   - Add perspective projection
   - Support multiple objects

## File Changes Summary

### New Files:
- `src/pov_peripheral.v`: Memory-mapped POV peripheral
- `src/cube_pov.s`: CPU assembly program for cube rendering
- `CPU_CUBE_INTEGRATION.md`: This documentation

### Modified Files:
- `src/main.v`: Integrated CPU, address decoding, mode selection
- `constraints/constraints.xdc`: Added `mode_sel` and `cpu_reset` inputs

### Unchanged (Preserved):
- All existing POV modules (`breakbeam_sync_debounce.v`, `theta_from_breakbeam.v`, `ROM.v`)
- All VHDL Neopixel controller modules
- CPU processor and supporting modules in `src/proc/`

## Testing

To test the system:

1. **Verify Globe Mode**: Ensure existing globe mode still works with `mode_sel = 0`
2. **Test CPU Integration**: 
   - Set `mode_sel = 1`
   - Reset CPU with `cpu_reset`
   - Verify CPU executes and writes to POV peripheral
   - Check that LED strip displays the cube pattern
3. **Mode Switching**: Toggle `mode_sel` and verify smooth switching between modes

## Troubleshooting

- **CPU not executing**: Check that `cube_prog.mem` is properly generated and loaded
- **No cube display**: Verify CPU is writing to POV peripheral addresses
- **Globe mode broken**: Ensure mode selection multiplexer is working correctly
- **Timing issues**: Check that CPU and POV paths are properly synchronized

