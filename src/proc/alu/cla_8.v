module cla_8 (A, B, Cin, Cout, G, P, S);
	input [7:0] A, B;
	input Cin;
	output [7:0] S;
	output G, P, Cout;

	wire [7:0] g,p;
	wire [7:0] c;

	genvar i;
	generate
		for (i = 0; i < 8; i = i + 1) begin : gen_gp
			and (g[i], A[i], B[i]); 
			or (p[i], A[i], B[i]);
		end
	endgenerate

	assign c[0] = Cin;
	
	// c[1] = g[0] + p[0]c[0]
	wire w1;
	and (w1, p[0], c[0]);
	or (c[1], g[0], w1);

	// c[2] = g[1] + p[1]g[0] + p[1]p[0]c[0]
	wire w2, w3;
	and (w2, p[1], g[0]);            
	and (w3, p[1], p[0], c[0]);     
	or  (c[2], g[1], w2, w3);

	// c[3] = g[2] 
	//       + p[2]g[1] 
	//       + p[2]p[1]g[0] 
	//       + p[2]p[1]p[0]c[0]
	wire w4, w5, w6;
	and (w4, p[2], g[1]);
	and (w5, p[2], p[1], g[0]);
	and (w6, p[2], p[1], p[0], c[0]);
	or  (c[3], g[2], w4, w5, w6);

	// c[4] = g[3] 
	//       + p[3]g[2] 
	//       + p[3]p[2]g[1] 
	//       + p[3]p[2]p[1]g[0] 
	//       + p[3]p[2]p[1]p[0]c[0]
	wire w7, w8, w9, w10;
	and (w7,  p[3], g[2]);
	and (w8,  p[3], p[2], g[1]);
	and (w9,  p[3], p[2], p[1], g[0]);
	and (w10, p[3], p[2], p[1], p[0], c[0]);
	or  (c[4], g[3], w7, w8, w9, w10);

	// c[5] = g[4] 
	//       + p[4]g[3] 
	//       + p[4]p[3]g[2] 
	//       + p[4]p[3]p[2]g[1] 
	//       + p[4]p[3]p[2]p[1]g[0] 
	//       + p[4]p[3]p[2]p[1]p[0]c[0]
	wire w11, w12, w13, w14, w15;
	and (w11, p[4], g[3]);
	and (w12, p[4], p[3], g[2]);
	and (w13, p[4], p[3], p[2], g[1]);
	and (w14, p[4], p[3], p[2], p[1], g[0]);
	and (w15, p[4], p[3], p[2], p[1], p[0], c[0]);
	or  (c[5], g[4], w11, w12, w13, w14, w15);

	// c[6] = g[5] 
	//       + p[5]g[4] 
	//       + p[5]p[4]g[3] 
	//       + p[5]p[4]p[3]g[2] 
	//       + p[5]p[4]p[3]p[2]g[1] 
	//       + p[5]p[4]p[3]p[2]p[1]g[0] 
	//       + p[5]p[4]p[3]p[2]p[1]p[0]c[0]
	wire w16, w17, w18, w19, w20, w21;
	and (w16, p[5], g[4]);
	and (w17, p[5], p[4], g[3]);
	and (w18, p[5], p[4], p[3], g[2]);
	and (w19, p[5], p[4], p[3], p[2], g[1]);
	and (w20, p[5], p[4], p[3], p[2], p[1], g[0]);
	and (w21, p[5], p[4], p[3], p[2], p[1], p[0], c[0]);
	or  (c[6], g[5], w16, w17, w18, w19, w20, w21);

	// c[7] = g[6] 
	//       + p[6]g[5] 
	//       + p[6]p[5]g[4] 
	//       + p[6]p[5]p[4]g[3] 
	//       + p[6]p[5]p[4]p[3]g[2] 
	//       + p[6]p[5]p[4]p[3]p[2]g[1] 
	//       + p[6]p[5]p[4]p[3]p[2]p[1]g[0] 
	//       + p[6]p[5]p[4]p[3]p[2]p[1]p[0]c[0]
	wire w22, w23, w24, w25, w26, w27, w28;
	and (w22, p[6], g[5]);
	and (w23, p[6], p[5], g[4]);
	and (w24, p[6], p[5], p[4], g[3]);
	and (w25, p[6], p[5], p[4], p[3], g[2]);
	and (w26, p[6], p[5], p[4], p[3], p[2], g[1]);
	and (w27, p[6], p[5], p[4], p[3], p[2], p[1], g[0]);
	and (w28, p[6], p[5], p[4], p[3], p[2], p[1], p[0], c[0]);
	or  (c[7], g[6], w22, w23, w24, w25, w26, w27, w28);

	// Cout = g[7] 
	//       + p[7]g[6] 
	//       + p[7]p[6]g[5] 
	//       + p[7]p[6]p[5]g[4] 
	//       + p[7]p[6]p[5]p[4]g[3] 
	//       + p[7]p[6]p[5]p[4]p[3]g[2] 
	//       + p[7]p[6]p[5]p[4]p[3]p[2]g[1] 
	//       + p[7]p[6]p[5]p[4]p[3]p[2]p[1]g[0] 
	//       + p[7]p[6]p[5]p[4]p[3]p[2]p[1]p[0]c[0]
	wire w29, w30, w31, w32, w33, w34, w35, w36;
	and (w29, p[7], g[6]);
	and (w30, p[7], p[6], g[5]);
	and (w31, p[7], p[6], p[5], g[4]);
	and (w32, p[7], p[6], p[5], p[4], g[3]);
	and (w33, p[7], p[6], p[5], p[4], p[3], g[2]);
	and (w34, p[7], p[6], p[5], p[4], p[3], p[2], g[1]);
	and (w35, p[7], p[6], p[5], p[4], p[3], p[2], p[1], g[0]);
	and (w36, p[7], p[6], p[5], p[4], p[3], p[2], p[1], p[0], c[0]);
	or  (Cout, g[7], w29, w30, w31, w32, w33, w34, w35, w36);

	generate
		for (i = 0; i < 8; i = i + 1) begin : gen_sum
			xor (S[i], A[i], B[i], c[i]);
		end
	endgenerate

	and (P, p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7]);

	// G = g[7] 
	//   + p[7]g[6] 
	//   + p[7]p[6]g[5] 
	//   + p[7]p[6]p[5]g[4] 
	//   + p[7]p[6]p[5]p[4]g[3] 
	//   + p[7]p[6]p[5]p[4]p[3]g[2] 
	//   + p[7]p[6]p[5]p[4]p[3]p[2]g[1] 
	//   + p[7]p[6]p[5]p[4]p[3]p[2]p[1]g[0] 
	wire wg1, wg2, wg3, wg4, wg5, wg6, wg7;
	and (wg1, p[7], g[6]);
	and (wg2, p[7], p[6], g[5]);
	and (wg3, p[7], p[6], p[5], g[4]);
	and (wg4, p[7], p[6], p[5], p[4], g[3]);
	and (wg5, p[7], p[6], p[5], p[4], p[3], g[2]);
	and (wg6, p[7], p[6], p[5], p[4], p[3], p[2], g[1]);
	and (wg7, p[7], p[6], p[5], p[4], p[3], p[2], p[1], g[0]);
	or  (G, g[7], wg1, wg2, wg3, wg4, wg5, wg6, wg7);

endmodule
