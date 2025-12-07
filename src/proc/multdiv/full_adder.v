module full_adder(S, Cout, A, B, Cin);

	input A, B, Cin;
	output S, Cout;
	wire w1, w2, w3;

	xor Sresult(S, A, B, Cin); // all of these are gates
	and A_and_B(w1, A, B);
	and A_and_Cin(w2, A, Cin);
	and B_and_Cin(w3, B, Cin);
	or Coutresult(Cout, w1, w2, w3);

endmodule
