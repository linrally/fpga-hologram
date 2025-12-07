module or_reduce_32 (A, Y);
	input [31:0] A;
	output Y;

	wire [15:0] l1;
	wire [7:0] l2;
	wire [3:0] l3;
	wire [1:0] l4;

	genvar i;

	generate
		for (i = 0; i < 16; i = i + 1) begin : gen_l1
			or (l1[i], A[2*i], A[2*i+1]);
		end
	endgenerate

	generate
		for (i = 0; i < 8; i = i + 1) begin : gen_l2
			or (l2[i], l1[2*i], l1[2*i+1]);
		end
	endgenerate

	generate
		for (i = 0; i < 4; i = i + 1) begin : gen_l3
			or (l3[i], l2[2*i], l2[2*i+1]);
		end
	endgenerate

	generate
		for (i = 0; i < 2; i = i + 1) begin : gen_l4
			or (l4[i], l3[2*i], l3[2*i+1]);
		end
	endgenerate

	or (Y, l4[0], l4[1]);

endmodule
