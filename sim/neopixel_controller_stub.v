// Minimal stub for VHDL neopixel_controller. Allows iverilog to compile without errors.

module neopixel_controller #(
    parameter px_count_width = 6,
    parameter px_num         = 60,
    parameter bits_per_pixel = 24,
    parameter one_high_time  = 80,
    parameter zero_high_time = 40
)(
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     start,
    input  wire [bits_per_pixel-1:0] pixel,
    output wire [px_count_width-1:0] next_px_num,
    output wire                     signal_out
);

endmodule