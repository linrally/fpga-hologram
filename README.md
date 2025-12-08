# FPGA Hologram – CPU Assembly and Behavior

## What `main.s` does
- **Texture selection:** Polls BTNU (MMIO 1000). On rising edge, increments `texture_idx`, wraps 0–2, and writes to MMIO 1001.
- **Invert toggle:** Reads BTN_INV (MMIO 1002). Rising edge toggles `invert_flag` and writes to MMIO 1005.
- **Brightness presets:** Reads BTN_BRT (MMIO 1003). Rising edge steps `brightness_level` through 0..3 and writes to MMIO 1004.
- **Utility work each loop:**  
  - Debounce average over 16 button samples; sets a flag in `s0` (not used elsewhere).  
  - Pseudo-LFSR update in `t3` (for variability/telemetry).  
  - Checksum over scratch RAM words `[1100..1107]`, stored at `1108`.
- **Startup init:** Seeds LFSR, clears scratch RAM `[1100..1108]`, initializes brightness/invert MMIO (1004/1005), and texture_idx (1001).
- **Idle padding:** Small delay loop and a frame counter to keep the pipeline busy (no external side effects).

## CPU role in the project
- Runs the assembly program from `main.mem` to handle user input and simple control logic.
- Drives texture selection via MMIO writes to 1001.
- Exposes user-driven controls (invert/brightness) via MMIO 1004/1005 for hardware to consume.
- Performs lightweight telemetry (checksum, LFSR) without affecting display output.

## MMIO map (as used by `main.s`)
- `1000` : BTNU (texture cycle) read
- `1001` : texture_idx/LED register write/read
- `1002` : BTN_INV (invert button) read
- `1003` : BTN_BRT (brightness button) read
- `1004` : brightness preset read/write (4 bits, used by hardware)
- `1005` : invert flag read/write (1 bit, used by hardware)
- `1100..1107` : scratch RAM for checksum input
- `1108` : checksum output

## Display pipeline integration
- Hardware reads `texture_idx` to select columns in `texture.mem`.
- Hardware reads `invert_flag` to optionally invert GRB channels before driving LEDs.
- Hardware reads `brightness_level` to apply a simple right-shift brightness scale (levels 0..3).
