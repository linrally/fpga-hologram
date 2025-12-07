module sll_barrel_32(A, shamt, Y);
  input [31:0] A;
  input [4:0]  shamt;
  output [31:0] Y;

  wire [31:0] w1, w2, w3, w4;
  genvar i;

  generate
    for (i = 0; i < 32; i = i + 1) begin : gen_w1
      mux_2 #(1) mux (
        .out(w1[i]),
        .select(shamt[0]),
        .in0(A[i]),
        .in1((i == 0) ? 1'b0 : A[i-1])
      );
    end
  endgenerate

  generate
    for (i = 0; i < 32; i = i + 1) begin : gen_w2
      mux_2 #(1) mux (
        .out(w2[i]),
        .select(shamt[1]),
        .in0(w1[i]),
        .in1((i < 2) ? 1'b0 : w1[i-2])
      );
    end
  endgenerate

  generate
    for (i = 0; i < 32; i = i + 1) begin : gen_w3
      mux_2 #(1) mux (
        .out(w3[i]),
        .select(shamt[2]),
        .in0(w2[i]),
        .in1((i < 4) ? 1'b0 : w2[i-4])
      );
    end
  endgenerate

  generate
    for (i = 0; i < 32; i = i + 1) begin : gen_w4
      mux_2 #(1) mux (
        .out(w4[i]),
        .select(shamt[3]),
        .in0(w3[i]),
        .in1((i < 8) ? 1'b0 : w3[i-8])
      );
    end
  endgenerate

  generate
    for (i = 0; i < 32; i = i + 1) begin : gen_Y
      mux_2 #(1) mux (
        .out(Y[i]),
        .select(shamt[4]),
        .in0(w4[i]),
        .in1((i < 16) ? 1'b0 : w4[i-16])
      );
    end
  endgenerate

endmodule
