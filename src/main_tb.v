`timescale 1ns/1ps

module main_tb;
    reg clk = 0;
    always #10 clk = ~clk; // 50 MHz

    initial begin
        $dumpfile("main.vcd");
        $dumpvars(0, main_tb);
    end

    initial begin
        repeat (10000) @(posedge clk);
        $finish;
    end
endmodule