module main(
    input clk,
    output ws2812_dout
);
    localparam LED_COUNT = 8;

    // color order: G R B
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

    reg start = 0;
    reg state = 0;
    wire busy;

    always @(posedge clk) begin
        case (state)
            0: begin
                start <= 0;
                if (!busy) state <= 1;
            end

            1: begin
                start <= 1;
                state <= 0;
            end
        endcase
    end

    ws2812_driver #(.LED_COUNT(LED_COUNT)) ws2812_driver_inst (
        .clk(clk),
        .start(start),
        .reset(1'b0),
        .data(data),
        .dout(ws2812_dout),
        .busy(busy)
    );
endmodule
