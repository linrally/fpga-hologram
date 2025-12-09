/*
1000: BTNU (R)
1001: LED[4:0] (RW)
1002: brightness[1:0] (RW)
1003: BTND (R)
1004: invert (RW)
*/

module RAM_MMIO(
    input  wire clk,
    input  wire wEn,
    input  wire [11:0] addr,
    input  wire [31:0] dataIn,
    output wire [31:0] dataOut,
    input  wire BTNU,
    input  wire BTND,
    output wire [4:0] LED,
    output wire [1:0] brightness,
    output wire invert
);

    wire [31:0] memDataOut_raw;

    RAM #(
        .DATA_WIDTH(32),
        .ADDRESS_WIDTH(12),
        .DEPTH(4096)
    ) ProcMem (
        .clk (clk),
        .wEn (wEn),
        .addr (addr),
        .dataIn (dataIn),
        .dataOut (memDataOut_raw)
    );

    reg [4:0] led_reg = 5'd0;
    reg [1:0] brightness_reg = 2'd0;
    reg invert_reg = 1'd0;

    always @(posedge clk) begin
        if (wEn && addr == 12'd1001)
            led_reg <= dataIn[4:0];
        if (wEn && addr == 12'd1002)
            brightness_reg <= dataIn[1:0];
        if (wEn && addr == 12'd1004)
            invert_reg <= dataIn[0];
    end

    assign LED = led_reg;
    assign brightness = brightness_reg;
    assign invert = invert_reg;

    assign dataOut =
        (addr == 12'd1000) ? {31'd0, BTNU}:
        (addr == 12'd1001) ? {27'd0, led_reg}:
        (addr == 12'd1002) ? {30'd0, brightness_reg}:
        (addr == 12'd1003) ? {31'd0, BTND}:
        (addr == 12'd1004) ? {31'd0, invert_reg}:
                             memDataOut_raw;       // default: RAM

endmodule
