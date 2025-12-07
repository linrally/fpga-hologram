module cla_32 (A, B, Cin, Cout, S);
	input [31:0] A, B;
	input Cin;
	output [31:0] S;
	output Cout;

	wire [3:0] G,P;
	wire [3:0] C;

	assign C[0] = Cin;

	// C[1] = G[0] + P[0]C[0]
	wire w1;
	and (w1, P[0], C[0]);
	or  (C[1], G[0], w1);

	// C[2] = G[1] + P[1]G[0] + P[1]P[0]C[0] 
	wire w2, w3;
	and (w2, P[1], G[0]);
	and (w3, P[1], P[0], C[0]);
	or  (C[2], G[1], w2, w3);

	// C[3] = G[2] + P[2]G[1] + P[2]P[1]G[0] + P[2]P[1]P[0]C[0]
	wire w4, w5, w6;
	and (w4, P[2], G[1]);
	and (w5, P[2], P[1], G[0]);
	and (w6, P[2], P[1], P[0], C[0]);
	or  (C[3], G[2], w4, w5, w6);

	// Cout = G[3] + P[3]G[2] + P[3]P[2]G[1] + P[3]P[2]P[1]G[0] + P[3]P[2]P[1]P[0]C[0]
	wire w7, w8, w9, w10;
	and (w7, P[3], G[2]);
	and (w8, P[3], P[2], G[1]);
	and (w9, P[3], P[2], P[1], G[0]);
	and (w10, P[3], P[2], P[1], P[0], C[0]);
	or  (Cout, G[3], w7, w8, w9, w10);

	cla_8 cla0 (
			.A(A[7:0]),
			.B(B[7:0]),
			.Cin(C[0]),
			.S(S[7:0]),
			.Cout(),     
			.G(G[0]),
			.P(P[0])
	);

	cla_8 cla1 (
			.A(A[15:8]),
			.B(B[15:8]),
			.Cin(C[1]),
			.S(S[15:8]),
			.Cout(),
			.G(G[1]),
			.P(P[1])
	);

	cla_8 cla2 (
			.A(A[23:16]),
			.B(B[23:16]),
			.Cin(C[2]),
			.S(S[23:16]),
			.Cout(),
			.G(G[2]),
			.P(P[2])
	);

	cla_8 cla3 (
			.A(A[31:24]),
			.B(B[31:24]),
			.Cin(C[3]),
			.S(S[31:24]),
			.Cout(),
			.G(G[3]),
			.P(P[3])
	);

endmodule

