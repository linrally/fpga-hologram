`timescale 1ns / 1ps

module proc_tb #(parameter INSTR_FILE = "");
    localparam NUM_CYCLES = 255;
    reg clock = 0, reset = 0;

	wire rwe, mwe;
	wire[4:0] rd, rs1, rs2;
	wire[31:0] instAddr, instData, 
		rData, regA, regB,
		memAddr, memDataIn, memDataOut_cpu, memDataOut_ram;

	processor CPU(.clock(clock), .reset(reset), 
								
		// ROM
		.address_imem(instAddr), .q_imem(instData),
									
		// Regfile
		.ctrl_writeEnable(rwe),     .ctrl_writeReg(rd),
		.ctrl_readRegA(rs1),     .ctrl_readRegB(rs2), 
		.data_writeReg(rData), .data_readRegA(regA), .data_readRegB(regB),
									
		// RAM
		.wren(mwe), .address_dmem(memAddr), 
		.data(memDataIn), .q_dmem(memDataOut_cpu)); 
	
	ROM #(.DATA_WIDTH(32), .ADDRESS_WIDTH(12), .DEPTH(4096), .MEMFILE({INSTR_FILE}))
	InstMem(.clk(clock), 
		.addr(instAddr[11:0]), 
		.dataOut(instData));
	
	regfile RegisterFile(.clock(clock), 
		.ctrl_writeEnable(rwe), .ctrl_reset(reset), 
		.ctrl_writeReg(rd),
		.ctrl_readRegA(rs1), .ctrl_readRegB(rs2), 
		.data_writeReg(rData), .data_readRegA(regA), .data_readRegB(regB));
						
	// Processor Memory (RAM)
	RAM #(.DATA_WIDTH(32), .ADDRESS_WIDTH(12), .DEPTH(4096)) ProcMem(.clk(clock), 
		.wEn(mwe), 
		.addr(memAddr[11:0]), 
		.dataIn(memDataIn), 
		.dataOut(memDataOut_cpu));
    
    always #5 clock = ~clock;

    integer cycles;
	reg[9:0] num_cycles = NUM_CYCLES;

    initial begin
        reset = 1;
        #1;
        reset = 0;

		for (cycles = 0; cycles < num_cycles; cycles = cycles + 1) begin
			// Every rising edge, write to the actual file
			@(posedge clock);
			if (rwe && rd != 0) begin
				$display("Cycle %3d: Wrote %0d into register %0d", cycles, $signed(rData), rd);
			end
		end

        #100;
        $finish;
    end
    
endmodule
