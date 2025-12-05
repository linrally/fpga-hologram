`timescale 1ns/1ps

module main_tb;
    reg clk = 0;
    always #10 clk = ~clk; // 50 MHz

    initial begin
        $dumpfile("sim/main_tb.vcd");
        $dumpvars(0, main_tb);
    end

    wire ws2812_dout;

    main dut (
        .clk(clk),
        .ws2812_dout(ws2812_dout)
    );

    initial begin
        repeat (10000) @(posedge clk);
        $finish;
    end
endmodule