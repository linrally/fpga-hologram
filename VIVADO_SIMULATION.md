# Running Testbench in Vivado - Step by Step

## Step 1: Open or Create Vivado Project

1. **Open Vivado**
2. If you have an existing project:
   - File → Open Project → Navigate to `build/hologram.xpr`
3. If creating a new project:
   - Create Project → Next
   - Project Name: `hologram` → Location: `build/`
   - Project Type: RTL Project
   - Add Sources: Skip for now (we'll add them manually)
   - Add Constraints: Skip
   - Default Part: Select **Nexys A7-100T** (xc7a100tcsg324-1)

## Step 2: Add Source Files

1. In the **Sources** window, right-click on **Design Sources**
2. Select **Add Sources...**
3. Choose **Add or create design sources**
4. Click **Add Files** and add these files (in this order):
   ```
   fpga-neopixel-main/src/controller/pixel_controller.vhd
   fpga-neopixel-main/src/controller/strip_controller.vhd
   fpga-neopixel-main/src/controller/signal_controller.vhd
   fpga-neopixel-main/src/controller/neopixel_controller.vhd
   src/top_neopixel.vhd
   ```
5. Click **OK** → **Finish**

## Step 3: Add Testbench

1. In the **Sources** window, right-click on **Simulation Sources**
2. Select **Add Sources...**
3. Choose **Add or create simulation sources**
4. Click **Add Files** and add:
   ```
   sim/top_neopixel_tb.vhd
   ```
5. Click **OK** → **Finish**

## Step 4: Set Testbench as Top

1. In the **Sources** window, expand **Simulation Sources** → **sim_1**
2. Right-click on **top_neopixel_tb**
3. Select **Set as Top**

## Step 5: Run Simulation

### Option A: Using Flow Navigator
1. In the **Flow Navigator** (left panel), expand **SIMULATION**
2. Click **Run Simulation** → **Run Behavioral Simulation**

### Option B: Using Toolbar
1. Click the **Run Simulation** button (play icon with waveform)
2. Or go to: **Flow** → **Run Simulation** → **Run Behavioral Simulation**

## Step 6: View Waveforms

Once simulation starts:

1. **Add Signals to Waveform:**
   - In the **Objects** window (usually bottom-left), you'll see signals
   - Expand `top_neopixel_tb` → `UUT` to see internal signals
   - Select these signals:
     - `clk_100mhz`
     - `btn_start`
     - `btn_reset`
     - `led_data` (this is the output you want to see)
   - Right-click → **Add to Wave Window**
   - Or drag and drop into the waveform window

2. **Run Simulation:**
   - Click the **Run** button (or press **F9**)
   - Or use toolbar: **Run for** → Enter `2000ms` → Click **Run**

3. **Zoom Controls:**
   - **Zoom Fit**: Click the magnifying glass icon or press **F**
   - **Zoom In/Out**: Use mouse wheel or zoom buttons
   - **Zoom to Full**: To see the full 2-second simulation

## Step 7: What to Look For

You should see:
- **`clk_100mhz`**: Fast clock signal (10 ns period)
- **`led_data`**: Square wave toggling every 0.5 seconds
  - Should be HIGH for 0.5s, then LOW for 0.5s
  - Repeats continuously (1 Hz frequency)
  - This confirms the test signal is working!

## Troubleshooting

### No Signals in Waveform
- Make sure you added signals to the wave window
- Check that simulation actually ran (look for "Simulation completed" in TCL console)

### Can't See the Pattern
- Zoom out: Use **Zoom Fit** (F key) to see the full view
- The `led_data` signal should show clear 0.5s HIGH/LOW periods

### Compilation Errors
- Check that all source files are added
- Verify file paths are correct
- Check TCL console for specific error messages

### Simulation Runs Too Fast
- Increase simulation time: **Run for** → Enter `2000ms` or `5000ms`

## Quick Reference

- **Run Simulation**: Flow Navigator → Simulation → Run Behavioral Simulation
- **Add Signals**: Right-click signal → Add to Wave Window
- **Run**: Press F9 or click Run button
- **Zoom Fit**: Press F
- **Stop Simulation**: Click Stop button or press Ctrl+C in TCL console

