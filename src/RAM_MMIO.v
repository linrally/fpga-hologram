module RAM_MMIO(
    input  wire        clk,
    input  wire        wEn,
    input  wire [11:0] addr,
    input  wire [31:0] dataIn,
    output wire [31:0] dataOut,
    input  wire        BTNU,
    output wire [4:0]  LED,
    output wire [7:0]  frame_idx  // current animation frame
);

    wire [31:0] memDataOut_raw;

    RAM #(
        .DATA_WIDTH(32),
        .ADDRESS_WIDTH(12),
        .DEPTH(4096)
    ) ProcMem (
        .clk     (clk),
        .wEn     (wEn),
        .addr    (addr),
        .dataIn  (dataIn),
        .dataOut (memDataOut_raw)
    );

    reg [4:0] led_reg = 5'd0;
    reg [7:0] frame_reg = 8'd0;  // animation frame index

    // 24 fps timer: generates a flag every 1/24 second
    localparam CLK_FREQ = 100_000_000;  // 100 MHz clock
    localparam FPS = 24;
    localparam CYCLES_PER_FRAME = CLK_FREQ / FPS;  // 100M / 24 = 4,166,667

    reg [31:0] frame_timer = 32'd0;
    reg frame_tick = 1'b0;  // pulses high for one cycle every frame period

    always @(posedge clk) begin
        if (frame_timer >= CYCLES_PER_FRAME - 1) begin
            frame_timer <= 32'd0;
            frame_tick <= 1'b1;
        end else begin
            frame_timer <= frame_timer + 1;
            frame_tick <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (wEn && addr == 12'd1001)
            led_reg <= dataIn[4:0];
        if (wEn && addr == 12'd1002)
            frame_reg <= dataIn[7:0];
    end

    assign LED = led_reg;
    assign frame_idx = frame_reg;

    assign dataOut =
        (addr == 12'd1000) ? {31'd0, BTNU}       : // BTNU at bit 0
        (addr == 12'd1001) ? {27'd0, led_reg}    : // LED register readback
        (addr == 12'd1002) ? {24'd0, frame_reg}  : // frame index readback
        (addr == 12'd1003) ? {31'd0, frame_tick} : // 24 fps timer tick
                             memDataOut_raw;        // default: RAM

endmodule
