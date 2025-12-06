// Cannot write a testbench for this becuase it mixes Verilog and VHDL
// Use the Vivado XSIM 
module main(
    input  wire clk,
    output wire ws2812_dout
);

    localparam LED_COUNT  = 32;
    localparam TEX_WIDTH  = 256;

    reg [5:0] theta = 0;

    wire [5:0] next_px_num;

    wire [$clog2(TEX_WIDTH)-1:0] col;
    assign col = (theta * TEX_WIDTH) >> 6;

    wire [23:0] pixel_color;
    wire [$clog2(TEX_WIDTH*LED_COUNT)-1:0] rom_addr;
    assign rom_addr = next_px_num * TEX_WIDTH + col;

    ROM #(
        .DATA_WIDTH(24),
        .ADDRESS_WIDTH($clog2(TEX_WIDTH*LED_COUNT)),
        .DEPTH(TEX_WIDTH*LED_COUNT),
        .MEMFILE("texture.mem")
    ) rom (
        .clk(clk),
        .addr(rom_addr),
        .dataOut(pixel_color)
    );

    neopixel_controller #(
        .px_count_width(6),
        .px_num(LED_COUNT),
        .bits_per_pixel(24)
    ) strip (
        .clk(clk),
        .rst(1'b0),
        .start(1'b1),
        .pixel(pixel_color),
        .next_px_num(next_px_num),
        .signal_out(ws2812_dout)
    );

    reg [31:0] timer = 0;

    always @(posedge clk) begin
        if (timer < 100_000_00) // 10ms
            timer <= timer + 1;
        else begin
            timer <= 0;
            theta <= theta + 1;
        end
    end

endmodule
