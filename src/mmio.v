module mmio(
    input wire [11:0] addr,
    input wire mwe,
    input wire [31:0] data,
    output wire [31:0] data_out,
    input wire BTNU
    output reg  [3:0]  texture_idx
);
    always @(posedge clk) begin
        if (we) begin
            case (addr)
                12'd1001: texture_idx <= data[3:0]; 
            endcase
        end
    end

    always @(*) begin
        case (addr)
            12'd1000: data_out = {31'b0, BTNU}; 
            12'd1001: data_out = {28'b0, texture_idx}; 
            default:  data_out = data;  
        endcase
    end
endmodule
