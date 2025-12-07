module code_selector (
    input [31:0] multiplicand,
    input [2:0]  booth_code,
    output [32:0] alu_out
);
	wire signed [32:0] M = {multiplicand[31], multiplicand};
	wire signed [32:0] Mx2 = M <<< 1;
	wire signed [32:0] neg_M = -M;
	wire signed [32:0] neg_Mx2= -Mx2;

	mux_8 #(.WIDTH(33)) mux_inst (
		.out(alu_out),
		.select(booth_code),
		.in0(33'd0), // 000 0
		.in1(M),     // 001 +M
		.in2(M),     // 010 +M
		.in3(Mx2),   // 011 +2M
		.in4(neg_Mx2),// 100 -2M
		.in5(neg_M), // 101 -M
		.in6(neg_M), // 110 -M
		.in7(33'd0)  // 111 0
	);
endmodule

module cla_33 (
	input [32:0] A,
	input [32:0] B,
	input Cin,
	output [32:0] S,
	output Cout
);
	wire [31:0] sum_lower;
	wire carry_lower;
	wire sum_msb;
	wire carry_msb;

	cla_32 add_lower (
		.A(A[31:0]),
		.B(B[31:0]),
		.Cin(Cin),
		.S(sum_lower),
		.Cout(carry_lower)
	);

	full_adder add_msb (
		.S(sum_msb),
		.Cout(carry_msb),
		.A(A[32]),
		.B(B[32]),
		.Cin(carry_lower)
	);

	assign S = {sum_msb, sum_lower};
	assign Cout = carry_msb;

endmodule

module booth (
	input clock,
	input ctrl_MULT,
	input [31:0] A, B,
	output [31:0] P,
	output data_resultRDY,
	output data_exception
);
	wire [7:0] counter_cur, counter_next, counter_inc;
	wire done = (counter_cur[5:0] == 6'd16);

	register #(8) counter (
		.clk(clock),
		.input_enable(1'b1),
		.output_enable(1'b1),
		.clr(ctrl_MULT),
		.in(counter_next),
		.out(counter_cur)
	);

	cla_8 counter_adder (
		.A(counter_cur),
		.B(8'b00000001),
		.Cin(1'b0),
		.S(counter_inc),
		.Cout()
	);

	assign counter_next = counter_inc;
	wire init = (counter_cur[5:0] == 6'd0);

	wire [65:0] product_cur, product_next;

	register #(66) product_reg (
		.clk(clock),
		.input_enable(1'b1),
		.output_enable(1'b1),
		.clr(ctrl_MULT),
		.in(product_next),
		.out(product_cur)
	);

	wire [2:0] booth_code = product_cur[2:0];
	wire [32:0] booth_val;

	code_selector cs (
		.multiplicand(A),
		.booth_code(booth_code),
		.alu_out(booth_val)
	);

	
	wire [32:0] upper_sum;
	wire [32:0] upper_cur = product_cur[65:33];
	cla_33 add_upper (
		.A(upper_cur),
		.B(booth_val),
		.Cin(1'b0),
		.S(upper_sum),
		.Cout()
	);

	wire [65:0] shifted;
	wire signed [65:0] prodsum = {upper_sum, product_cur[32:0]};
	assign shifted = prodsum >>> 2;

	assign product_next = init ? {33'b0, B, 1'b0} : shifted;

	assign P = product_next[32:1];  

	wire overflow = |(product_next[64:33] ^ {32{product_next[32]}});
	assign data_exception = done && overflow;

	assign data_resultRDY = done;
endmodule
