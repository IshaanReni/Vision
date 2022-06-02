module RING_BUFFER( //pls 4give moi if this doesn't work:(
	//Parameters
	capacity_in
	data_width_in
	// global clock & reset
	clk,
	reset_n,
	// data flow
	data_in,
	data_out,
	// pointer values to be called upon
	head_in,
	tail_in
);
	/* We need two pointers: one head pointer and one tail pointer. We replace 
	the value at the head pointer and we read the value at the tail pointer.*/

	// Parameter Declaration(s)
	parameter CAPACITY = capacity_in; // to hold a whole row of pixels
	parameter DATA_WIDTH = data_width_in; // to hold {r,g,b}

	// Input Port(s)
	input [DATA_WIDTH-1:0] data_in;
	input head_in; // push the inputted value of the head to be operated on
	input tail_in; // likewise

	// Output Port(s)
	output [DATA_WIDTH-1:0] data_out;
	output headOut;
	output tailOut;
	 
	// Memory block instantiation
	reg [DATA_WIDTH-1:0] buffer_array [CAPACITY-1:0];

	// Counter logic for pointers
	always @ (posedge clk) begin
		if (reset_n) // If the reset signal is high then bring the pointers back to the beginning
			headOut <= 1;
			tailOut <= 0;
		else
			//Let's update the value at the head pointer and push out the value at the tail pointer
			buffer_array[head] <= data_in;
			data_out <= buffer_array[tail];
			
			//Now let's increment the head and the tail pointers.
			if (head_in != (CAPACITY-1))
				headOut <= head_in + 1;
			else //else condition should take care of resetting the head pointer. 
				headOut <= 0;
			if (tail_in != (CAPACITY-1))
				tailOut <= tail_in + 1;
			else //else condition should take care of resetting the tail pointer. 
				tailOut <= 0;	
	end
	

endmodule