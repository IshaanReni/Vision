module RGB_TO_HSV (
    input logic clk,
    input logic rst_n,
    input logic valid_in,
    input logic [23:0] rgb_in,
    output logic [7:0] hue

);

  multi_divider HSV_Divider (
      .clock(clk),
      .denom(hue_bot),
      .numer(hue_top),
      .quotient(hue_quotient),
      .remain(hue_remainder)
  );

  logic [7:0] red_d0, green_d0, blue_d0;
  logic [7:0] red_d1, green_d1, blue_d1;
  logic [7:0] red_d2, green_d2, blue_d2;

  logic [7:0] min, max, delta;

  logic [7:0] max_delayed;
  logic [16:0] hue_negative_delayed;
  logic [15:0] hue_add_delayed[16:0];

  //_top refers to the numerator whereas _bot refers to the denominator
  logic [15:0] hue_top, hue_bot;
  logic [15:0] hue_quotient, hue_remainder;

  always_ff @(posedge clk) begin

    if (valid_in) begin
      // Clk 1: Latch inputs
      {red_d0, green_d0, blue_d0} <= rgb_in;

      // Clk 2: Compute minimum/maximum
      {red_d1, green_d1, blue_d1} <= {red_d0, green_d0, blue_d0};

      if ((red_d0 >= green_d0) && (red_d0 >= blue_d0)) begin
        max <= red_d0;
      end else if ((green_d0 >= red_d0) && (green_d0 >= blue_d0)) begin
        max <= green_d0;
      end else begin
        max <= blue_d0;
      end

      if ((red_d0 <= green_d0) && (red_d0 <= blue_d0)) begin
        min <= red_d0;
      end else if ((green_d0 <= red_d0) && (green_d0 <= blue_d0)) begin
        min <= green_d0;
      end else begin
        min <= blue_d0;
      end

      // Clk 3: Compute the delta
      {red_d2, green_d2, blue_d2} <= {red_d1, green_d1, blue_d1};
      delta <= max - min;
      max_delayed <= max;


      // Clk 4: Top and bottom calculations for conversion
      if (red_d2 == max_delayed) begin
        hue_top <= (green_d2 >= blue_d2) ? (green_d2-blue_d2)*8'd255:(blue_d2 - green_d2) * 8'd255;
        hue_negative_delayed[0] <= (green_d2 >= blue_d2) ? 0 : 1;
        hue_add_delayed[0] <= 16'd0;
      end else if (green_d2 == max_delayed) begin
        hue_top <= (blue_d2 >= red_d2) ? (blue_d2 - red_d2) * 8'd255 : (red_d2 - blue_d2) * 8'd255;
        hue_negative_delayed[0] <= (blue_d2 >= red_d2) ? 0 : 1;
        hue_add_delayed[0] <= 16'd85;
      end else if (blue_d2 == max_delayed) begin
        hue_top <= (red_d2 >= green_d2) ? (red_d2 - green_d2) * 8'd255 : (green_d2 - red_d2) * 8'd255;
        hue_negative_delayed[0] <= (red_d2 >= green_d2) ? 0 : 1;
        hue_add_delayed[0] <= 16'd170;
      end

      hue_bot <= (delta > 0) ? delta * 8'd6 : 16'd6;

      for (integer i = 1; i < 17; i = i + 1) begin
        hue_negative_delayed[i] <= hue_negative_delayed[i-1];
        hue_add_delayed[i] <= hue_add_delayed[i-1];
      end

      //Clock 20: Final Value of h
      if (hue_negative_delayed[16] && (hue_quotient > hue_add_delayed[16])) begin
        //Subtract 255 from h to come back to the start
        hue <= 8'd255 - hue_quotient[7:0] + hue_add_delayed[16];
      end else if (hue_negative_delayed[16]) begin
        hue <= hue_add_delayed[16] - hue_quotient[7:0];
      end else begin
        hue <= hue_quotient[7:0] + hue_add_delayed[16];
      end
    end


  end

endmodule
