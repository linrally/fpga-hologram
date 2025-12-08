// XSIM

`timescale 1ns/1ps

module main_tb;
    reg clk = 0;
    wire ws2812_dout;

    main dut(.clk(clk), .ws2812_dout(ws2812_dout));

    wire[5:0] theta = dut.theta;
    wire [23:0] pixel_color = dut.pixel_color;

    always #5 clk = ~clk;

    initial begin
        forever @(posedge clk);
    end
endmodule