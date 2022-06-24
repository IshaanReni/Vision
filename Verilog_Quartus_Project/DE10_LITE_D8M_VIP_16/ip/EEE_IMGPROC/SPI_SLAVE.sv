// synthesis VERILOG_INPUT_VERSION SYSTEMVERILOG_2005

module SPI_Slave #(
    parameter CLK_POL = 1,
    parameter CLK_PHA = 1
) (
    input logic clk_in,
    input logic rst_n_in,

    // Signals to interface with rest of FPGA
    input logic TX_valid_in,
    input logic [31:0] TX_byte_in,
    output logic ready_out,

    // External SPI Interface signals
    input  logic SPI_Clk_in,
    output logic SPI_MISO_out,
    input  logic SPI_MOSI_in,
    input  logic SPI_CS_n_in    // active low
);

  logic SPI_Clk_Polar;
  assign SPI_Clk_Polarised = CLK_POL ? ~SPI_Clk_in : SPI_Clk_in;
  logic ready;
  assign ready_out = ready;

  logic [7:0] TX_bit_count;
  logic TX_done;
  logic [31:0] TX_byte;
  logic transmit_rdy;

  /*
  always_ff @(posedge SPI_Clk_Polarised or posedge SPI_CS_n_in) begin

    // Posedge detected for CS, reset read buffer 
    if (SPI_CS_n_in) begin
      RX_bit_count <= 0;
      RX_done <= 1'b0;

    end else begin
      // recieve next bit
      RX_bit_count <= RX_bit_count + 1;
      temp_RX_byte <= {temp_RX_byte[6:0], SPI_MOSI_in};

      if (RX_bit_count == 7) begin
        RX_done <= 1'b1;
        RX_byte <= {temp_RX_byte[6:0], SPI_MOSI_in};
      end else if (RX_bit_count == 3'b010) begin
        RX_done <= 1'b0;
      end

    end
  end

  logic RX_done_d1, RX_done_d2;

  // Serialize data from master such that FPGA
  // can read it later.
  always_ff @(posedge clk_in) begin
    if (~rst_n_in) begin
      RX_done_d1   <= 1'b0;
      RX_done_d2   <= 1'b0;
      RX_valid_out <= 1'b0;
      RX_byte_out  <= 8'h0;
    end else begin
      RX_done_d1 <= RX_done;
      RX_done_d2 <= RX_done_d1;

      // Rising edge
      if (RX_done_d2 == 1'b0 && RX_done_d1 == 1'b1) begin
        RX_valid_out <= 1'b1;
        RX_byte_out  <= RX_byte;
      end else begin
        RX_valid_out <= 1'b0;
      end
    end
  end
  */

  // We need to clock out data as soon as CS goes low
  // preload MISO signifies whether 
  logic SPI_MISO_bit, preload_MISO;

  // Control preload signal.  Should be 1 when CS is high, but as soon as
  // first clock edge is seen it goes low.
  always_ff @(posedge SPI_Clk_Polarised or posedge SPI_CS_n_in) begin
    if (SPI_CS_n_in) begin
      preload_MISO <= 1'b1;
    end else begin
      preload_MISO <= 1'b0;
    end
  end

  // Transmit data bit by bit to master
  always_ff @(posedge SPI_Clk_Polarised or posedge SPI_CS_n_in) begin
    if (SPI_CS_n_in) begin
      TX_bit_count <= 31;
      SPI_MISO_bit <= TX_byte[31];
    end else begin
      TX_bit_count <= TX_bit_count - 1;
      SPI_MISO_bit <= TX_byte[TX_bit_count];
    end
  end

  logic prev_SPI_CS_n_in;
  // Save TX data from FPGA. Keeps registed TX byte in 
  // this module to get serialized and sent back to master.
  always_ff @(posedge clk_in) begin
    prev_SPI_CS_n_in <= SPI_CS_n_in;
    if (~rst_n_in) begin
      TX_byte <= 32'h00;
      ready   <= 1'b1;
    end else if (TX_valid_in & ready) begin
      TX_byte <= TX_byte_in;
      ready   <= 1'b0;
    end else if ((!prev_SPI_CS_n_in) && SPI_CS_n_in) begin
      ready <= 1'b1;
    end


  end

  assign SPI_MISO_out = preload_MISO ? TX_byte[31] : SPI_MISO_bit;

endmodule


