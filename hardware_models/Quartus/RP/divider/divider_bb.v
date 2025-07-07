
module divider (
	numer,
	denom,
	clock,
	quotient,
	remain);	

	input	[35:0]	numer;
	input	[15:0]	denom;
	input		clock;
	output	[35:0]	quotient;
	output	[15:0]	remain;
endmodule
