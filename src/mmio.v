module mmio(
    input wire [11:0] addr,
    input wire [31:0] data,
    output wire [31:0] data_out,
    input wire BTNU
);
    assign data_out = (addr == 12'd1000) ? BTNU : data;
endmodule