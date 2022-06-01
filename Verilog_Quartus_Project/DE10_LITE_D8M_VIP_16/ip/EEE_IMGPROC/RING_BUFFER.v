module RING_BUFFER(
	// global clock & reset
	clk,
	reset_n,
	
	data_in,
);

	// Input Port(s)
	input [DATA_WIDTH-1:0] data_in;

	// Parameter Declaration(s)
	parameter CAPACITY = 640;
	parameter DATA_WIDTH = 24;



