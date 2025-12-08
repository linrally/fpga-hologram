module main(
    input  wire clk,         
    input  wire reset,
    input  wire BTNU,
    input  wire break_din,   
    output wire ws2812_dout, 
    output wire [4:0] LED    
);
    //--------------------------------  MAPPER UNIT  --------------------------------
    //assign LED[0] = break_din;

    localparam LED_COUNT  = 52;
    localparam TEX_WIDTH  = 128;  // Width per texture (changed from 256 to 128)
    localparam NUM_TEXTURES = 3;  // Number of textures in texture.mem (duke, globe, gradient)
    localparam TOTAL_TEX_WIDTH = TEX_WIDTH * NUM_TEXTURES;  // Total width: 384

    wire break_clean;

    breakbeam_sync_debounce deb (
        .clk      (clk),
        .din_raw  (break_din),
        .din_clean(break_clean)
    );

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

    wire [5:0] next_px_num;  // from neopixel_controller: which LED index

    // Scale theta (0..63) → column (0..127) within selected texture
    wire [13:0] theta_scaled = theta * TEX_WIDTH;  // 6+7 bits = 13 bits
    wire [$clog2(TEX_WIDTH)-1:0] col;
    assign col = theta_scaled >> 6;  // divide by 64

    // Texture selection from CPU (via MMIO)
    wire [3:0] texture_idx;

    // ROM address calculation with texture offset
    // rom_addr = row * TOTAL_TEX_WIDTH + col + (texture_idx * TEX_WIDTH)
    // This selects the correct texture column range
    wire [13:0] texture_offset = texture_idx * TEX_WIDTH;  // Offset to texture start column
    wire [$clog2(TOTAL_TEX_WIDTH*LED_COUNT)-1:0] rom_addr;
    assign rom_addr = next_px_num * TOTAL_TEX_WIDTH + col + texture_offset;

    // ROM interface - total size is 640×52 = 33,280 pixels
    wire [23:0] pixel_color;
    ROM #(.DATA_WIDTH(24), .ADDRESS_WIDTH($clog2(TOTAL_TEX_WIDTH*LED_COUNT)), .DEPTH(TOTAL_TEX_WIDTH*LED_COUNT), .MEMFILE("texture.mem"))
        tex0_rom (.clk(clk), .addr(rom_addr), .dataOut(pixel_color));

    neopixel_controller #(
        .px_count_width (6),
        .px_num         (LED_COUNT),
        .bits_per_pixel (24)
    ) strip (
        .clk        (clk),
        .rst        (1'b0),
        .start      (1'b1),
        .pixel      (pixel_color),
        .next_px_num(next_px_num),
        .signal_out (ws2812_dout)
    );

    //--------------------------------  PROCESSOR  --------------------------------
    wire rwe, mwe;
	wire[4:0] rd, rs1, rs2;
	wire[31:0] instAddr, instData, 
		rData, regA, regB,
		memAddr, memDataIn, memDataOut;


	localparam INSTR_FILE = "main";
	
	// Main Processing Unit
	processor CPU(.clock(clk), .reset(reset), 
								
		// ROM
		.address_imem(instAddr), .q_imem(instData),
									
		// Regfile
		.ctrl_writeEnable(rwe),     .ctrl_writeReg(rd),
		.ctrl_readRegA(rs1),     .ctrl_readRegB(rs2), 
		.data_writeReg(rData), .data_readRegA(regA), .data_readRegB(regB),
									
		// RAM
		.wren(mwe), .address_dmem(memAddr), 
		.data(memDataIn), .q_dmem(memDataOut)); 
	
	// Instruction Memory (ROM)
	ROM #(.DATA_WIDTH(32), .ADDRESS_WIDTH(12), .DEPTH(4096), .MEMFILE({INSTR_FILE, ".mem"}))
	InstMem(.clk(clk), 
		.addr(instAddr[11:0]), 
		.dataOut(instData));
	
	// Register File
	regfile RegisterFile(.clock(clk), 
		.ctrl_writeEnable(rwe), .ctrl_reset(reset), 
		.ctrl_writeReg(rd),
		.ctrl_readRegA(rs1), .ctrl_readRegB(rs2), 
		.data_writeReg(rData), .data_readRegA(regA), .data_readRegB(regB));
    
    RAM_MMIO RAM_MMIO(.clk(clk), .wEn(mwe), .addr(memAddr[11:0]), .dataIn(memDataIn), .dataOut(memDataOut), .BTNU(BTNU), .LED(LED), .texture_idx(texture_idx));

endmodule