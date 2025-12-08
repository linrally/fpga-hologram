module main(
    input  wire clk,         
    input  wire reset,
    input  wire BTNU,        // existing button: texture cycle
    input  wire BTN_INV,     // new button: color invert toggle
    input  wire BTN_BRT,     // new button: brightness preset step
    input  wire break_din,   
    output wire ws2812_dout, 
    output wire [4:0] LED    
);

    localparam LED_COUNT  = 52;
    localparam TEX_WIDTH  = 128;
    localparam NUM_TEXTURES = 3;
    localparam TOTAL_TEX_WIDTH = TEX_WIDTH * NUM_TEXTURES;

    wire break_clean;

    // Sync and debounce breakbeam sensor input
    breakbeam_sync_debounce deb (
        .clk      (clk),
        .din_raw  (break_din),
        .din_clean(break_clean)
    );

    wire [5:0] theta;  // 0-63 angle steps per rotation

    // Track rotation angle from breakbeam pulses
    theta_from_breakbeam #(
        .THETA_BITS (6),
        .PERIOD_BITS(28)
    ) angle_gen (
        .clk        (clk),
        .reset      (1'b0),
        .break_clean(break_clean),
        .theta      (theta)
    );

    wire [5:0] next_px_num;  // which LED we're updating

    // Map angle (0-63) to texture column (0-127)
    wire [13:0] theta_scaled = theta * TEX_WIDTH;
    wire [$clog2(TEX_WIDTH)-1:0] col;
    assign col = theta_scaled >> 6;  // divide by 64

    wire [3:0] texture_idx;  // CPU selects which texture (0-2)
    wire [13:0] texture_offset = texture_idx * TEX_WIDTH;
    // Address = row * total_width + column + texture_start_offset
    wire [$clog2(TOTAL_TEX_WIDTH*LED_COUNT)-1:0] rom_addr;
    assign rom_addr = next_px_num * TOTAL_TEX_WIDTH + col + texture_offset;

    wire [23:0] pixel_color;  // raw pixel from ROM
    wire [23:0] pixel_color_adj;  // after brightness/invert
    ROM #(.DATA_WIDTH(24), .ADDRESS_WIDTH($clog2(TOTAL_TEX_WIDTH*LED_COUNT)), .DEPTH(TOTAL_TEX_WIDTH*LED_COUNT), .MEMFILE("texture.mem"))
        tex0_rom (.clk(clk), .addr(rom_addr), .dataOut(pixel_color));

    wire [3:0] brightness_level;  // from CPU via MMIO
    wire       invert_flag;       // from CPU via MMIO
    wire [1:0] br_shift = brightness_level[1:0];  // shift amount for brightness

    // Extract RGB from GRB format (WS2812 uses GRB)
    wire [7:0] r_in = pixel_color[15:8];
    wire [7:0] g_in = pixel_color[23:16];
    wire [7:0] b_in = pixel_color[7:0];

    // Invert colors if flag is set
    wire [7:0] r_sel = invert_flag ? ~r_in : r_in;
    wire [7:0] g_sel = invert_flag ? ~g_in : g_in;
    wire [7:0] b_sel = invert_flag ? ~b_in : b_in;

    // Apply brightness by right-shifting (0=full, 1=half, 2=quarter, 3=eighth)
    wire [7:0] r_out = r_sel >> br_shift;
    wire [7:0] g_out = g_sel >> br_shift;
    wire [7:0] b_out = b_sel >> br_shift;

    assign pixel_color_adj = {g_out, r_out, b_out};  // back to GRB format

    // WS2812B LED driver - handles timing-critical serial protocol
    neopixel_controller #(
        .px_count_width (6),
        .px_num         (LED_COUNT),
        .bits_per_pixel (24)
    ) strip (
        .clk        (clk),
        .rst        (1'b0),
        .start      (1'b1),
        .pixel      (pixel_color_adj),
        .next_px_num(next_px_num),  // tells us which LED we're updating
        .signal_out (ws2812_dout)
    );

    // CPU interface signals
    wire rwe, mwe;  // register write enable, memory write enable
	wire[4:0] rd, rs1, rs2;  // register addresses
	wire[31:0] instAddr, instData, 
		rData, regA, regB,
		memAddr, memDataIn, memDataOut;

	localparam INSTR_FILE = "main";
	
	// 5-stage pipelined CPU
	processor CPU(.clock(clk), .reset(reset), 
		.address_imem(instAddr), .q_imem(instData),
		.ctrl_writeEnable(rwe), .ctrl_writeReg(rd),
		.ctrl_readRegA(rs1), .ctrl_readRegB(rs2), 
		.data_writeReg(rData), .data_readRegA(regA), .data_readRegB(regB),
		.wren(mwe), .address_dmem(memAddr), 
		.data(memDataIn), .q_dmem(memDataOut)); 
	
	// Instruction memory (ROM) - holds assembly program
	ROM #(.DATA_WIDTH(32), .ADDRESS_WIDTH(12), .DEPTH(4096), .MEMFILE({INSTR_FILE, ".mem"}))
	InstMem(.clk(clk), 
		.addr(instAddr[11:0]), 
		.dataOut(instData));
	
	// Register file - CPU's 32 registers
	regfile RegisterFile(.clock(clk), 
		.ctrl_writeEnable(rwe), .ctrl_reset(reset), 
		.ctrl_writeReg(rd),
		.ctrl_readRegA(rs1), .ctrl_readRegB(rs2), 
		.data_writeReg(rData), .data_readRegA(regA), .data_readRegB(regB));
    
    // Memory-mapped I/O - CPU reads buttons, writes texture/brightness/invert
    RAM_MMIO RAM_MMIO(
        .clk(clk),
        .wEn(mwe),
        .addr(memAddr[11:0]),
        .dataIn(memDataIn),
        .dataOut(memDataOut),
        .BTNU(BTNU),
        .BTN_INV(BTN_INV),
        .BTN_BRT(BTN_BRT),
        .LED(LED),
        .texture_idx(texture_idx),        // CPU writes this
        .brightness_level(brightness_level),  // CPU writes this
        .invert_flag(invert_flag)         // CPU writes this
    );

endmodule