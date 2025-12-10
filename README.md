## What This Is

This is a persistence-of-vision (POV) hologram display built entirely in Verilog and running on a **Nexys A7 FPGA**. Basically, you spin a strip of 52 LEDs really fast, and by carefully timing when each LED lights up based on the rotation angle, you can make it look like there's a 3D image floating in mid-air. It's the same trick those LED fan displays use, but we're doing it with a custom 5-stage pipelined CPU running assembly code that handles button input and display control.

<img width="468" height="516" alt="Screenshot 2025-12-08 at 10 06 39 PM" src="https://github.com/user-attachments/assets/15cd752c-196a-42cd-a50b-b6911069e785" />

## How It Works

### The Hardware Side (All Verilog)

The whole disk spins around via a gear motor, and there's a breakbeam sensor that detects when it passes a fixed point. Every time it sees that point, we know we're at angle zero. From there, the `angle_mapper` module (in `src/angle_mapper.v`) tracks how many clock cycles have passed to figure out what angle we're at (0 to 63, since we use 6 bits). It uses an exponential moving average to smooth out the rotation period, so even if the motor speed varies a bit, the angle tracking stays accurate.

The display itself is 64 pixels wide (columns) and 52 pixels tall (rows, one per LED). We've got 30 frames of animation stored in a ROM (`src/texture.mem`), and the hardware cycles through them at 15 frames per second. There's a frame timer in `main.v` that counts clock cycles and advances the frame index every 6.67 million cycles (100MHz / 15 FPS). So every 1/15th of a second, it moves to the next frame, creating a smooth animation as the thing spins.

The ROM addressing works like this: `rom_addr = frame_idx * FRAME_SIZE + LED_row * TEX_WIDTH + column`. The frame offset gets you to the right animation frame, then the LED row tells you which horizontal slice, and the column comes from the rotation angle.

The pixel colors get processed through brightness and invert logic before hitting the LEDs. The brightness just right-shifts the RGB values (so level 0 is full brightness, level 1 is half, level 2 is quarter, level 3 is eighth), and the invert does a bitwise XOR with all 1s to flip the colors. This all happens in combinational logic in `main.v`, so it's instant.

The LED driver (`src/controller/neopixel_controller.vhd` - yes, it's VHDL, but everything else is Verilog) handles all the timing-critical stuff for the WS2812B protocol. Those LEDs need really precise timing (800kHz bit rate, 1.25µs per bit), so we offloaded that to a dedicated hardware module. The CPU just doesn't run fast enough or predictably enough to bit-bang that protocol reliably.

We actually tried implementing the WS2812B driver ourselves in Verilog, but getting the timing right was really tricky. The protocol requires precise pulse widths (800ns high for a '1', 400ns high for a '0'), and any jitter or timing errors cause the LEDs to misinterpret the data. After struggling with it for a while, we found [blaz-r's fpga-neopixel project](https://github.com/blaz-r/fpga-neopixel) which had a well-tested VHDL implementation. We adapted their `neopixel_controller` module to work with our system. The fact that it's VHDL while the rest of our project is Verilog meant we had to use Xilinx Vivado for synthesis and simulation, since it supports mixed-language projects. Other tools like Verilator or Icarus Verilog don't handle VHDL, so Vivado was the only option that could compile everything together.

### The CPU Side (Verilog + Assembly)

The CPU is a custom 5-stage pipelined processor (MIPS-like ISA) that we built from scratch in Verilog. You can find the processor implementation in `src/proc/processor.v`, with the ALU in `src/proc/alu/`, the register file in `src/proc/regfile/`, and the multiply/divide unit in `src/proc/multdiv/`. The ALU uses a carry-lookahead adder (`cla_32.v`) for fast addition, and the multiplier uses Booth's algorithm while the divider uses non-restoring division.

The CPU is running a simple event loop (`src/main.s`) that just watches two buttons. One button (BTNU) cycles through brightness levels (0-3), and the other (BTND) toggles color inversion. The tricky part is that buttons bounce, so we had to write debouncing logic in assembly. The way it works is we wait for the button value to stay stable for 16 clock cycles before we consider it a real press. Then we only act on the rising edge (when it goes from 0 to 1) so you don't get multiple actions from a single button press.

The CPU communicates with the hardware through memory-mapped I/O (MMIO). The `RAM_MMIO` module (`src/RAM_MMIO.v`) intercepts memory accesses to certain addresses and routes them to hardware registers instead of RAM:

- **Address 1000**: Read BTNU button state
- **Address 1001**: Read/write LED debug output (5 bits)
- **Address 1002**: Read/write brightness level (2 bits, 0-3)
- **Address 1003**: Read BTND button state  
- **Address 1004**: Read/write invert flag (1 bit)

When the CPU writes to addresses 1002 or 1004, those values get latched into registers that feed directly into the pixel processing pipeline. So the CPU can control the display in real-time without the hardware having to poll anything.

The assembly code is pretty straightforward - it's basically just polling buttons, debouncing them, and writing to MMIO addresses. We had to add NOPs to avoid pipeline hazards, and the code could definitely be cleaner if we had function calls, but our processor doesn't have a stack so everything's inline. The assembler is in `assembler/assemble.py` - it's a Python script that converts MIPS-like assembly into the binary `.mem` file that gets loaded into the instruction ROM.

## Project Structure

Here's where everything lives:

- **`src/main.v`** - Top-level module that wires everything together. This is where the frame timer, ROM addressing, pixel processing, and CPU instantiation all happen.

- **`src/main.s`** - The assembly program the CPU runs. It's a simple event loop that debounces buttons and writes to MMIO.

- **`src/main.mem`** - Compiled binary of the assembly program (generated by the assembler).

- **`src/proc/processor.v`** - The 5-stage pipelined CPU. Handles instruction fetch, decode, execute, memory access, and writeback. Includes hazard detection and bypassing.

- **`src/proc/alu/`** - Arithmetic logic unit. Has the main ALU (`alu.v`), carry-lookahead adders (`cla_32.v`, `cla_8.v`), barrel shifters (`sll_barrel_32.v`, `sra_barrel_32.v`), and bitwise operations.

- **`src/proc/regfile/`** - 32-register register file. Each register is a D flip-flop.

- **`src/proc/multdiv/`** - Multi-cycle multiply/divide unit. Uses Booth's algorithm for multiplication and non-restoring division.

- **`src/RAM_MMIO.v`** - Memory-mapped I/O module. Combines regular RAM with hardware register mapping for buttons and display control.

- **`src/ROM.v`** - Read-only memory module. Used for both instruction memory and texture memory.

- **`src/RAM.v`** - Random access memory module. Used for CPU data memory.

- **`src/angle_mapper.v`** - Tracks rotation angle from breakbeam sensor pulses. Uses exponential moving average to smooth period measurements.

- **`src/debounce.v`** - Hardware debouncer for the breakbeam sensor input (2-FF synchronizer).

- **`src/controller/neopixel_controller.vhd`** - WS2812B LED driver. Handles the timing-critical serial protocol. Adapted from [blaz-r's fpga-neopixel project](https://github.com/blaz-r/fpga-neopixel). This is the only VHDL file - everything else is Verilog, which is why we use Vivado for the mixed-language project.

- **`src/texture.mem`** - Binary texture data. 30 frames × 64 columns × 52 rows × 3 bytes (RGB) = 299,520 bytes total.

- **`constraints/constraints.xdc`** - Pin assignments for the Nexys A7. Maps signals to physical FPGA pins.

- **`assembler/assemble.py`** - Python assembler that converts assembly to binary. See `assembler/README.md` for usage.

- **`utils/gen.py`** - Python script to generate texture memory from images/GIFs.

- **`build/hologram.xpr`** - Vivado project file.

- **`sim/`** - Testbenches for various components. The processor, ALU, register file, and multiply/divide units all have testbenches.

## The Stack

- **FPGA**: Nexys A7 (Xilinx Artix-7) running at 100MHz
- **LEDs**: 52 WS2812B (NeoPixel) LEDs
- **Sensor**: Breakbeam sensor for rotation tracking
- **CPU**: Custom 5-stage pipelined processor (MIPS-like ISA), all in Verilog
- **Memory**: Instruction ROM (4KB) and data RAM (4KB) with MMIO
- **Animation**: 30 frames, 64×52 pixels each, stored in texture ROM
- **Language**: Verilog (with one VHDL file for the LED controller)
- **Tools**: Xilinx Vivado (required for mixed Verilog/VHDL compilation)

## Why We Built a CPU

You might wonder why we need a CPU at all when we could just do everything in hardware. The answer is flexibility and complexity. Button debouncing with proper edge detection, state machines for brightness cycling, and handling multiple button inputs would require a lot of Verilog state machines and counters. By using a CPU, we can write the logic in assembly, which is much easier to modify and debug. Plus, it demonstrates that we can build a real pipelined processor that actually does useful work in a real system.

The CPU handles all the "soft" control logic - things that don't need microsecond timing. The hardware handles the "hard" real-time stuff - LED timing, angle tracking, frame animation. It's a good example of hardware/software co-design.

## Development Tools

Because our project mixes Verilog and VHDL (the NeoPixel controller is VHDL while everything else is Verilog), we had to use **Xilinx Vivado** for synthesis and simulation. Vivado is one of the few tools that can handle mixed-language projects seamlessly. The project file is in `build/hologram.xpr` if you want to open it in Vivado.

## References 

- **NeoPixel Controller**: [blaz-r/fpga-neopixel](https://github.com/blaz-r/fpga-neopixel) - VHDL implementation of WS2812B/SK6812 LED driver. We adapted the `neopixel_controller` module from this project after struggling to implement the timing-critical protocol ourselves. The module handles the precise 800kHz serial protocol required by WS2812B LEDs.
