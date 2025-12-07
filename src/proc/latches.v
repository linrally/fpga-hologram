module fd_latch(
    input clk,
    input reset,
    input enable,
    input [31:0] insn_in,
    output [31:0] insn_out
);
    register #(32) fd_insn(.clk(clk), .input_enable(enable), .output_enable(1'b1), .clr(reset), .in(insn_in), .out(insn_out));
endmodule


module dx_latch(
    input clk,
    input reset,
    input enable,
    input [31:0] insn_in,
    input [31:0] A_in,
    input [31:0] B_in,
    output [31:0] insn_out,
    output [31:0] A_out,
    output [31:0] B_out
);
    register #(32) dx_insn(.clk(clk), .input_enable(enable), .output_enable(1'b1), .clr(reset), .in(insn_in), .out(insn_out));
    register #(32) dx_A(.clk(clk), .input_enable(enable), .output_enable(1'b1), .clr(reset), .in(A_in), .out(A_out));
    register #(32) dx_B(.clk(clk), .input_enable(enable), .output_enable(1'b1), .clr(reset), .in(B_in), .out(B_out));
endmodule


module xm_latch(
    input clk,
    input reset,
    input enable,
    input [31:0] insn_in,
    input [31:0] O_in,
    input [31:0] B_in,
    input exception_in,
    output [31:0] insn_out,
    output [31:0] O_out,
    output [31:0] B_out,
    output exception_out
);
    register #(32) xm_insn(.clk(clk), .input_enable(enable), .output_enable(1'b1), .clr(reset), .in(insn_in), .out(insn_out));
    register #(32) xm_O(.clk(clk), .input_enable(enable), .output_enable(1'b1), .clr(reset), .in(O_in), .out(O_out));
    register #(32) xm_B(.clk(clk), .input_enable(enable), .output_enable(1'b1), .clr(reset), .in(B_in), .out(B_out));
    register #(1) xm_exception(.clk(clk), .input_enable(enable), .output_enable(1'b1), .clr(reset), .in(exception_in), .out(exception_out));
endmodule


module mw_latch(
    input clk,
    input reset,
    input [31:0] insn_in,
    input [31:0] O_in,
    input [31:0] D_in,
    input exception_in,
    output [31:0] insn_out,
    output [31:0] O_out,
    output [31:0] D_out,
    output exception_out
);
    register #(32) mw_insn(.clk(clk), .input_enable(1'b1), .output_enable(1'b1), .clr(reset), .in(insn_in), .out(insn_out));
    register #(32) mw_O(.clk(clk), .input_enable(1'b1), .output_enable(1'b1), .clr(reset), .in(O_in), .out(O_out));
    register #(32) mw_D(.clk(clk), .input_enable(1'b1), .output_enable(1'b1), .clr(reset), .in(D_in), .out(D_out));
    register #(1) mw_exception(.clk(clk), .input_enable(1'b1), .output_enable(1'b1), .clr(reset), .in(exception_in), .out(exception_out));
endmodule
