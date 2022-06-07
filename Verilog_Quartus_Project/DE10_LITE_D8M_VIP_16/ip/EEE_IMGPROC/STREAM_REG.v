module STREAM_REG (
    ready_out,
    valid_out,
    data_out,
    ready_in,
    valid_in,
    data_in,
    clk,
    rst_n
);

  // Input Port(s)
  input clk, rst_n;
  input ready_in, valid_in;
  input [DATA_WIDTH-1:0] data_in;

  // Output Port(s)
  output ready_out, valid_out;
  output reg [DATA_WIDTH-1:0] data_out;

  // Parameter Declaration(s)
  parameter DATA_WIDTH = 26;

  reg data_valid, ready_in_d;

  always @(posedge clk) begin
    if (~rst_n) begin
      data_out   <= 1'b0;
      data_valid <= 1'b0;
      ready_in_d <= 1'b0;
    end else begin
      ready_in_d <= ready_in;
      // If the stream register is 
      //	a. recieving valid input AND (
      // 	b. is not currently holding any valid data that must be passed on OR
      // 	c.the sreaming register after this is ready to recieve)
      // then accept new data. If the next streaming register is ready to recieve,
      // then we can clock out the current contents of this register to it
      // and simultaneously (on the same posedge) clock in the input data.
      if (valid_in & (~data_valid | ready_in_d)) begin
        data_out   <= data_in;
        data_valid <= 1;
      end else if (ready_in_d) begin
        data_valid <= 0;
      end
    end
  end

  // 
  assign ready_out = (~data_valid & ~valid_in) | ready_in; // indicates if the streaming reg is ready to recieve any data. 
  assign valid_out = ready_in_d & data_valid;


endmodule
