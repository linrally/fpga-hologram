module RAM_MMIO(
    input  wire        clk,
    input  wire        wEn,
    input  wire [11:0] addr,
    input  wire [31:0] dataIn,
    output wire [31:0] dataOut,
    input  wire        BTNU,
    input  wire        BTN_INV,
    input  wire        BTN_BRT,
    output wire [4:0]  LED,
    output wire [3:0]  texture_idx,
    output wire [3:0]  brightness_level,
    output wire        invert_flag
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
    reg [3:0] texture_idx_reg = 4'd0;
    reg [3:0] brightness_reg = 4'd0; // 0..15 brightness preset
    reg       invert_reg     = 1'b0; // color invert toggle

    always @(posedge clk) begin
        if (wEn && addr == 12'd1001) begin
            led_reg <= dataIn[4:0];
            texture_idx_reg <= dataIn[3:0];  // texture_idx is bits [3:0]
        end
        if (wEn && addr == 12'd1004) begin
            brightness_reg <= dataIn[3:0];   // brightness preset write
        end
        if (wEn && addr == 12'd1005) begin
            invert_reg <= dataIn[0];         // invert flag write
        end
    end

    assign LED = led_reg;
    assign texture_idx = texture_idx_reg;
    assign brightness_level = brightness_reg;
    assign invert_flag = invert_reg;

    assign dataOut =
        (addr == 12'd1000) ? {31'd0, BTNU}               : // BTNU at bit 0
        (addr == 12'd1001) ? {27'd0, led_reg}            : // LED/texture_idx register readback
        (addr == 12'd1002) ? {31'd0, BTN_INV}            : // invert button state
        (addr == 12'd1003) ? {31'd0, BTN_BRT}            : // brightness button state
        (addr == 12'd1004) ? {28'd0, brightness_reg}     : // brightness preset readback
        (addr == 12'd1005) ? {31'd0, invert_reg}         : // invert flag readback
                             memDataOut_raw;                // default: RAM

endmodule
