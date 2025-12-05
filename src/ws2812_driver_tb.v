// TODO: may be helpful to add a test reciever to check the bitstream
`timescale 1ns/1ps

module ws2812_driver_tb;

    localparam LED_COUNT = 8;

    reg clk = 0;
    reg reset = 0;
    reg start = 0;
    reg [LED_COUNT*24-1:0] data = {
        24'hFF0000,
        24'h00FF00,
        24'h0000FF,
        24'hFF0000,
        24'h00FF00,
        24'h0000FF,
        24'hFF0000,
        24'h00FF00
    };
    integer i;

    wire dout;
    wire busy;

    ws2812_driver #(.LED_COUNT(LED_COUNT)) dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .data(data),
        .dout(dout),
        .busy(busy)
    );

    always #10 clk = ~clk; // 50 MHz

    initial begin
        $dumpfile("sim/ws2812_driver_tb.vcd");
        $dumpvars(0, ws2812_driver_tb);
    end

    initial begin
        start = 1;
        @(posedge clk);   
        @(posedge clk); // only holding high for one cycle leads to hanging
        start = 0;

        wait (busy == 1);
        wait (busy == 0);

        repeat (20) @(posedge clk);

        start = 1;
        @(posedge clk);
        @(posedge clk);
        start = 0;

        wait (busy == 1);
        wait (busy == 0);

        repeat (20) @(posedge clk);

        $finish;
    end

endmodule
