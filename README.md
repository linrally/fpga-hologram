# FPGA Hologram - WS2812B Neopixel Integration

This project integrates the fpga-neopixel VHDL core to drive 48 WS2812B LEDs on a Nexys A7 FPGA board.

## Overview

The design uses a ready-made VHDL neopixel controller module that generates the correctly timed 1-wire waveform for WS2812B LED strips. The top module (`top_neopixel.vhd`) is configured for 48 LEDs and provides a simple test pattern.

## Files Structure

### Top Module
- **`src/top_neopixel.vhd`**: Top-level module that instantiates the neopixel controller
  - Configured for 48 WS2812B LEDs
  - Uses 24-bit RGB format
  - Test pattern: first 16 LEDs red, next 16 green, last 16 blue

### Constraints
- **`constraints/constraints.xdc`**: Nexys A7 pin mappings
  - Clock: E3 (100 MHz)
  - Start button: M18 (BTNU)
  - Reset button: N17 (BTNC)
  - LED data output: D15 (PMOD JB[1])

### Neopixel Controller Source Files
Located in `fpga-neopixel-main/src/controller/`:
- `neopixel_controller.vhd`
- `pixel_controller.vhd`
- `strip_controller.vhd`
- `signal_controller.vhd`

## Configuration for 48 LEDs

The neopixel controller is configured with the following generics:

```vhdl
px_count_width => 6,        -- log2(48) = 6 (2^6 = 64 > 48)
px_num         => 48,       -- Number of LEDs
bits_per_pixel => 24,       -- WS2812B uses 24-bit RGB
one_high_time  => 80,       -- 0.8us @ 100 MHz = 80 cycles
zero_high_time => 40        -- 0.4us @ 100 MHz = 40 cycles
```

## Setup Instructions

### 1. Add Source Files to Vivado Project

Add the following files to your Vivado project:

**From `fpga-neopixel-main/src/controller/`:**
- `neopixel_controller.vhd`
- `pixel_controller.vhd`
- `strip_controller.vhd`
- `signal_controller.vhd`

**From `src/`:**
- `top_neopixel.vhd` (set as top module)

### 2. Add Constraints

Add `constraints/constraints.xdc` to your project as a constraints file.

### 3. Synthesize and Generate Bitstream

1. Set `top_neopixel` as the top module
2. Run synthesis
3. Run implementation
4. Generate bitstream

### 4. Program FPGA

Program the bitstream to your Nexys A7 board.

## Hardware Connections

### Power Supply
- **Important**: The FPGA cannot provide enough current for the LED strip
- Connect the WS2812B strip to an external 5V power supply
- Ensure the power supply can handle the current (typically 60mA per LED at full brightness = ~2.9A for 48 LEDs)

### Ground Connection
- Connect the strip ground to the FPGA ground (common ground is essential)

### Data Signal
- Connect the strip DIN pin to PMOD JB[1] (FPGA pin D15) **through a level shifter**
- **Critical**: WS2812B requires 5V logic levels, but Nexys A7 outputs 3.3V
- Use a level shifter such as:
  - 74HCT125 (quad buffer)
  - SN74LVC1T45 (single-bit bidirectional)
  - Dedicated level shifter module (e.g., SparkFun Logic Level Converter)

### Level Shifter Connection Example
```
FPGA (3.3V)          Level Shifter          WS2812B (5V)
D15 (led_data)  -->  LV (Low Voltage)  -->  HV (High Voltage)  -->  DIN
GND            -->  GND               -->  GND               -->  GND
                     LV                -->  HV
                     3.3V                -->  5V
```

## Usage

1. **Start Frame Transmission**: Press BTNU (button up) to send one complete frame to the LED strip
2. **Reset**: Press BTNC (center button) to reset the controller

The controller sends one complete frame per button press. After transmission, there's a 100us latch time before the next frame can be sent.

## Customizing the LED Pattern

To change the LED colors, edit the color generation process in `src/top_neopixel.vhd`:

```vhdl
process(next_px_idx)
    variable idx : integer;
begin
    idx := to_integer(next_px_idx);
    -- Modify this section to change colors
    if idx < 16 then
        R <= (others => '1');  -- Red
        G <= (others => '0');
        B <= (others => '0');
    -- ... etc
end process;
```

The `next_px_idx` signal indicates which LED (0-47) is currently being requested.

## WS2812B Data Format

- Bit order: MSB first for each byte
- Byte order: G[7:0], R[7:0], B[7:0]
- Total: 24 bits per pixel

## Timing Specifications

- Clock: 100 MHz (Nexys A7 system clock)
- Bit '1' high time: 0.8us (80 cycles)
- Bit '0' high time: 0.4us (40 cycles)
- Total bit period: 1.25us
- Latch time: 100us (after frame transmission)

## Troubleshooting

- **No LEDs lighting up**: Check level shifter connections and power supply
- **Wrong colors**: Verify data line connection and check for signal integrity issues
- **Only some LEDs work**: Check power supply current capacity and connections
- **Erratic behavior**: Ensure proper ground connection between FPGA and LED strip

## References

- fpga-neopixel repository: https://github.com/blaz-r/fpga-neopixel
- WS2812B Datasheet: Available from various LED strip manufacturers
- Nexys A7 Reference Manual: Digilent documentation

