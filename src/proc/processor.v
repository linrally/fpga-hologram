/**
 * READ THIS DESCRIPTION!
 *
 * This is your processor module that will contain the bulk of your code submission. You are to implement
 * a 5-stage pipelined processor in this module, accounting for hazards and implementing bypasses as
 * necessary.
 *
 * Ultimately, your processor will be tested by a master skeleton, so the
 * testbench can see which controls signal you active when. Therefore, there needs to be a way to
 * "inject" imem, dmem, and regfile interfaces from some external controller module. The skeleton
 * file, Wrapper.v, acts as a small wrapper around your processor for this purpose. Refer to Wrapper.v
 * for more details.
 *
 * As a result, this module will NOT contain the RegFile nor the memory modules. Study the inputs 
 * very carefully - the RegFile-related I/Os are merely signals to be sent to the RegFile instantiated
 * in your Wrapper module. This is the same for your memory elements. 
 *
 *
 */
module processor(
    // Control signals
    clock,                          // I: The master clock
    reset,                          // I: A reset signal

    // Imem
    address_imem,                   // O: The address of the data to get from imem
    q_imem,                         // I: The data from imem

    // Dmem
    address_dmem,                   // O: The address of the data to get or put from/to dmem
    data,                           // O: The data to write to dmem
    wren,                           // O: Write enable for dmem
    q_dmem,                         // I: The data from dmem

    // Regfile
    ctrl_writeEnable,               // O: Write enable for RegFile
    ctrl_writeReg,                  // O: Register to write to in RegFile
    ctrl_readRegA,                  // O: Register to read from port A of RegFile
    ctrl_readRegB,                  // O: Register to read from port B of RegFile
    data_writeReg,                  // O: Data to write to for RegFile
    data_readRegA,                  // I: Data from port A of RegFile
    data_readRegB                   // I: Data from port B of RegFile
	 
	);

	// Control signals
	input clock, reset;
	
	// Imem
    output [31:0] address_imem;
	input [31:0] q_imem;

	// Dmem
	output [31:0] address_dmem, data;
	output wren;
	input [31:0] q_dmem;

	// Regfile
	output ctrl_writeEnable;
	output [4:0] ctrl_writeReg, ctrl_readRegA, ctrl_readRegB;
	output [31:0] data_writeReg;
	input [31:0] data_readRegA, data_readRegB;

	// =======================================================================

	wire [31:0] pc_out, pc_next, pc_plus_one;
	cla_32 pc_plus_one_cla(
		.A(pc_out),
		.B(32'b1),
		.Cin(1'b0),
		.Cout(),
		.S(pc_plus_one)
	);
	assign address_imem = pc_out;

	wire stall;
	wire stall_multdiv;

	register #(32) pc_reg(
		.clk(~clock),
		.input_enable(~stall),
		.output_enable(1'b1),  
		.clr(reset),
		.in(pc_next),
		.out(pc_out)
	);

	wire [31:0] fd_insn;
	wire [31:0] xm_insn, xm_O, xm_B;
	wire [31:0] dx_insn, dx_A, dx_B;
	wire [31:0] mw_insn, mw_O, mw_D;

	wire [4:0] fd_opcode = fd_insn[31:27];
	wire [4:0] fd_rd = fd_insn[26:22];
	wire [4:0] fd_rs = fd_insn[21:17];
	wire [4:0] fd_rt = fd_insn[16:12];
	wire fd_is_bex = (fd_opcode == 5'b10110);
	wire fd_is_r_type = (fd_opcode == 5'b00000);
	wire fd_is_bne = (fd_opcode == 5'b00010);
	wire fd_is_blt = (fd_opcode == 5'b00110);
	wire fd_is_jr = (fd_opcode == 5'b00100);
	wire fd_is_j = (fd_opcode == 5'b00001);
	wire fd_is_jal = (fd_opcode == 5'b00011);
	wire fd_is_setx = (fd_opcode == 5'b10101);
	wire fd_is_addi = (fd_opcode == 5'b00101);
	wire fd_is_lw = (fd_opcode == 5'b01000);
	wire fd_is_sw = (fd_opcode == 5'b00111);

	wire [4:0] dx_opcode = dx_insn[31:27];
	wire [4:0] dx_rd = dx_insn[26:22];
	wire [4:0] dx_rs = dx_insn[21:17];
	wire [4:0] dx_rt = dx_insn[16:12];
	wire [16:0] dx_imm = dx_insn[16:0];
	wire [4:0] dx_shamt = dx_insn[11:7];
	wire [4:0] dx_aluop = dx_insn[6:2];
	wire [26:0] dx_T = dx_insn[26:0];
	wire dx_is_r_type = (dx_opcode == 5'b00000);
	wire dx_is_addi = (dx_opcode == 5'b00101);
	wire dx_is_bex = (dx_opcode == 5'b10110);
	wire dx_is_bne = (dx_opcode == 5'b00010);
	wire dx_is_blt = (dx_opcode == 5'b00110);
	wire dx_is_j = (dx_opcode == 5'b00001);
	wire dx_is_jal = (dx_opcode == 5'b00011);
	wire dx_is_jr = (dx_opcode == 5'b00100);
	wire dx_is_mult = (dx_is_r_type && dx_aluop == 5'b00110);
	wire dx_is_div = (dx_is_r_type && dx_aluop == 5'b00111);
	wire dx_is_add = (dx_is_r_type && dx_aluop == 5'b00000);
	wire dx_is_sub = (dx_is_r_type && dx_aluop == 5'b00001);
	wire dx_is_sw = (dx_opcode == 5'b00111);
	wire dx_is_lw = (dx_opcode == 5'b01000);
	wire dx_is_setx = (dx_opcode == 5'b10101);
	wire dx_is_i_type = (dx_is_addi || dx_is_sw || dx_is_lw || dx_is_bne || dx_is_blt);

	wire [4:0] xm_opcode = xm_insn[31:27];
	wire [4:0] xm_rd = xm_insn[26:22];
	wire xm_is_r_type = (xm_opcode == 5'b00000);
	wire xm_is_addi = (xm_opcode == 5'b00101);
	wire xm_is_sw = (xm_opcode == 5'b00111);
	wire xm_is_lw = (xm_opcode == 5'b01000);
	wire xm_is_jal = (xm_opcode == 5'b00011);
	wire xm_is_setx = (xm_opcode == 5'b10101);
	wire xm_is_mult = (xm_opcode == 5'b00110);
	wire xm_is_div = (xm_opcode == 5'b00111);

	wire [4:0] mw_opcode = mw_insn[31:27];
	wire [4:0] mw_rd = mw_insn[26:22];
	wire [4:0] mw_rt = mw_insn[16:12];
	wire [26:0] mw_T = mw_insn[26:0];
	wire mw_is_r_type = (mw_opcode == 5'b00000);
	wire mw_is_addi = (mw_opcode == 5'b00101);
	wire mw_is_lw = (mw_opcode == 5'b01000);
	wire mw_is_setx = (mw_opcode == 5'b10101);
	wire mw_is_nop = (mw_insn == 32'b0);
	wire mw_is_jal = (mw_opcode == 5'b00011);
	wire mw_is_mult = (mw_opcode == 5'b00110);
	wire mw_is_div = (mw_opcode == 5'b00111);

	// Stall Logic 
	wire load_use_hazard = dx_is_lw && (
    ((fd_is_bne || fd_is_blt) && ((dx_rd == fd_rs) || (dx_rd == fd_rd))) ||
    (fd_is_jr && (dx_rd == fd_rd)) ||
    (fd_is_bex && (dx_rd == 5'd30))
);

	assign stall = load_use_hazard || stall_multdiv;

	// =======================================================================
	// FETCH STAGE 
	// =======================================================================
	
	wire branch_taken;
	
	wire flush = branch_taken;

	fd_latch fd(
		.clk(~clock),
		.reset(reset),
		.enable(~stall), // stall on all hazards
		.insn_in(flush ? 32'b0 : q_imem),
		.insn_out(fd_insn)
	);

	assign ctrl_readRegA = fd_rs;
	assign ctrl_readRegB = fd_is_bex ? 5'd30 : (fd_is_r_type ? fd_rt : fd_rd);

	// =======================================================================
	// EXECUTE STAGE
	// =======================================================================

	dx_latch dx(
		.clk(~clock),
		.reset(reset),
		.enable(~stall_multdiv), // only stall multdiv, not other hazards (otherwise fails branch tests)
		.insn_in((flush || load_use_hazard) ? 32'b0 : fd_insn),
		.A_in(data_readRegA),
		.B_in(data_readRegB),
		.insn_out(dx_insn),
		.A_out(dx_A),
		.B_out(dx_B)
	);

	wire dx_is_i_type_with_imm = dx_is_i_type && !dx_is_bne && !dx_is_blt;

	// ALU Logic
	wire [31:0] dx_imm_ext = {{15{dx_imm[16]}}, dx_imm};
	wire [4:0] dx_aluop_adjusted = (dx_is_addi || dx_is_sw || dx_is_lw) ? 5'b00000 : 
	                                (dx_is_bne || dx_is_blt) ? 5'b00001 : 
	                                dx_aluop;

	wire xm_will_write = xm_is_r_type ||
	                     xm_is_addi ||
						 xm_is_lw ||
						 xm_is_jal;

	// Bypass if MW will write to the destination register	
	wire mw_will_write = mw_is_r_type ||
						 mw_is_addi ||
						 mw_is_lw ||
						 mw_is_jal;
	
	wire [31:0] fwd_A =  // A is always $rs
    (xm_exception && (dx_rs == 5'd30)) ? xm_O :
    (mw_exception && (dx_rs == 5'd30)) ? mw_O :
    (xm_will_write && (xm_rd != 5'b0) && (xm_rd == dx_rs)) ? (xm_is_lw ? q_dmem : xm_O) :
    (mw_will_write && (mw_rd != 5'b0) && (mw_rd == dx_rs)) ? mw_O :
    dx_A;
	
	wire [4:0] dx_srcB = (dx_is_bne || dx_is_blt || dx_is_jr || dx_is_sw) ? dx_rd : dx_rt; // for branch instructions, use rd instead of rt
	wire [31:0] fwd_B =  // the control logic could be much better
    (xm_exception && (dx_srcB == 5'd30)) ? xm_O :
    (mw_exception && (dx_srcB == 5'd30)) ? mw_O :
    (xm_will_write && (xm_rd != 5'b0) && (xm_rd == dx_srcB)) ? (xm_is_lw ? q_dmem : xm_O) : // for lw, bypass dmem data instead of O
    (mw_will_write && (mw_rd != 5'b0) && (mw_rd == dx_srcB)) ? mw_O :
    dx_B;

	wire [31:0] alu_operandB = (dx_is_addi || dx_is_lw || dx_is_sw) ? dx_imm_ext : fwd_B;

	wire [31:0] alu_result;
	wire alu_isNotEqual, alu_isLessThan, alu_overflow;
	alu ALU(
		.data_operandA(fwd_A),
		.data_operandB(alu_operandB),
		.ctrl_ALUopcode(dx_aluop_adjusted),
		.ctrl_shiftamt(dx_shamt),
		.data_result(alu_result),
		.isNotEqual(alu_isNotEqual),
		.isLessThan(alu_isLessThan),
		.overflow(alu_overflow)
	);

	// MultDiv Logic
	wire [31:0] multdiv_result;
	wire multdiv_ready, multdiv_exception;
	
	wire multdiv_started;
	register #(1) multdiv_started_reg(
		.clk(~clock),
		.input_enable(1'b1),
		.output_enable(1'b1),
		.clr(reset),
		.in((dx_is_mult || dx_is_div) && !multdiv_ready),
		.out(multdiv_started)
	);

	wire ctrl_MULT_pulse = dx_is_mult && !multdiv_started; // 1 cycle pulse
	wire ctrl_DIV_pulse = dx_is_div && !multdiv_started; // 1 cycle pulse
	
	// Need to latch operands when multdiv operation starts to keep them stable during computation
	wire [31:0] multdiv_operandA, multdiv_operandB;
	register #(32) multdiv_operand_A_reg(
		.clk(~clock),
		.input_enable(ctrl_MULT_pulse || ctrl_DIV_pulse),
		.output_enable(1'b1),
		.clr(reset),
		.in(fwd_A),
		.out(multdiv_operandA)
	);
	register #(32) multdiv_operand_B_reg(
		.clk(~clock),
		.input_enable(ctrl_MULT_pulse || ctrl_DIV_pulse),
		.output_enable(1'b1),
		.clr(reset),
		.in(fwd_B),
		.out(multdiv_operandB)
	);
	
	multdiv MD(
		.data_operandA(multdiv_operandA),
		.data_operandB(multdiv_operandB),
		.ctrl_MULT(ctrl_MULT_pulse),
		.ctrl_DIV(ctrl_DIV_pulse),
		.clock(clock),
		.data_result(multdiv_result),
		.data_exception(multdiv_exception),
		.data_resultRDY(multdiv_ready)
	);
	assign stall_multdiv = (dx_is_mult || dx_is_div) && !multdiv_ready; // stall if not ready

	// Exception Detection
	wire dx_exception = 
    ((dx_is_add || dx_is_addi || dx_is_sub) && alu_overflow) ||
    ((dx_is_mult || dx_is_div) && multdiv_exception);
	wire [31:0] dx_exception_code = 
		(dx_is_add && alu_overflow) ? 32'd1 :
		(dx_is_addi && alu_overflow) ? 32'd2 :
		(dx_is_sub && alu_overflow) ? 32'd3 :
		(dx_is_mult && multdiv_exception) ? 32'd4 :
		(dx_is_div && multdiv_exception) ? 32'd5 :
		32'd0;

	wire [31:0] dx_result = dx_exception ? dx_exception_code : 
							(dx_is_setx ? {5'b0, dx_T} :
	                        (dx_is_jal ? pc_minus_one : 
	                        (dx_is_mult || dx_is_div) ? multdiv_result : 
	                        alu_result));

	// Branching Logic
	wire [31:0] bne_target;
	wire [31:0] pc_minus_one;
	cla_32 pc_minus_one_cla(
		.A(pc_out),
		.B(32'hFFFFFFFF),  
		.Cin(1'b0),
		.Cout(),
		.S(pc_minus_one)
	);
	cla_32 bne_target_cla(
		.A(pc_minus_one),
		.B(dx_imm_ext),
		.Cin(1'b0),
		.Cout(),
		.S(bne_target)
	);

	wire [31:0] bex_value =  // if setx happens close before bex, use the value from the setx
		(xm_is_setx) ? xm_O :
		(mw_is_setx) ? mw_O :
		dx_B;   

	wire dx_bex_taken = dx_is_bex && (bex_value != 32'b0);
	wire dx_bne_taken = dx_is_bne && alu_isNotEqual;
	wire dx_blt_taken = dx_is_blt && !alu_isLessThan && alu_isNotEqual;
	wire dx_j_taken = dx_is_j; // replace these since always taken
	wire dx_jal_taken = dx_is_jal;
	wire dx_jr_taken = dx_is_jr;
	assign branch_taken = dx_bex_taken || dx_bne_taken || dx_blt_taken || dx_j_taken || dx_jal_taken || dx_jr_taken;
	wire [31:0] branch_target = (dx_bex_taken || dx_j_taken || dx_jal_taken) ? {5'b0, dx_T} : (dx_jr_taken ? fwd_B : bne_target);
	assign pc_next = branch_taken ? branch_target : pc_plus_one;
	
	// =======================================================================
	// MEMORY STAGE
	// =======================================================================

	wire xm_exception;
	xm_latch xm(
		.clk(~clock),
		.reset(reset),
		.enable(~stall_multdiv), // only stall multdiv, not other hazards (otherwise fails branch tests)
		.insn_in(dx_insn),
		.O_in(dx_result),
		.B_in(fwd_B),
		.exception_in(dx_exception),
		.insn_out(xm_insn),
		.O_out(xm_O),
		.B_out(xm_B),
		.exception_out(xm_exception)
	);

	assign wren = xm_is_sw;
	assign address_dmem = xm_O;
	assign data = xm_B;

	// =======================================================================
	// WRITEBACK STAGE
	// =======================================================================
	
	wire mw_exception;
	mw_latch mw(
		.clk(~clock),
		.reset(reset),
		.insn_in(xm_insn), // no stall here
		.O_in(xm_is_lw ? q_dmem : xm_O),
		.D_in(xm_B), // Should this be B or D?
		.exception_in(xm_exception),
		.insn_out(mw_insn),
		.O_out(mw_O),
		.D_out(mw_D),
		.exception_out(mw_exception)
	);

	assign ctrl_writeEnable = !mw_is_nop && (mw_exception || mw_is_r_type || mw_is_addi || mw_is_lw || mw_is_setx || mw_is_jal); 
	assign ctrl_writeReg = mw_exception ? 5'd30 : 
	                       (mw_is_jal ? 5'd31 : 
	                       (mw_is_setx ? 5'd30 : 
	                       ((mw_is_r_type || mw_is_addi || mw_is_lw) ? mw_rd : 5'b0)));
	assign data_writeReg = mw_is_setx ? {5'b0, mw_T} : mw_O; // if exception, O contains exception code; if jal, O contains pc - 1; if lw, O contains dmem data

endmodule
