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
                             memDataOut_raw;        // default: RAM

endmodule
