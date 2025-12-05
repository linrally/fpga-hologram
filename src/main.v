// Cannot write a testbench for this becuase it mixes Verilog and VHDL
module main(
    input clk,
    output ws2812_dout
);
    reg [23:0] framebuffer [0:7];

    initial begin
        framebuffer[0] = 24'hFF0000;
        framebuffer[1] = 24'h00FF00;
        framebuffer[2] = 24'h0000FF;
        framebuffer[3] = 24'hFF0000;
        framebuffer[4] = 24'h00FF00;
        framebuffer[5] = 24'h0000FF;
        framebuffer[6] = 24'hFF0000;
        framebuffer[7] = 24'h00FF00;
    end

    reg start = 0;
    reg state = 0;

    wire [5:0] next_px_num;

    always @(posedge clk) begin
        case (state)
            0: begin
                start <= 0;
                state <= 1;
            end
            1: begin
                start <= 1;
                state <= 2;
            end
            2: begin
                start <= 0;
            end
        endcase
    end

    neopixel_controller #(
        .px_count_width(6),
        .px_num(8),
        .bits_per_pixel(24)
    ) strip (
        .clk(clk),
        .rst(1'b0),
        .start(start),
        .pixel(framebuffer[next_px_num]), // dynamic pixel feed
        .next_px_num(next_px_num),
        .signal_out(ws2812_dout)
    );
endmodule
