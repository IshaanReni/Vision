// synthesis VERILOG_INPUT_VERSION SYSTEMVERILOG_2005


// Module act as middle-man to the SPI bridge between
// EEE_IMGPROC and the ESP32. Inputs and outputs are similar to
// that of the streaming register.
module SPI_BUFFER #(
    parameter CAPACITY   = 9,
    parameter DATA_WIDTH = 32

) (
    //control signals
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic ready_in,
    output logic valid_out,
    output logic ready_out,

    //data signals 
    input  logic [DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0] data_out
);

  // pointer to where there is free space in buffer
  // location at head + 1 is taken
  logic [6:0] head;

  assign ready_out = head > 1;
  assign valid_out = head < CAPACITY - 1;

  logic [DATA_WIDTH-1:0] internal_q[CAPACITY-1:0];
  logic [DATA_WIDTH-1:0] internal_d[CAPACITY-1:0];

  always_comb begin
    // wire input to first
    internal_d[head] = data_in;

    for (integer i = head + 1; i < CAPACITY; i = i + 1) begin
      internal_d[i] = internal_q[i-1];
    end
  end


  always_ff @(posedge clk) begin
    if (~rst_n) begin
      for (integer i = 0; i < CAPACITY; i = i + 1) begin
        internal_q[i] <= {DATA_WIDTH{1'b0}};
      end

      head <= CAPACITY - 1;

    end else if (valid_in && ready_out) begin
      // We are ready to recieve and valid data has been put on our input.
      // This data must go in the buffer.

      if (ready_in) begin
        // SPI is also ready to recieve.
        // On this clock we can both output data to the SPI and
        // recieve - hence not filling up our buffer more.

        for (integer i = head; i < CAPACITY; i = i + 1) begin
          internal_q[i] <= internal_d[i];
        end

      end else begin
        // SPI is not ready to recieve. We put the valid data
        // in the buffer.
        internal_q[head] <= internal_d[head];
        head <= head - 1;
      end
    end else begin
      // Either we are not ready to recieve, or the data we have been given
      // is not proper. 
      if (ready_in) begin
        // SPI is ready to recieve, though.

        for (integer i = head + 1; i < CAPACITY; i = i + 1) begin
          internal_q[i] <= internal_d[i];
        end

        head <= head + 1;
      end

    end
  end

  always_comb begin
    data_out = internal_q[CAPACITY-1];
  end


endmodule
