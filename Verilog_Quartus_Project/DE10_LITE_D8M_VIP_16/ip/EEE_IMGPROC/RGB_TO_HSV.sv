module RGB_TO_HSV (
    input logic clk,
    input logic rst_n,

    input  logic [23:0] rgb_in,
    output logic [23:0] hsv_out

);

  multi_divider HSV_Divider (
      .clock(clk),
      .denom(h_bot),
      .numer(h_top),
      .quotient(h_quotient),
      .remain(h_remainder)
  );

  logic [7:0] red_d0, green_d0, blue_d0;
  logic [7:0] red_d1, green_d1, blue_d1;
  logic [7:0] red_d2, green_d2, blue_d2;

  logic [7:0] min, max, delta;

  logic [7:0] max_delayed[17:0];
  logic [16:0] h_negative_delayed;
  logic [15:0] h_add_delayed[16:0];

  logic [15:0] h_top, h_bot;
  logic [15:0] h_quotient, h_remainder;

  logic [7:0] s_top, s_bot;

  always_ff @(posedge clk) begin

    // Clk 1: Latch inputs
    {red_d0, green_d0, blue_d0} <= rgb_in;

    // Clk 2: Compute min/max
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
    max_delayed[0] <= max;


    // Clk 4: Top and bottom calculations for conversion
    s_top <= 8'd255 * delta;
    s_bot <= (max_delayed[0] > 0) ? {8'd0, max_delayed[0]} : 16'd1;

    if (red_d2 == max_delayed[0]) begin
      h_top <= (green_d2 >= blue_d2)?(green_d2-blue_d2)*8'd255:(blue_d2 - green_d2) * 8'd255;
      h_negative_delayed[0] <= (green_d2 >= blue_d2) ? 0 : 1;
      h_add_delayed[0] <= 16'd0;
    end else if (green_d2 == max_delayed[0]) begin
      h_top <= (blue_d2 >= red_d2) ? (blue_d2 - red_d2) * 8'd255 : (red_d2 - blue_d2) * 8'd255;
      h_negative_delayed[0] <= (blue_d2 >= red_d2) ? 0 : 1;
      h_add_delayed[0] <= 16'd85;
    end else if (blue_d2 == max_delayed[0]) begin
      h_top <= (red_d2 >= green_d2) ? (red_d2 - green_d2) * 8'd255 : (green_d2 - red_d2) * 8'd255;
      h_negative_delayed[0] <= (red_d2 >= green_d2) ? 0 : 1;
      h_add_delayed[0] <= 16'd170;
    end

    h_bot <= (delta > 0) ? delta * 8'd6 : 16'd6;

    for (integer i = i; i < 17; i = i + 1) begin
      max_delayed[i] = max_delayed[i-1];
      h_negative_delayed[i] <= h_negative_delayed[i-1];
      h_add_delayed[i] <= h_add_delayed[i-1];
    end

    max_delayed[17] <= max_delayed[16];

    //Clock 22: Final Value of h
    if (h_negative_delayed[16] && (h_quotient > h_add_delayed[16])) begin
      h <= 8'd255 - h_quotient[7:0] + h_add_delayed[16];
    end else if (h_negative_delayed[16]) begin
      h <= h_add_delayed[16] - h_quotient[7:0];
    end else begin
      h <= h_quotient[7:0] + h_add_delayed[16];
    end

  end

endmodule
