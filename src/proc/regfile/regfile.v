module regfile (
	clock,
	ctrl_writeEnable, ctrl_reset, ctrl_writeReg,
	ctrl_readRegA, ctrl_readRegB, data_writeReg,
	data_readRegA, data_readRegB
);

	input clock, ctrl_writeEnable, ctrl_reset;
	input [4:0] ctrl_writeReg, ctrl_readRegA, ctrl_readRegB;
	input [31:0] data_writeReg;

	output [31:0] data_readRegA, data_readRegB;

	wire [31:0] reg_out [31:0];   

	wire [31:0] write_ohot;
	wire [31:0] read_A_ohot;
	wire [31:0] read_B_ohot;

	assign write_ohot = 32'b1 << ctrl_writeReg;
	assign read_A_ohot = 32'b1 << ctrl_readRegA;
	assign read_B_ohot = 32'b1 << ctrl_readRegB;

	assign reg_out[0] = 32'b0;

	genvar i;
	generate
		for (i = 1; i < 32; i = i + 1) begin
			register r (
				.clk(clock),
				.input_enable(ctrl_writeEnable ? write_ohot[i] : 1'b0),
				.output_enable(1'b1),
				.clr(ctrl_reset),
				.in(data_writeReg),
				.out(reg_out[i])
			);
		end
	endgenerate

	generate
		for (i = 0; i < 32; i = i + 1) begin
			assign data_readRegA = read_A_ohot[i] ? reg_out[i] : 32'bz;
			assign data_readRegB = read_B_ohot[i] ? reg_out[i] : 32'bz;
		end
	endgenerate

endmodule
