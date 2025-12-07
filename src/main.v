// main.v
// Top-level for POV display with WS2812 and break-beam angle locking
//
// Architecture:
//   - CPU-driven menu system with button control
//   - Display control peripheral for brightness, effects, mode selection
//   - Mode 0: Globe mode - displays static texture from texture.mem ROM
//   - Mode 1: Cube mode - displays precomputed rotating wireframe cube from cube.mem ROM
//
// CPU Integration:
//   - CPU instruction memory: menu_control.mem
//   - CPU data memory: RAM for general data
//   - Display control peripheral: 0xFFFF1000-0xFFFF1018 for menu control
//   - Address decoding routes CPU data accesses to RAM or display peripheral

module main(
    input  wire clk,          // 100 MHz board clock
    input  wire break_din,    // IR break-beam sensor input
    input  wire btn_up,       // BTNU - menu navigation up
    input  wire btn_down,     // BTND - menu navigation down
    input  wire btn_center,   // BTNC - menu selection
    input  wire cpu_reset,    // CPU reset signal (SW1)
    output wire ws2812_dout,  // data out to WS2812 strip
    output wire [15:0] LED    // LED outputs for menu feedback
);
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
        .reset      (1'b0),
        .break_clean(break_clean),
        .theta      (theta)
    );

    // ------------------------------------------------------------
    // 3) Use theta + next_px_num to address the texture ROMs
    // ------------------------------------------------------------
    wire [5:0] next_px_num;  // from neopixel_controller: which LED index

    // Scale theta (0..63) → column (0..255)
    wire [13:0] theta_scaled = theta * TEX_WIDTH;  // 6+8 bits = 14 bits
    wire [$clog2(TEX_WIDTH)-1:0] col;
    assign col = theta_scaled >> 6;  // divide by 64

    // ROM address calculation: same for both ROMs
    wire [$clog2(TEX_WIDTH*LED_COUNT)-1:0] rom_addr;
    assign rom_addr = next_px_num * TEX_WIDTH + col;

    // Globe texture ROM
    wire [23:0] globe_pixel_color;
    ROM #(
        .DATA_WIDTH   (24),
        .ADDRESS_WIDTH($clog2(TEX_WIDTH*LED_COUNT)),
        .DEPTH        (TEX_WIDTH*LED_COUNT),
        .MEMFILE      ("texture.mem")
    ) globe_rom (
        .clk    (clk),
        .addr   (rom_addr),
        .dataOut(globe_pixel_color)
    );

    // Cube LUT ROM (precomputed rotating wireframe cube)
    wire [23:0] cube_pixel_color;
    ROM #(
        .DATA_WIDTH   (24),
        .ADDRESS_WIDTH($clog2(TEX_WIDTH*LED_COUNT)),
        .DEPTH        (TEX_WIDTH*LED_COUNT),
        .MEMFILE      ("cube.mem")
    ) cube_rom (
        .clk    (clk),
        .addr   (rom_addr),
        .dataOut(cube_pixel_color)
    );

    // ------------------------------------------------------------
    // 4) CPU subsystem for menu control
    // ------------------------------------------------------------
    
    // CPU signals
    wire cpu_rwe, cpu_mwe;
    wire [4:0] cpu_rd, cpu_rs1, cpu_rs2;
    wire [31:0] cpu_inst_addr, cpu_inst_data;
    wire [31:0] cpu_reg_data, cpu_regA, cpu_regB;
    wire [31:0] cpu_mem_addr, cpu_mem_data_in, cpu_mem_data_out;
    
    // CPU instruction memory
    localparam INSTR_FILE = "menu_control";  // CPU program memory file
    
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
    
    // Address decoding: Display peripheral is at 0xFFFF1000-0xFFFF1020
    wire is_disp_access = (cpu_mem_addr >= 32'hFFFF1000) && (cpu_mem_addr < 32'hFFFF1020);
    wire is_ram_access = !is_disp_access;
    
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
    
    // ------------------------------------------------------------
    // 5) Mode selection: choose between globe and cube (from CPU)
    // ------------------------------------------------------------
    wire [23:0] selected_pixel_color_raw;
    wire disp_mode;
    assign selected_pixel_color_raw = disp_mode ? cube_pixel_color : globe_pixel_color;
    
    // Display control peripheral (memory-mapped IO)
    wire [31:0] disp_cpu_data_out;
    wire [23:0] processed_pixel_color;
    wire cpu_disp_rden = !cpu_mwe && is_disp_access;  // Read enable for lw instruction
    
    display_control_peripheral disp_periph(
        .clk(clk),
        .reset(cpu_reset),
        .cpu_addr(cpu_mem_addr),
        .cpu_data_in(cpu_mem_data_in),
        .cpu_wren(cpu_mwe && is_disp_access),
        .cpu_rden(cpu_disp_rden),
        .cpu_data_out(disp_cpu_data_out),
        .btn_up(btn_up),
        .btn_down(btn_down),
        .btn_center(btn_center),
        .pixel_in(selected_pixel_color_raw),
        .pixel_out(processed_pixel_color),
        .disp_mode(disp_mode),
        .disp_brightness(),
        .disp_effect(),
        .menu_sel(),
        .led_out(LED)
    );
    
    // Multiplex CPU data memory output (RAM or display peripheral)
    assign cpu_mem_data_out = is_disp_access ? disp_cpu_data_out : cpu_ram_data_out;

    // ------------------------------------------------------------
    // 6) Neopixel controller (VHDL entity)
    //    Feed it the processed pixel color (brightness + effects applied)
    // ------------------------------------------------------------
    neopixel_controller #(
        .px_count_width (6),
        .px_num         (LED_COUNT),
        .bits_per_pixel (24)
    ) strip (
        .clk        (clk),
        .rst        (1'b0),
        .start      (1'b1),
        .pixel      (processed_pixel_color),
        .next_px_num(next_px_num),
        .signal_out (ws2812_dout)
    );

endmodule
