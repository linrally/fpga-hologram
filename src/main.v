// main.v
// Top-level for POV display with WS2812 and break-beam angle locking
//
// Architecture:
//   - Mode 0 (mode_sel = 0): Globe mode - displays static texture from texture.mem ROM
//   - Mode 1 (mode_sel = 1): CPU cube mode - CPU renders 3D rotating wireframe cube
//
// CPU Integration:
//   - CPU instruction memory: separate ROM for CPU program (cube_prog.mem)
//   - CPU data memory: RAM for general data
//   - Memory-mapped POV peripheral: 0xFFFF0000-0xFFFF0010 for framebuffer control
//   - Address decoding routes CPU data accesses to RAM or POV peripheral

module main(
    input  wire clk,          // 100 MHz board clock
    input  wire break_din,    // IR break-beam sensor input
    input  wire mode_sel,     // Mode selection: 0=globe, 1=CPU cube
    input  wire cpu_reset,    // CPU reset signal
    output wire ws2812_dout,  // data out to WS2812 strip
    output wire [0:0] LED     // debug LED
);
    // Debug: mirror raw break-beam input on LED
    assign LED = break_din;

    // Texture dimensions
    localparam LED_COUNT  = 52;   // number of LEDs on strip
    localparam TEX_WIDTH  = 256;  // columns around the circle

    // ------------------------------------------------------------
    // 1) Debounce / synchronize break-beam signal into clk domain
    // ------------------------------------------------------------
    wire break_clean;

    breakbeam_sync_debounce deb (
        .clk      (clk),
        .din_raw  (break_din),
        .din_clean(break_clean)
    );

    // ------------------------------------------------------------
    // 2) Generate angular position theta (0..63) from break-beam
    // ------------------------------------------------------------
    wire [5:0] theta;   // 6-bit angle index (64 steps per revolution)

    theta_from_breakbeam #(
        .THETA_BITS (6),
        .PERIOD_BITS(28)   // increase to 26/28 if you want slower RPM support
    ) angle_gen (
        .clk        (clk),
        .reset      (1'b0),        // tie to a real reset if you have one
        .break_clean(break_clean),
        .theta      (theta)
    );

    // ------------------------------------------------------------
    // 3) Use theta + next_px_num to address the texture ROM
    // ------------------------------------------------------------
    wire [5:0] next_px_num;  // from neopixel_controller: which LED index

    // Scale theta (0..63) → column (0..255)
    wire [13:0] theta_scaled = theta * TEX_WIDTH;  // 6+8 bits = 14 bits
    wire [$clog2(TEX_WIDTH)-1:0] col;
    assign col = theta_scaled >> 6;  // divide by 64

    // ROM interface
    wire [23:0] pixel_color;
    wire [$clog2(TEX_WIDTH*LED_COUNT)-1:0] rom_addr;
    assign rom_addr = next_px_num * TEX_WIDTH + col;

    ROM #(
        .DATA_WIDTH   (24),
        .ADDRESS_WIDTH($clog2(TEX_WIDTH*LED_COUNT)),
        .DEPTH        (TEX_WIDTH*LED_COUNT),
        .MEMFILE      ("texture.mem")
    ) rom (
        .clk    (clk),
        .addr   (rom_addr),
        .dataOut(pixel_color)
    );

    // ------------------------------------------------------------
    // 4) CPU subsystem (Mode 1: CPU cube rendering)
    // ------------------------------------------------------------
    
    // CPU signals
    wire cpu_rwe, cpu_mwe;
    wire [4:0] cpu_rd, cpu_rs1, cpu_rs2;
    wire [31:0] cpu_inst_addr, cpu_inst_data;
    wire [31:0] cpu_reg_data, cpu_regA, cpu_regB;
    wire [31:0] cpu_mem_addr, cpu_mem_data_in, cpu_mem_data_out;
    
    // CPU instruction memory (separate from texture ROM)
    localparam INSTR_FILE = "cube_prog";  // CPU program memory file
    
    // CPU processor
    processor CPU(
        .clock(clk),
        .reset(cpu_reset),
        .address_imem(cpu_inst_addr),
        .q_imem(cpu_inst_data),
        .ctrl_writeEnable(cpu_rwe),
        .ctrl_writeReg(cpu_rd),
        .ctrl_readRegA(cpu_rs1),
        .ctrl_readRegB(cpu_rs2),
        .data_writeReg(cpu_reg_data),
        .data_readRegA(cpu_regA),
        .data_readRegB(cpu_regB),
        .wren(cpu_mwe),
        .address_dmem(cpu_mem_addr),
        .data(cpu_mem_data_in),
        .q_dmem(cpu_mem_data_out)
    );
    
    // CPU instruction ROM
    ROM #(
        .DATA_WIDTH(32),
        .ADDRESS_WIDTH(12),
        .DEPTH(4096),
        .MEMFILE({INSTR_FILE, ".mem"})
    ) cpu_inst_rom(
        .clk(clk),
        .addr(cpu_inst_addr[11:0]),
        .dataOut(cpu_inst_data)
    );
    
    // CPU register file
    regfile cpu_regfile(
        .clock(clk),
        .ctrl_writeEnable(cpu_rwe),
        .ctrl_reset(cpu_reset),
        .ctrl_writeReg(cpu_rd),
        .ctrl_readRegA(cpu_rs1),
        .ctrl_readRegB(cpu_rs2),
        .data_writeReg(cpu_reg_data),
        .data_readRegA(cpu_regA),
        .data_readRegB(cpu_regB)
    );
    
    // CPU data memory (RAM) - for normal data accesses
    wire cpu_ram_wren;
    wire [31:0] cpu_ram_data_out;
    
    // Address decoding: POV peripheral is at 0xFFFF0000-0xFFFF0010
    wire is_pov_access = (cpu_mem_addr >= 32'hFFFF0000) && (cpu_mem_addr < 32'hFFFF0020);
    wire is_ram_access = !is_pov_access;
    
    assign cpu_ram_wren = cpu_mwe && is_ram_access;
    
    RAM #(
        .DATA_WIDTH(32),
        .ADDRESS_WIDTH(12),
        .DEPTH(4096)
    ) cpu_data_ram(
        .clk(clk),
        .wEn(cpu_ram_wren),
        .addr(cpu_mem_addr[11:0]),
        .dataIn(cpu_mem_data_in),
        .dataOut(cpu_ram_data_out)
    );
    
    // POV peripheral (memory-mapped IO)
    wire [31:0] pov_cpu_data_out;
    wire [23:0] pov_pixel_color;
    wire cpu_pov_rden = !cpu_mwe && is_pov_access;  // Read enable for lw instruction
    
    // POV peripheral reset: only reset on power-on, not tied to CPU reset
    // This allows framebuffer to persist even when CPU resets
    pov_peripheral pov_periph(
        .clk(clk),
        .reset(1'b0),  // Don't tie to cpu_reset - let framebuffer persist
        .cpu_addr(cpu_mem_addr),
        .cpu_data_in(cpu_mem_data_in),
        .cpu_wren(cpu_mwe && is_pov_access),
        .cpu_rden(cpu_pov_rden),
        .cpu_data_out(pov_cpu_data_out),
        .theta(theta),
        .pixel_color(pov_pixel_color)
    );
    
    // Multiplex CPU data memory output (RAM or POV peripheral)
    assign cpu_mem_data_out = is_pov_access ? pov_cpu_data_out : cpu_ram_data_out;
    
    // ------------------------------------------------------------
    // 5) Mode selection: choose between globe and CPU cube
    // ------------------------------------------------------------
    wire [23:0] selected_pixel_color;
    wire [23:0] test_pattern_color;  // Hardware test pattern for debugging
    
    // Hardware test pattern: shows a simple gradient pattern based on theta
    // This helps verify mode selection and POV peripheral path work
    // Pattern: bright gradient from red to green to blue based on column
    wire [7:0] test_col;
    assign test_col = {theta, 2'b00};  // Same as POV peripheral column calculation
    
    // Create simple bright gradient: red -> green -> blue
    // Split 256 columns into 3 segments for maximum brightness and visibility
    wire [7:0] test_r, test_g, test_b;
    
    // Simple approach: use column value directly for smooth gradient
    // Red: high at start, fade to 0
    // Green: fade in, peak in middle, fade out
    // Blue: start at 0, fade in to full
    assign test_r = (test_col < 128) ? (8'd255 - test_col[7:0]) : 8'h00;
    assign test_g = (test_col < 128) ? test_col[7:0] : (8'd255 - (test_col - 8'd128));
    assign test_b = (test_col < 128) ? 8'h00 : (test_col - 8'd128);
    
    assign test_pattern_color = {test_r, test_g, test_b};
    
    // Select: test pattern if mode_sel=1, globe if mode_sel=0
    // TODO: Once CPU works, change to: mode_sel ? pov_pixel_color : pixel_color
    assign selected_pixel_color = mode_sel ? test_pattern_color : pixel_color;
    
    // ------------------------------------------------------------
    // 6) Neopixel controller (VHDL entity)
    //    Feed it the selected pixel color (globe or CPU cube)
    // ------------------------------------------------------------
    neopixel_controller #(
        .px_count_width (6),
        .px_num         (LED_COUNT),
        .bits_per_pixel (24)
    ) strip (
        .clk        (clk),
        .rst        (1'b0),
        .start      (1'b1),
        .pixel      (selected_pixel_color),
        .next_px_num(next_px_num),
        .signal_out (ws2812_dout)
    );

    // IMPORTANT: the old fixed timer-based theta increment has been removed.

endmodule