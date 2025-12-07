module sra_barrel_32(A, shamt, Y);
  input  [31:0] A;
  input  [4:0]  shamt;
  output [31:0] Y;

  wire [31:0] w1, w2, w3, w4;
  wire sign = A[31];
  genvar i;

  generate
    for (i = 0; i < 32; i = i + 1) begin : gen_w1
      mux_2 #(1) mux (
        .out(w1[i]),
        .select(shamt[0]),
        .in0(A[i]),
        .in1((i + 1 < 32) ? A[i+1] : sign)
      );
    end
  endgenerate

  generate
    for (i = 0; i < 32; i = i + 1) begin : gen_w2
      mux_2 #(1) mux (
        .out(w2[i]),
        .select(shamt[1]),
        .in0(w1[i]),
        .in1((i + 2 < 32) ? w1[i+2] : sign)
      );
    end
  endgenerate

  generate
    for (i = 0; i < 32; i = i + 1) begin : gen_w3
      mux_2 #(1) mux (
        .out(w3[i]),
        .select(shamt[2]),
        .in0(w2[i]),
        .in1((i + 4 < 32) ? w2[i+4] : sign)
      );
    end
  endgenerate

  generate
    for (i = 0; i < 32; i = i + 1) begin : gen_w4
      mux_2 #(1) mux (
        .out(w4[i]),
        .select(shamt[3]),
        .in0(w3[i]),
        .in1((i + 8 < 32) ? w3[i+8] : sign)
      );
    end
  endgenerate

  generate
    for (i = 0; i < 32; i = i + 1) begin : gen_Y
      mux_2 #(1) mux (
        .out(Y[i]),
        .select(shamt[4]),
        .in0(w4[i]),
        .in1((i + 16 < 32) ? w4[i+16] : sign)
      );
    end
  endgenerate

endmodule
