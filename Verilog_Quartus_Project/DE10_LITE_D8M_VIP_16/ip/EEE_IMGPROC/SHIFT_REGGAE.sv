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

  logic [DATA_WIDTH-1:0] internal_q[NO_STAGES-1:0];
  logic [DATA_WIDTH-1:0] internal_d[NO_STAGES-1:0];

  integer i;

  always_comb begin
    // wire input to first
    internal_d[0] = data_in;

    for (i = 1; i < NO_STAGES - 1; i = i + 1) begin
      internal_d[i] = internal_q[i-1];
    end
  end


  always_ff @(posedge clk) begin
    if (valid_in) begin
      for (i = 0; i < NO_STAGES - 1; i = i + 1) begin
        internal_q[i] <= internal_d[i];
      end
    end
  end

  always_comb begin
    data_out = internal_q[NO_STAGES-1];
  end


  always_ff @(posedge clk) begin

    for (i = 0; i < NO_STAGES - 2; i = i + 1) begin
      if (~rst_n) begin
        internal_q[i] <= {DATA_WIDTH{1'b0}};
      end else if (valid_in) begin
        internal_q[i+1] <= internal_q[i];
      end else begin
        //DO nothing (nothing to add so don't move)
      end
    end

    if (~rst_n) begin
      internal_q[NO_STAGES-1] <= {DATA_WIDTH{1'b0}};
    end
  end


endmodule
