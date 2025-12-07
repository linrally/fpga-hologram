module multdiv(
	data_operandA, data_operandB, 
	ctrl_MULT, ctrl_DIV, 
	clock, 
	data_result, data_exception, data_resultRDY);

	input [31:0] data_operandA, data_operandB;
	input ctrl_MULT, ctrl_DIV, clock;

	output [31:0] data_result;
	output data_exception, data_resultRDY;

	wire [31:0] mult_result;
	wire [31:0] div_result;
	wire mult_ready, div_ready;
	wire mult_exception, div_exception;

	wire op_select_out;
	register #(1) op (
		.clk(clock),
		.input_enable(1'b1),
		.output_enable(1'b1),
		.clr(1'b0),
		.in(ctrl_MULT | (op_select_out & ~ctrl_DIV)),
		.out(op_select_out)
	);

	booth bm (
		.clock(clock),
		.A(data_operandA),
		.B(data_operandB),
		.P(mult_result),
		.ctrl_MULT(ctrl_MULT),
		.data_resultRDY(mult_ready),
		.data_exception(mult_exception)
	);

	nonrestoring rs(
		.clock(clock),
		.A(data_operandA),
		.V(data_operandB),
		.Q(div_result),
		.R(),
		.ctrl_DIV(ctrl_DIV),
		.data_resultRDY(div_ready),
		.data_exception(div_exception)
	);

	assign data_result = op_select_out ? mult_result : div_result;
	assign data_resultRDY = op_select_out ? mult_ready : div_ready;
	assign data_exception = op_select_out ? mult_exception : div_exception;

endmodule
