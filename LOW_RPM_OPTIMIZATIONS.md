# Low-RPM Visibility Optimizations

## Overview

The cube rendering system has been optimized for low motor speeds (~400 RPM, ~6-7 revolutions per second). At these speeds, the POV display refresh rate is too low for perfectly stable images, so the design prioritizes **visibility and recognizability** over realism.

## Key Optimizations

### 1. Thick Edges (Multi-Column Lighting)

**Problem**: At low RPM, single-column edges are too thin and flickery to see clearly.

**Solution**: Each edge point lights multiple adjacent columns:
- Default: 3 columns (col-1, col, col+1)
- Configurable via `EDGE_THICKNESS` constant
- All columns use full brightness for maximum visibility

**Implementation**: In `cube_pov.s`, the `draw_line_forward` and `draw_line_reverse` sections now light a range of columns around each edge point, with proper clamping to [0, 255].

**Tuning**: Adjust `EDGE_THICKNESS` (stored in `$20`):
- `1` = 3 columns total (recommended default)
- `2` = 5 columns total (thicker, more visible but less precise)
- `0` = single column (not recommended for low RPM)

### 2. Slow Rotation Speed

**Problem**: Fast rotation at low frame rates makes the cube unrecognizable.

**Solution**: Small `ANGLE_STEP` value for slow, smooth rotation:
- Default: `1` (full rotation in 256 frames)
- At 6-7 FPS, this gives ~1 full rotation per ~40 seconds
- Makes the cube shape clearly recognizable frame-to-frame

**Implementation**: Angle increment uses `add $4, $4, $22` where `$22` contains `ANGLE_STEP`.

**Tuning**: Adjust `ANGLE_STEP` (stored in `$22`):
- `1` = very slow rotation (recommended)
- `2-3` = moderate rotation
- `>5` = fast rotation (may be too fast at low RPM)

### 3. Persistence/Blur Effect (Optional)

**Problem**: Sharp edges can appear to flicker or disappear between frames.

**Solution**: Decay existing framebuffer before drawing new frame:
- Shift each column's brightness right by 1 bit (divide by 2)
- Draw new edges at full brightness on top
- Creates trailing effect that helps human eye see continuous edges

**Implementation**: The `main_loop` checks `ENABLE_DECAY` flag:
- If enabled: uses `decay_fb_loop` to shift-right all columns
- If disabled: uses `clear_fb_loop` to set all columns to black

**Tuning**: Set `ENABLE_DECAY` (stored in `$23`):
- `1` = enable decay/blur (recommended for low RPM)
- `0` = sharp edges, no persistence

### 4. Maximum Brightness

**Problem**: Low-contrast edges are hard to see at low refresh rates.

**Solution**: 
- Edges use full white brightness (0x00FFFFFF)
- Background is completely black (0x000000)
- Maximum contrast ensures visibility even with flicker

**Implementation**: `EDGE_BRIGHTNESS` constant (stored in `$21`) set to 0x00FFFFFF.

**Tuning**: Adjust `EDGE_BRIGHTNESS` (stored in `$21`):
- `0x00FFFFFF` = full white (recommended)
- `0x00FF0000` = full red
- `0x0000FF00` = full green
- `0x000000FF` = full blue
- Lower values = dimmer edges (not recommended for low RPM)

### 5. Frame Rate Control

**Problem**: CPU may render too fast, causing unnecessary computation.

**Solution**: Configurable delay loop to control frame rate:
- Default: 20000 iterations
- Adjusts based on CPU speed and desired frame rate
- At 100 MHz, ~20000 iterations ≈ appropriate delay for ~6-7 FPS

**Implementation**: `DELAY_COUNT` constant (stored in `$24`) used in delay loop.

**Tuning**: Adjust `DELAY_COUNT` (stored in `$24`):
- `10000-20000` = faster frame rate
- `20000-50000` = slower frame rate (recommended for low RPM)
- Higher values = slower rendering, more time per frame

## Tunable Constants Location

All constants are defined at the start of `main:` in `cube_pov.s`:

```assembly
# $20 = EDGE_THICKNESS (1 = 3 columns, 2 = 5 columns)
addi $20, $0, 1

# $21 = EDGE_BRIGHTNESS (24-bit RGB)
addi $21, $0, 0x00FF
sll $21, $21, 8
addi $21, $21, 0xFFFF      # = 0x00FFFFFF (full white)

# $22 = ANGLE_STEP (rotation increment per frame)
addi $22, $0, 1            # Slow rotation

# $23 = ENABLE_DECAY (0 = clear, 1 = decay)
addi $23, $0, 1            # Use persistence/blur

# $24 = DELAY_COUNT (frame delay)
addi $24, $0, 20000        # Adjust for ~6-7 FPS
```

## Testing Recommendations

1. **Start with defaults**: All constants are set to recommended values for ~400 RPM
2. **If edges are too thin**: Increase `EDGE_THICKNESS` to 2
3. **If rotation is too fast**: Decrease `ANGLE_STEP` to 1 (already default)
4. **If image is too flickery**: Ensure `ENABLE_DECAY` is 1
5. **If edges are dim**: Ensure `EDGE_BRIGHTNESS` is 0x00FFFFFF
6. **If frame rate is wrong**: Adjust `DELAY_COUNT` based on CPU speed

## Expected Visual Result

At ~400 RPM with these optimizations:
- **Bright, thick wireframe cube** clearly visible
- **Slow, smooth rotation** that's easy to follow
- **Mild trailing effect** (if decay enabled) that helps continuity
- **High contrast** between bright edges and black background
- **Recognizable cube shape** even with flicker

The cube should be clearly visible as a bright rotating wireframe, though it will flicker due to the low refresh rate. The optimizations ensure maximum visibility and recognizability under these conditions.

