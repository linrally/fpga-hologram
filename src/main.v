// Cannot write a testbench for this becuase it mixes Verilog and VHDL
// Use the Vivado XSIM 
module main(
    input  wire clk,
    output wire ws2812_dout
);

    localparam LED_COUNT  = 48;
    localparam PX_COUNT_WIDTH = 6;

    // Reset tied to ground (always inactive)
    wire reset = 1'b0;

    wire [5:0] next_px_num;
    wire [23:0] pixel_color;

    // Rainbow generator: produces cycling rainbow pattern
    rainbow_generator #(
        .px_num(LED_COUNT),
        .px_count_width(PX_COUNT_WIDTH)
    ) rainbow (
        .clk(clk),
        .reset(reset),
        .next_px_num(next_px_num),
        .pixel_bits(pixel_color)
    );

    // Neopixel controller: drives WS2812B LED strip
    neopixel_controller #(
        .px_count_width(PX_COUNT_WIDTH),
        .px_num(LED_COUNT),
        .bits_per_pixel(24),
        .one_high_time(80),
        .zero_high_time(40)
    ) strip (
        .clk(clk),
        .rst(reset),
        .start(1'b1),
        .pixel(pixel_color),
        .next_px_num(next_px_num),
        .signal_out(ws2812_dout)
    );

endmodule
