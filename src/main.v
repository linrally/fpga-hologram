module main(
    input clk,
    output ws2812_dout
);
    localparam LED_COUNT = 8;
		reg [LED_COUNT*24-1:0] data = {
			24'hFF0000, // 7
			24'h00FF00, 
			24'h0000FF, 
			24'hFFFFFF, 
			24'h000000, 
			24'h000000, 
			24'h000000, 
			24'h000000 	// 0
		};
    /*
		RAM #(.DATA_WIDTH(24), .ADDRESS_WIDTH(8), .DEPTH(LED_COUNT), .MEMFILE("data.mem")) ram_inst (
        .clk(clk),
        .wEn(1'b1),
        .addr(8'd0),
        .dataIn(24'hFF0000),
        .dataOut(data)
    );
		*/

    ws2812_driver #(.LED_COUNT(LED_COUNT)) ws2812_driver_inst (
        .clk(clk),
        .start(1'b1),
        .reset(1'b0),
        .data(data),
        .dout(ws2812_dout),
        .busy()
    );
endmodule
