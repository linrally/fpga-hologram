# Simulation Guide for top_neopixel

## Running the Testbench in Vivado

### Step 1: Add Source Files to Project

Make sure these files are added to your Vivado project:

**Required Source Files:**
- `src/top_neopixel.vhd` (top module)
- `fpga-neopixel-main/src/controller/neopixel_controller.vhd`
- `fpga-neopixel-main/src/controller/pixel_controller.vhd`
- `fpga-neopixel-main/src/controller/strip_controller.vhd`
- `fpga-neopixel-main/src/controller/signal_controller.vhd`

**Testbench:**
- `sim/top_neopixel_tb.vhd`

### Step 2: Set Testbench as Top

1. In Vivado, go to **Sources** window
2. Right-click on `top_neopixel_tb.vhd`
3. Select **Set as Top**

### Step 3: Run Simulation

1. Go to **Flow Navigator** → **Simulation** → **Run Simulation** → **Run Behavioral Simulation**
   - Or use the toolbar: Click the simulation icon (play button with waveform)

### Step 4: Add Signals to Waveform

1. In the **Objects** window, select signals to monitor:
   - `clk_100mhz`
   - `btn_start`
   - `btn_reset`
   - `led_data` (this is the output you want to see)

2. Right-click and select **Add to Wave Window**
   - Or drag and drop into the waveform window

### Step 5: Run Simulation

1. Click **Run** button (or press F9)
2. Set simulation time to **2 seconds** (2000ms) or use the default
3. Click **Run All** or press F9

## What to Expect

### Test Signal Mode (Current Configuration)

You should see:
- `led_data` toggling between '0' and '1'
- Period: 1 second (0.5s high, 0.5s low)
- This confirms the pin output is working

### Waveform Characteristics

- **Clock**: `clk_100mhz` - 10 ns period (100 MHz)
- **Test Signal**: `led_data` - Square wave at 1 Hz
  - High for 0.5 seconds
  - Low for 0.5 seconds
  - Repeats continuously

### Zooming

- Use zoom controls to see:
  - **Zoom Out**: To see full 1-second periods
  - **Zoom In**: To see individual clock edges

## Troubleshooting

### No Signal Activity
- Check that all source files are added
- Verify no compilation errors
- Check that testbench is set as top

### Simulation Runs Too Fast
- Increase simulation time in toolbar
- Use "Run for" and set to 2000ms or more

### Can't See Waveform
- Make sure signals are added to wave window
- Check zoom level (may need to zoom out)
- Verify simulation actually ran (check status bar)

## Next Steps

Once you verify the test signal works:
1. Switch back to neopixel mode in `top_neopixel.vhd`
2. Comment out: `led_data <= test_output;`
3. Uncomment: `led_data <= neopixel_out;`
4. Re-run simulation to see neopixel protocol signals


