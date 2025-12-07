# Interactive Menu Control System

## Overview

The CPU-driven menu control system provides interactive control over the POV display using buttons and LED feedback. The system allows real-time adjustment of display settings including mode, brightness, color effects, and more.

## Architecture

### Hardware Components

1. **Display Control Peripheral** (`src/display_control_peripheral.v`)
   - Memory-mapped at `0xFFFF1000-0xFFFF1018`
   - Handles button debouncing and edge detection
   - Processes pixels through brightness and color effect pipeline
   - Provides LED output for menu feedback

2. **CPU Integration** (`src/main.v`)
   - CPU runs `menu_control.mem` program
   - Address decoding routes CPU accesses to RAM or display peripheral
   - Pixel pipeline: ROM → Mode Selection → Brightness → Effects → Neopixel

3. **Assembly Program** (`src/menu_control.s`)
   - 358 lines of assembly code (166 instructions)
   - Implements menu navigation and control logic
   - Button polling with edge detection
   - Menu state machine

## Memory Map

| Address | Register | Description |
|---------|----------|-------------|
| 0xFFFF1000 | DISP_MODE | Display mode: 0=globe, 1=cube |
| 0xFFFF1004 | DISP_BRIGHTNESS | Brightness: 0-255 (0=off, 255=full) |
| 0xFFFF1008 | DISP_EFFECT | Color effect: 0=normal, 1=grayscale, 2=sepia, 3=inverted, 4=rainbow |
| 0xFFFF100C | DISP_SPEED | Speed offset (reserved for future use) |
| 0xFFFF1010 | BTN_STATUS | Button status (read-only): bit0=UP, bit1=DOWN, bit2=CENTER |
| 0xFFFF1014 | MENU_SEL | Current menu selection (0-4) |
| 0xFFFF1018 | LED_OUT | LED output pattern (16 bits, one per LED) |

## Menu System

### Menu Items

0. **Mode**: Toggle between Globe and Cube display
1. **Brightness**: Cycle through 0%, 25%, 50%, 75%, 100%
2. **Effect**: Cycle through Normal, Grayscale, Sepia, Inverted, Rainbow
3. **Speed**: Reserved for future use
4. **Reset**: Reset all settings to defaults

### Controls

- **BTNU (Up Button)**: Navigate menu up (wraps from 0 to 4)
- **BTND (Down Button)**: Navigate menu down (wraps from 4 to 0)
- **BTNC (Center Button)**: Select/Activate current menu item

### LED Feedback

- LEDs 0-4 indicate current menu selection
- LED N lights up when menu item N is selected
- Example: LED 0 on = Menu 0 (Mode) selected

## Color Effects

1. **Normal (0)**: No effect, original colors
2. **Grayscale (1)**: Convert to grayscale using luminance formula
3. **Sepia (2)**: Apply warm brown sepia tone
4. **Inverted (3)**: Invert all color channels (255 - value)
5. **Rainbow (4)**: Apply color shift for rainbow effect

## Brightness Control

Brightness values cycle through:
- 0 (0%): Off
- 64 (25%): Quarter brightness
- 128 (50%): Half brightness
- 192 (75%): Three-quarter brightness
- 255 (100%): Full brightness

## Pin Assignments

### Buttons
- `btn_up`: M18 (BTNU)
- `btn_down`: P18 (BTND)
- `btn_center`: U18 (BTNC)

### LEDs
- `LED[0]` through `LED[15]`: H17, K15, J13, N14, R18, V17, U17, U16, V16, T15, U14, T16, V15, V14, V12, V11

### Other
- `cpu_reset`: L16 (SW1)

## Usage

1. **Power on**: CPU starts running menu control program
2. **Navigate**: Use BTNU/BTND to navigate menu items
3. **Select**: Press BTNC to activate current menu item
4. **Adjust**: Menu items cycle through their options on each BTNC press
5. **Reset**: Select menu item 4 (Reset) to restore defaults

## Implementation Details

### Button Debouncing

The display peripheral includes hardware debouncing:
- 2-FF synchronizer to bring buttons into clock domain
- 12-bit counter for debounce (~41 µs at 100 MHz)
- Edge detection for single-press recognition

### Pixel Processing Pipeline

1. **ROM Lookup**: Read pixel from globe or cube ROM based on mode
2. **Brightness**: Multiply RGB values by brightness/255
3. **Effect**: Apply color effect transformation
4. **Output**: Send processed pixel to Neopixel controller

### Assembly Program Structure

- **Initialization**: Set default values, configure peripheral
- **Main Loop**: Poll buttons, handle navigation/selection
- **Menu Handlers**: Process each menu item's logic
- **Delay Loop**: Debounce and reduce CPU load

## Files

- `src/display_control_peripheral.v`: Display control peripheral module
- `src/main.v`: Top-level with CPU integration
- `src/menu_control.s`: Assembly program source (358 lines)
- `src/menu_control.mem`: Assembled program (166 instructions)
- `constraints/constraints.xdc`: Pin assignments

## Testing

1. Synthesize and program FPGA
2. Press CPU reset (SW1) to initialize CPU
3. Observe LED 0 lighting up (menu item 0 selected)
4. Press BTNU/BTND to navigate menu (LEDs should change)
5. Press BTNC to activate menu items and observe display changes
6. Test brightness adjustment (should dim/brighten display)
7. Test color effects (should change display appearance)
8. Test mode switching (should toggle between globe and cube)

