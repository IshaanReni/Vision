// synthesis VERILOG_INPUT_VERSION SYSTEMVERILOG_2005
module RING_BUFFER #(
    parameter DATA_WIDTH = 24,
    parameter CAPACITY   = 640
) (
    input logic clk,
    input logic rst_n,

    // data flow
    input logic data_in,
    input logic data_new_in,

    // 32 bits should suit our needs regardless of capacity.. 
    output logic [31:0] head_out,
    output logic [DATA_WIDTH - 1:0] buffer_array_out[CAPACITY - 1:0]
);
  logic [31:0] head_temp;

  //integer i;

  // Counter logic for pointers
  always_ff @(posedge clk) begin
    if (~rst_n) begin  // Reset seems to be active low
      head_out <= 31'b0;
    end
    /*
	for(i= 0; i < CAPACITY; i = i + 1) begin
		buffer_array[i] <= {DATA_WIDTH{1'b0}};
	end
	*/    
    
	else
    if (data_new_in == 1) begin
      //Let's update the value at the head_out pointer and push out the value at the tail pointer
      buffer_array_out[head_out] <= data_in;

      head_temp <= head_out;
      head_out <= head_temp + 1;
    end
  end


endmodule
