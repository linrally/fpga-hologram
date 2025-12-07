`timescale 1ns/100ps
module register_tb;
	reg clk;
	reg input_enable, output_enable, clr;
	reg [31:0] in;
	wire [32-1:0] out;

	register re(
		.clk(clk),
		.input_enable(input_enable),
		.output_enable(output_enable),
		.clr(clr),
		.in(in),
		.out(out)
	);
	
	initial clk = 0;
	always
		#5 clk = !clk;

	initial begin
		$display(" time | clr in_en out_en | in           | out");
    $monitor("%4t  |  %b    %b     %b   | %h | %h",
             $time, clr, input_enable, output_enable, in, out);

		in = 0;
		clr = 0;
		input_enable = 0;
		output_enable = 0;

		in = 32'hDEADBEEF;
    input_enable = 1;
		#20
    input_enable = 0;

		output_enable = 1;
		#20
		output_enable = 0;
		
		in = 32'hCAFEBABE;
    input_enable = 1;
		#20
    input_enable = 0;

		output_enable = 1;
		#20
		output_enable = 0;

		$finish;
	end
endmodule

