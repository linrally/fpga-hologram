`timescale 1ns/1ps

module main_tb;
    reg clk = 0;
    wire ws2812_dout;

    main dut(.clk(clk), .ws2812_dout(ws2812_dout));

    always #5 clk = ~clk;

    initial begin
        forever @(posedge clk);
    end
endmodule