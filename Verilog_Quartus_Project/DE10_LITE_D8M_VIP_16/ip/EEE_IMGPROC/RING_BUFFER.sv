// synthesis VERILOG_INPUT_VERSION SYSTEMVERILOG_2005

module RING_BUFFER #(
    parameter DATA_WIDTH = 26,
    parameter CAPACITY   = 640
) (
    input logic clk,
    input logic rst_n,
    input logic ready_in,
    input logic valid_in,
    input logic [DATA_WIDTH-1:0] data_in,
    output logic ready_out,
    output logic valid_out,
    output logic [DATA_WIDTH-1:0] data_out
);
  logic data_valid, ready_in_d;

  logic ready_d, ready_q;

  always_comb begin
    ready_d = ready_in;
  end


  always_ff @(posedge clk) begin
    ready_q <= ready_d;

    if (~rst_n) begin
      ready_q <= 1'b0;
      data_out <= {DATA_WIDTH{1'b0}};
      data_valid <= 1'b0;
    end else begin
      //ready_in_d <= ready_in;

      // If the stream register is 
      //	a. recieving valid input AND (
      // 	b. is not currently holding any valid data that must be passed on OR
      // 	c.the sreaming register after this is ready to recieve)
      // then accept new data. If the next streaming register is ready to recieve,
      // then we can clock out the current contents of this register to it
      // and simultaneously (on the same posedge) clock in the input data.
      if (valid_in & (~data_valid | ready_q)) begin
        // We have a valid input, and the reciever is either ready or
        // we have empty space for the new data. 


        data_out   <= data_in;
        data_valid <= 1'b1;
      end else if (ready_q) begin
        // Reciever is ready, but we have no new data on our input
        data_valid <= 1'b0;


      end
    end
  end

  assign ready_out = (~data_valid & ~valid_in) | ready_in; // indicates if the streaming reg is ready to recieve any data. 
  assign valid_out = ready_in_d & data_valid;


endmodule



/*
module RING_BUFFER #(
    parameter DATA_WIDTH = 27,
    parameter CAPACITY   = 640
) (
    input logic clk,
    input logic rst_n,

    // data flow
    input logic [DATA_WIDTH - 1:0] data_in,
    input logic data_new_in, // Gonna be high if there is a valid pixel ready to be put into the ring buffer

    // 32 bits should suit our needs regardless of capacity.. 
    output logic [31:0] head_out,
    output logic [31:0] tail_out,
    output logic [DATA_WIDTH - 1:0] buffer_array_out[CAPACITY - 1:0],

    output logic ring_valid_out  // Is going to be high if the buffer is full and is ready to be read
);

  logic [DATA_WIDTH - 1:0] buffer_array_d[CAPACITY - 1:0];
  logic [DATA_WIDTH - 1:0] buffer_array_q[CAPACITY - 1:0];
  logic [31:0] head_d, head_q, tail_d, tail_q;
  logic ring_valid_d, ring_valid_q;

  assign head_out = head_q;  // give the output(head)the latest value of the internal head value
  assign tail_out = tail_q;
  assign ring_valid_out = ring_valid_q;
  assign buffer_array_out = buffer_array_q;

  always_comb begin
    buffer_array_d = buffer_array_q;

    if (~rst_n) begin
      head_d = 32'b0;
      tail_d = CAPACITY - 1;
      //count_d = 32'b0;
      //ring_valid_out = 1'b0;
      buffer_array_d[head_d] = {DATA_WIDTH{1'b0}};

      //Assuming above is ok, if reset=1 then try the following:
    end else if (data_new_in == 1) begin  //if in_valid=1 (if we're dealing with an acc pixel)
      head_d = head_q + 1; // give head_d the value that is the old head value that has been incremented by 1
      tail_d = tail_q + 1;  // same but with the tail value. 

      if (head_q >= CAPACITY - 1) begin
        head_d = 32'b0;
      end

      if (tail_q >= CAPACITY - 1) begin
        tail_d = 32'b0;
      end

      // head points to newest valid element
      buffer_array_d[head_d] = data_in;

      // if (count_q < CAPACITY) begin
      //   count_d = count_q + 1;
      //   ring_valid_out = 1'b0;
      // end else begin
      //   count_d = count_q;
      //   ring_valid_out = 1'b1;
      // end

    end else begin
      head_d = head_q;
      tail_d = tail_q;
      buffer_array_d[head_d] = buffer_array_q[head_q];
      // count_d = count_q; did you remove the line below because it would have been redundant?
    end

    ring_valid_d = data_new_in;

  end


  // Counter logic for pointers
  always_ff @(posedge clk) begin
    //Let's update the value at the head_out pointer and push out the value at the tail pointer

    // if (data_new_in == 1) begin
    //   buffer_array_out[head_out] <= data_in;
    // end else begin
    //   buffer_array_out[head_out] <= buffer_array_out[head_out];
    // end

    buffer_array_q <= buffer_array_d;
    head_q <= head_d;
    tail_q <= tail_d;
    //count_q <= count_d;
    ring_valid_q <= ring_valid_d;
  end


endmodule
*/


