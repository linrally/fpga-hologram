module main(
    input  wire clk,         
    input  wire reset,
    input  wire BTNU,
    input  wire break_din,   
    output wire ws2812_dout, 
    output wire [0:0] LED    
);
    //--------------------------------  MAPPER UNIT  --------------------------------
    assign LED = break_din;

    localparam LED_COUNT  = 52;
    localparam TEX_WIDTH  = 256;

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

    // Scale theta (0..63) → column (0..255)
    wire [13:0] theta_scaled = theta * TEX_WIDTH;  // 6+8 bits = 14 bits
    wire [$clog2(TEX_WIDTH)-1:0] col;
    assign col = theta_scaled >> 6;  // divide by 64

    // ROM interface
    wire [23:0] pixel_color;
    wire [$clog2(TEX_WIDTH*LED_COUNT)-1:0] rom_addr;
    assign rom_addr = next_px_num * TEX_WIDTH + col;

    wire [3:0] texture_idx;

    wire [23:0] tex0_data, tex1_data, tex2_data;

    ROM #(.DATA_WIDTH(24), .ADDRESS_WIDTH($clog2(TEX_WIDTH*LED_COUNT)), .DEPTH(TEX_WIDTH*LED_COUNT), .MEMFILE("texture.mem"))
        tex0_rom (.clk(clk), .addr(rom_addr), .dataOut(tex0_data));

    ROM #(.DATA_WIDTH(24), .ADDRESS_WIDTH($clog2(TEX_WIDTH*LED_COUNT)), .DEPTH(TEX_WIDTH*LED_COUNT), .MEMFILE("texture1.mem"))
        tex1_rom (.clk(clk), .addr(rom_addr), .dataOut(tex1_data));
    
    // Is this better than a combinatorial mux?
    reg [23:0] pixel_color_r;
    always @(*) begin
        case (texture_idx)
            4'd0: pixel_color_r = tex0_data;
            4'd1: pixel_color_r = tex1_data;
            default: pixel_color_r = tex0_data; // safe fallback
        endcase
    end
    assign pixel_color = pixel_color_r;

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


	localparam INSTR_FILE = "main.mem";
	
	// Main Processing Unit
	processor CPU(.clock(clock), .reset(reset), 
								
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
	InstMem(.clk(clock), 
		.addr(instAddr[11:0]), 
		.dataOut(instData));
	
	// Register File
	regfile RegisterFile(.clock(clock), 
		.ctrl_writeEnable(rwe), .ctrl_reset(reset), 
		.ctrl_writeReg(rd),
		.ctrl_readRegA(rs1), .ctrl_readRegB(rs2), 
		.data_writeReg(rData), .data_readRegA(regA), .data_readRegB(regB));
						
	wire [31:0] memDataOutRaw;
	// Processor Memory (RAM)
	RAM #(.DATA_WIDTH(32), .ADDRESS_WIDTH(12), .DEPTH(4096)) ProcMem(.clk(clock), 
		.wEn(mwe), 
		.addr(memAddr[11:0]), 
		.dataIn(memDataIn), 
		.dataOut(memDataOutRaw));
	
	MMIO mmio(.addr(memAddr[11:0]), .mwe(mwe), .data(memDataOutRaw), .data_out(memDataOut), .BTNU(BTNU), .texture_idx(texture_idx));

endmodule