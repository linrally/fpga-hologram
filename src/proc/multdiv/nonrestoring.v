module nonrestoring ( 
    input clock,
    input [31:0] A,               
    input [31:0] V,               
    output [31:0] Q,               
    output [31:0] R,               
    input ctrl_DIV,        
    output data_resultRDY,  
    output data_exception   
);
	wire [31:0] A_neg, V_neg;
	cla_32 add_neg_A(
		.A(~A),
		.B(32'b1),
		.Cin(1'b0),
		.S(A_neg),
		.Cout()
	);
	cla_32 add_neg_V(
		.A(~V),
		.B(32'b1),
		.Cin(1'b0),
		.S(V_neg),
		.Cout()
	);

	wire [31:0] A_abs = A[31] ? (A_neg) : A;
	wire [31:0] V_abs = V[31] ? (V_neg) : V;

	wire [7:0] counter_cur, counter_next;
	wire done = (counter_cur[5:0] == 6'd32);

	register #(8) counter (
		.clk(clock),
		.input_enable(1'b1),
		.output_enable(1'b1),
		.clr(ctrl_DIV),
		.in(counter_next),
		.out(counter_cur)
	);

	cla_8 counter_adder (
		.A(counter_cur),
		.B(8'b00000001),
		.Cin(1'b0),
		.S(counter_next),
		.Cout()
	);

	wire init = (counter_cur[5:0] == 6'd0);

	wire [63:0] rq_cur, rq_next;

	register #(64) rq_reg (
		.clk(clock),
		.input_enable(1'b1),
		.output_enable(1'b1),
		.clr(ctrl_DIV),
		.in(rq_next),
		.out(rq_cur)
	);

	wire [63:0] rq_shift = rq_cur << 1; // Shift left RQ

	wire[31:0] V_abs_neg;
	cla_32 add_neg_V_abs( // This could be replaced with a conditional to reduce gates
		.A(~V_abs),
		.B(32'b1),
		.Cin(1'b0),
		.S(V_abs_neg),
		.Cout()
	);

	wire [31:0] R_add, R_sub;
	cla_32 add_r (.A(rq_shift[63:32]), .B(V_abs), .Cin(1'b0), .S(R_add), .Cout()); // If MSB of old R = 1, R = R + V
	cla_32 sub_r (.A(rq_shift[63:32]), .B(V_abs_neg), .Cin(1'b0), .S(R_sub), .Cout()); // If MSB of old R = 0, R = R - V
	wire [31:0] R_next = rq_cur[63] ? R_add : R_sub;
	
	wire [31:0] Q_next = {rq_cur[30:0], R_next[31] ? 1'b0 : 1'b1}; // If MSB of new R = 0, Q[0] = 1. If 1, Q[0] = 0

	assign rq_next = init ? {32'b0, A_abs} : {R_next, Q_next};

	// final iteration correction
	// wire [31:0] R_adjust;
	// cla_32 add_r_adjust (.A(rq_next[63:32]), .B(V), .Cin(1'b0), .S(R_adjust), .Cout()); // If MSB of old R = 1, R = R + V
	// wire [63:0] rq_adjust;
	// assign rq_adjust = {R_adjust, rq[31:0]};
	
	wire [31:0] Q_neg, Q_signed;
	cla_32 add_neg_q(
		.A(~Q_next),
		.B(32'b1),
		.Cin(1'b0),
		.S(Q_neg),
		.Cout()
	);

	mux_4 #(32) m4(
		.out(Q_signed),
		.select({A[31], V[31]}),
		.in0(Q_next),	
		.in1(Q_neg),
		.in2(Q_neg),
		.in3(Q_next)
	);
	
	// exception
	wire div0 = ~|V;
	assign data_exception = done && div0;

	assign Q = data_exception ? 32'b0 : Q_signed;
	
	assign data_resultRDY = done;

endmodule

