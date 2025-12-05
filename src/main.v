// Cannot write a testbench for this becuase it mixes Verilog and VHDL
// Use the Vivado XSIM 
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

    wire [5:0] next_px_num;

    neopixel_controller #(
        .px_count_width(6),
        .px_num(8),
        .bits_per_pixel(24)
    ) strip (
        .clk(clk),
        .rst(1'b0),
        .start(1'b1),
        .pixel(framebuffer[next_px_num]), // dynamic pixel feed
        .next_px_num(next_px_num),
        .signal_out(ws2812_dout)
    );
endmodule
