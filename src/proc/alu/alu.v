module alu(data_operandA, data_operandB, ctrl_ALUopcode, ctrl_shiftamt, data_result, isNotEqual, isLessThan, overflow);
        
    input [31:0] data_operandA, data_operandB;
    input [4:0] ctrl_ALUopcode, ctrl_shiftamt;

    output [31:0] data_result;
    output isNotEqual, isLessThan, overflow;

	wire add_sub;
	wire [31:0] sel_B, not_B;
	assign add_sub = ctrl_ALUopcode[0];
	not_32 nB(
		.A(data_operandB),
		.Y(not_B)
	);
	mux_2 #(32) m2_B(
		.out(sel_B),
		.select(add_sub),
		.in0(data_operandB),
		.in1(not_B)
	);

	wire [31:0] add_sub_result;
	cla_32 cla(
		.A(data_operandA),
		.B(sel_B),
		.Cin(add_sub),
		.S(add_sub_result),
		.Cout() // other operations are agnostic to this value
	);

	// two ways of detecting overflow
	// 1. Cin =/ Cout of MSB (31st full adder, more difficult for CLA)
	// 2. signs of inputs are equal and differ from sign of result
	wire signs_equal, result_not_equal;
	xnor(signs_equal, data_operandA[31], sel_B[31]);
	xor(result_not_equal, data_operandA[31], add_sub_result[31]);
	and(overflow, signs_equal, result_not_equal);

	wire [31:0] and_result;
	and_32 aAB(
		.A(data_operandA),
		.B(data_operandB),
		.Y(and_result)
	);
	
	wire [31:0] or_result;
	or_32 oAB(
		.A(data_operandA),
		.B(data_operandB),
		.Y(or_result)
	);
	
	or_reduce_32 ore(.A(add_sub_result), .Y(isNotEqual));

	// no overflow, positive -> not less than
	// no overflow, negative -> less than
	// overflow, positive -> less than
	// overflow, negative -> not less than
	xor (isLessThan, overflow, add_sub_result[31]);

	wire [31:0] sll_result;
	sll_barrel_32 sll(
		.A(data_operandA),
		.shamt(ctrl_shiftamt),
		.Y(sll_result)
	);

	wire [31:0] sra_result;
	sra_barrel_32 sra(
		.A(data_operandA),
		.shamt(ctrl_shiftamt),
		.Y(sra_result)
	);

	mux_8 #(32) m8_res( // only need 32 because first bit of every opcode is 0
		.out(data_result),
		.select(ctrl_ALUopcode[2:0]),
		.in0(add_sub_result),
		.in1(add_sub_result),
		.in2(and_result),
		.in3(or_result),
		.in4(sll_result),
		.in5(sra_result),
		.in6(32'b0),
		.in7(32'b0)
	);

endmodule
