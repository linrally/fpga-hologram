module main(
    input  wire clk,         
    input  wire reset,
    input  wire BTNU,
    input  wire break_din,   
    output wire ws2812_dout, 
    output wire [4:0] LED    
);
    //--------------------------------  MAPPER UNIT  --------------------------------
    localparam LED_COUNT  = 52;
    localparam TEX_WIDTH  = 64;
    localparam NUM_FRAMES = 30;  
    localparam FRAME_SIZE = TEX_WIDTH * LED_COUNT; 

    localparam CLK_FREQ = 100_000_000;  
    localparam FPS = 15;
    localparam CYCLES_PER_FRAME = CLK_FREQ / FPS;  // 100M / 15 = 6,666,667

    reg [31:0] frame_timer = 32'd0;
    reg [7:0] frame_idx = 8'd0; 

    always @(posedge clk) begin
        if (frame_timer >= CYCLES_PER_FRAME - 1) begin
            frame_timer <= 32'd0;

            if (frame_idx >= NUM_FRAMES - 1)
                frame_idx <= 8'd0;
            else
                frame_idx <= frame_idx + 1;
        end else begin
            frame_timer <= frame_timer + 1;
        end
    end

    wire break_clean;

    breakbeam_sync_debounce deb (
        .clk      (clk),
        .din_raw  (break_din),
        .din_clean(break_clean)
    );

    wire [5:0] theta; // 6-bit angle (64 steps per revolution)

    theta_from_breakbeam #(
        .THETA_BITS (6),
        .PERIOD_BITS(28) // needs to be large enough to count one revolution in cycles
                         // 2^28 = 268,435,456 cycles = 2.68 seconds @ 100 MHz
    ) angle_gen (
        .clk        (clk),
        .reset      (reset), 
        .break_clean(break_clean),
        .theta      (theta)
    );

    wire [5:0] next_px_num;  // from neopixel_controller: which LED index

    wire [$clog2(TEX_WIDTH)-1:0] col; 
    assign col = theta;  // map theta to column 1 to 1

    wire [23:0] pixel_color;
    wire [$clog2(FRAME_SIZE*NUM_FRAMES)-1:0] rom_addr;

    wire [$clog2(FRAME_SIZE*NUM_FRAMES)-1:0] frame_offset;
    assign frame_offset = frame_idx * FRAME_SIZE;
    assign rom_addr = frame_offset + next_px_num * TEX_WIDTH + col;

    ROM #(.DATA_WIDTH(24), .ADDRESS_WIDTH($clog2(FRAME_SIZE*NUM_FRAMES)), .DEPTH(FRAME_SIZE*NUM_FRAMES), .MEMFILE("texture.mem"))
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
	
	processor CPU(.clock(clk), .reset(reset), 
		.address_imem(instAddr), .q_imem(instData),
									
		.ctrl_writeEnable(rwe),     .ctrl_writeReg(rd),
		.ctrl_readRegA(rs1),     .ctrl_readRegB(rs2), 
		.data_writeReg(rData), .data_readRegA(regA), .data_readRegB(regB),
									
		.wren(mwe), .address_dmem(memAddr), 
		.data(memDataIn), .q_dmem(memDataOut)); 
	
	ROM #(.DATA_WIDTH(32), .ADDRESS_WIDTH(12), .DEPTH(4096), .MEMFILE({INSTR_FILE, ".mem"}))
	InstMem(.clk(clk), 
		.addr(instAddr[11:0]), 
		.dataOut(instData));
	
	regfile RegisterFile(.clock(clk), 
		.ctrl_writeEnable(rwe), .ctrl_reset(reset), 
		.ctrl_writeReg(rd),
		.ctrl_readRegA(rs1), .ctrl_readRegB(rs2), 
		.data_writeReg(rData), .data_readRegA(regA), .data_readRegB(regB));
    
    RAM_MMIO RAM_MMIO(.clk(clk), .wEn(mwe), .addr(memAddr[11:0]), .dataIn(memDataIn), .dataOut(memDataOut), .BTNU(BTNU), .LED(LED));

endmodule