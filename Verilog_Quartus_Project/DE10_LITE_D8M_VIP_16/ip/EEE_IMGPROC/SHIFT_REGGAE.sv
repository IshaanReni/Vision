// synthesis VERILOG_INPUT_VERSION SYSTEMVERILOG_2005

module SHIFT_REGGAE #(
    parameter NO_STAGES  = 9,
    parameter DATA_WIDTH = 26

) (
    //control signals
    input logic clk,
    input logic rst_n,
    input logic valid_in,

    //data signals 
    input  logic [DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0] data_out
);


  logic [DATA_WIDTH-1:0] tmp[NO_STATES-1:0];

  logic [DATA_WIDTH-1:0] internal[NO_STAGES-1:0];

  always_ff @(posedge clk) begin
    if (valid_in) begin
      internal[0] <= data_in;
    end
  end

  always_comb begin
    data_out = internal[NO_STAGES-1];
  end

  integer i;

  always_comb begin
    for (i = 0; i < NO_STAGES - 2; i = i + 1) begin
      tmp[i] = internal[i];  //force output to the temporary wire
    end
  end

  always_ff @(posedge clk) begin

    for (i = 0; i < NO_STAGES - 2; i = i + 1) begin
      if (~rst_n) begin
        internal[i] <= {DATA_WIDTH{1'b0}};
      end else if (valid_in) begin
        internal[i+1] <= tmp[i];
      end else begin
        //DO nothing (nothing to add so don't move)
      end
    end

    if (~rst_n) begin
      internal[NO_STAGES-1] <= {DATA_WIDTH{1'b0}};
    end
  end


endmodule
