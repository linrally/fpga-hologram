module register #(parameter WIDTH = 32) (
	clk,
	input_enable,
	output_enable,
	clr,
	in,
	out
);

	input clk, input_enable, output_enable, clr;
	input [WIDTH - 1:0] in;
	output [WIDTH - 1:0] out;
	wire [WIDTH - 1:0] Qout;

	genvar i;
	generate
		for (i = 0; i < WIDTH; i = i + 1) begin
			dffe_ref dff(.q(Qout[i]), .d(in[i]), .clk(clk), .en(input_enable), .clr(clr));
		end
	endgenerate
	assign out = output_enable ? Qout : {WIDTH{1'bz}};

endmodule
