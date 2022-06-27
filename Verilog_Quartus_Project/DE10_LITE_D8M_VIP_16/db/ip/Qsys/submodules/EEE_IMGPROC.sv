// synthesis VERILOG_INPUT_VERSION SYSTEMVERILOG_2005

extern module RING_BUFFER #(
    parameter DATA_WIDTH = 27,
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

extern module SHIFT_REGGAE #(
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

extern module SHIFT_EXPOSED #(
    parameter NO_STAGES  = 5,
    parameter DATA_WIDTH = 26

) (
    //control signals
    input logic clk,
    input logic rst_n,
    input logic valid_in,

    //data signals 
    input  logic [DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0] internal_out[NO_STAGES-1:0],
    output logic [DATA_WIDTH-1:0] data_out
);


extern module RGB_TO_HSV (
    input logic clk,
    input logic rst_n,
    input logic valid_in,

    input  logic [23:0] rgb_in,
    output logic [23:0] hsv_out

);

extern module SPI_Slave #(
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

extern module SPI_BUFFER #(
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

module EEE_IMGPROC #(
    parameter IMAGE_W = 11'd640,
    parameter IMAGE_H = 11'd480,
    parameter MESSAGE_BUF_MAX = 256,
    parameter MSG_INTERVAL = 6,
    parameter BB_COL_DEFAULT = 24'h00ff00
) (
    // global clock & reset
    input logic clk,
    input logic reset_n,

    // mm slave
    input logic s_chipselect,
    input logic s_read,
    input logic s_write,
    output logic [31:0] s_readdata,
    input logic [31:0] s_writedata,
    input logic [2:0] s_address,


    // streaming sink
    input logic [23:0] sink_data,
    input logic sink_valid,
    output logic sink_ready,
    input logic sink_sop,
    input logic sink_eop,

    // streaming source
    output logic [23:0] source_data,
    output logic source_valid,
    input logic source_ready,
    output logic source_sop,
    output logic source_eop,

    input logic SPI_Clk,
    output logic SPI_MISO,
    input logic SPI_MOSI,
    input logic SPI_CS_n,
    // conduit export
    input logic mode
);

  ////////////////////////////////////////////////////////////////////////
  logic [7:0] red, green, blue, grey;
  logic [7:0] red_out, green_out, blue_out;

  logic sop, eop, in_valid, out_ready;
  ////////////////////////////////////////////////////////////////////////

  // Detect red areas
  logic red_detect;
  assign red_detect = red[7] & ~green[7] & ~blue[7]; //red detected if MSB is 1 for Red and 0 for Green, Blue

  // Find boundary of cursor box

  // Highlight detected areas
  logic [23:0] red_high;
  assign grey = green[7:1] + red[7:2] + blue[7:2]; //Grey = green/2 + red/4 + blue/4 <- Makes grayscale image (approx given formula)
  assign red_high = red_detect ? {8'hff, 8'h0, 8'h0} : {grey, grey, grey}; //if red is detected - we put red on that pixel

  // Show bounding box
  logic [23:0] new_image;
  logic bb_active;
  assign bb_active = (x == left) | (x == right) | (y == top) | (y == bottom); //bb_active if pixel is on any boundary line (on x or y axis)
  assign new_image = bb_active ? bb_col : red_high; //if we are on a boundary pixel; we set the colour to blue, if not; we set it to the computed highlighted (red_high) pixel colour

  logic packet_video;
  // Switch output pixels depending on mode switch
  // Don't modify the start-of-packet word - it's a packet discriptor
  // Don't modify data in non-video packets
  assign {red_out, green_out, blue_out} = (mode & ~sop & packet_video) ? new_image : {red,green,blue}; //if video packet : change content of new_image

  //Count valid pixels to tget the image coordinates. Reset and detect packet type on Start of Packet.
  logic [10:0] x, y;

  always_ff @(posedge clk) begin
    if (sop) begin  //if we have the start of packet header - we set x and y coordinates to 0
      x <= 11'h0;
      y <= 11'h0;
      packet_video <= (blue[3:0] == 3'h0);  //if the 4 LSB of blue are 0 we have a packet? IDK
    end else if (in_valid) begin
      if (x == IMAGE_W - 1) begin
        x <= 11'h0;
        y <= y + 11'h1;
      end else begin
        x <= x + 11'h1;
      end
    end
  end

  //Find first and last red pixels
  logic [10:0] x_min, y_min, x_max, y_max;
  always_ff @(posedge clk) begin
    if (red_detect & in_valid) begin  //Update bounds when the pixel is red
      if (x < x_min) x_min <= x;
      if (x > x_max) x_max <= x;
      if (y < y_min) y_min <= y;
      y_max <= y;
    end
    if (sop & in_valid) begin  //Reset bounds on start of packet
      x_min <= IMAGE_W - 11'h1;
      x_max <= 0;
      y_min <= IMAGE_H - 11'h1;
      y_max <= 0;
    end
  end

  //Process bounding box at the end of the frame.
  logic [1:0] msg_state;
  logic [10:0] left, right, top, bottom;
  logic [7:0] frame_count;
  always_ff @(posedge clk) begin
    if (eop & in_valid & packet_video) begin  //Ignore non-video packets

      //Latch edges for display overlay on next frame
      left <= x_min;
      right <= x_max;
      top <= y_min;
      bottom <= y_max;


      //Start message writer FSM once every MSG_INTERVAL frames, if there is room in the FIFO
      frame_count <= frame_count - 1;

      if (frame_count == 0 && msg_buf_size < MESSAGE_BUF_MAX - 3) begin
        msg_state   <= 2'b01;
        frame_count <= MSG_INTERVAL - 1;
      end
    end

    //Cycle through message writer states once started
    if (msg_state != 2'b00) msg_state <= msg_state + 2'b01;

  end

  //Generate output messages for CPU
  logic [31:0] msg_buf_in;
  logic [31:0] msg_buf_out;
  logic msg_buf_wr, msg_buf_rd, msg_buf_flush;
  logic [7:0] msg_buf_size;
  logic msg_buf_empty;

  `define RED_BOX_MSG_ID "RBB"

  always_ff @(*) begin  //Write words to FIFO as state machine advances
    case (msg_state)
      2'b00: begin
        msg_buf_in = 32'b0;
        msg_buf_wr = 1'b0;
      end
      2'b01: begin
        msg_buf_in = `RED_BOX_MSG_ID;  //Message ID
        msg_buf_wr = 1'b1;
      end
      2'b10: begin
        msg_buf_in = {5'b0, x_min, 5'b0, y_min};  //Top left coordinate
        msg_buf_wr = 1'b1;
      end
      2'b11: begin
        msg_buf_in = {5'b0, x_max, 5'b0, y_max};  //Bottom right coordinate
        msg_buf_wr = 1'b1;
      end
      default: begin
        msg_buf_in = 32'b0;
        msg_buf_wr = 1'b0;
      end
    endcase
  end

  //Output message FIFO
  MSG_FIFO MSG_FIFO_inst (
      .clock(clk),
      .data(msg_buf_in),
      .rdreq(msg_buf_rd),
      .sclr(~reset_n | msg_buf_flush),
      .wrreq(msg_buf_wr),
      .q(msg_buf_out),
      .usedw(msg_buf_size),
      .empty(msg_buf_empty)
  );

  //Streaming registers to buffer video signal
  logic stream_reg_1_ready;

  STREAM_REG #(.DATA_WIDTH(26)) in_reg (
    .clk(clk),
    .rst_n(reset_n),
    .ready_out(stream_reg_1_ready),
    .valid_out(in_valid),
    .data_out({red,green,blue,sop,eop}),
    .ready_in(out_ready),
    .valid_in(sink_valid),
    .data_in({sink_data,sink_sop,sink_eop})
  );

  logic [23:0] source_data_intermediate_step1;
  logic source_sop_intermediate_step1, source_eop_intermediate_step1;
  logic [23:0] source_data_exposed_step1;
  logic source_sop_exposed_step1, source_eop_exposed_step1;
  logic [25:0] row_1_data [15:0];

  //for modal Kernel

  

  logic [23:0] source_data_intermediate_step2;

  STREAM_REG #(.DATA_WIDTH(26)) out_reg (
    .clk(clk),
    .rst_n(reset_n),
    .ready_out(out_ready),
    .valid_out(source_valid),
    .data_out({source_data_intermediate_step1, source_sop_intermediate_step1, source_eop_intermediate_step1}),
    .ready_in(source_ready),
    .valid_in(in_valid),
    .data_in({red_out, green_out, blue_out, sop, eop})
  );

  // _________________ Building Detection __________________

  // 1. Convert to grayscale. 1 Clk delay

  logic [7:0] building_grayscaled;

  always_ff @(posedge clk) begin
    //Grey = red/4 + green/2 + blue/4 <- Makes grayscale image - is this from stotts code earlier? yes
    if(source_valid) begin
      building_grayscaled <= source_data_intermediate_step1[23:18] + source_data_intermediate_step1[15:9] + source_data_intermediate_step1[7:2]; 
    end
  end

  // 2. Buffer 3 pixels. 3 clk delay
  
  logic [7:0] sobel_throwaway;
  logic [7:0] sobel_data [2:0];
  SHIFT_EXPOSED #(.DATA_WIDTH(8), .NO_STAGES(3)) sobel_exposed (
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(source_valid),
    .data_in(building_grayscaled),
    .internal_out(sobel_data),
    .data_out(sobel_throwaway)
  );
  
  
  // 3. Perform Image Derivative/Sobel filter. 1 Clk Delay
  logic signed [8:0] sobel_tmp;
  always_ff @(posedge clk) begin
    if(source_valid) begin
      sobel_tmp <= sobel_data[0] - sobel_data[2];
    end
  end

  logic [8:0] sobel_tmp2;
  assign sobel_tmp2 = sobel_tmp < 0 ? -sobel_tmp : sobel_tmp;
  
  logic [7:0] sobel_out;
  assign sobel_out = sobel_tmp2[7:0];

  // 4. Threshold Image Derivative 1 Clk Delay
  logic [7:0] sobel_thresholded;
  
  always_ff @(posedge clk) begin
    if(source_valid) begin 
      if(sobel_out < 20) begin
        sobel_thresholded <= 8'h0;
      end else begin
        sobel_thresholded <= 8'd255;
      end
    end
  end

  
  // 5. Bounding box for building. Does not delay sobel data
  
  //Delayed versions of x, y coordinates
  logic [10:0] x_d6, y_d6;

  logic sop_d6, eop_d6, in_valid_d6, packet_video_d6;

  SHIFT_REGGAE #(.DATA_WIDTH(22), .NO_STAGES(6)) delay_x_y_6 (
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(source_valid),
    .data_in({x,y}),
    .data_out({x_d6, y_d6})
  );
  
  SHIFT_REGGAE #(.DATA_WIDTH(4), .NO_STAGES(6)) delay_signals_6 (
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(source_valid),
    .data_in({sop, eop, in_valid, packet_video}),
    .data_out({sop_d6, eop_d6, in_valid_d6, packet_video_d6})
  );

  logic [10:0] building_xmax, building_xmin;
  
  always_ff @(posedge clk) begin 
    if(sop_d6 & in_valid_d6) begin
      building_xmax <= 11'd0;
      building_xmin <= IMAGE_W - 11'd1;
    end 
    else if ((sobel_thresholded != {8'd0}) && (y_d6 > 240) && (x_d6 > 20) && (x_d6 < 620)) begin
      if(x_d6 < building_xmin) building_xmin <= x_d6; 
      if(x_d6 > building_xmax) building_xmax <= x_d6;  
    end
  end 

  logic [10:0] building_xmax_latch, building_xmin_latch; 
  
  always_ff @(posedge clk) begin
    if (eop_d6 & in_valid_d6 & packet_video_d6) begin
      building_xmin_latch <= building_xmin;
      building_xmax_latch <= building_xmax;
    end
  end

  // 6. Identify columns of the obstacles at a certain row.
  // Just as 5. this does not delay the main sobel data.

  logic [7:0] sobel_col_data [4:0];
  logic [7:0] sobel_throwaway_2;

  // source_threshold is d6, final element in this is d6 + NO STAGES
  SHIFT_EXPOSED #(.DATA_WIDTH(8), .NO_STAGES(5)) sobel_col_identify (
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(source_valid),
    .data_in(sobel_thresholded),
    .internal_out(sobel_col_data),
    .data_out(sobel_throwaway_2)
  );

  // For drawing lines at each detected collumn, get delayed versions of x, y and control signals
  logic [10:0] x_d11, y_d11;
  logic sop_d11, eop_d11, in_valid_d11, packet_video_d11;

  SHIFT_REGGAE #(.DATA_WIDTH(22), .NO_STAGES(11)) delay_x_y_11 (
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(source_valid),
    .data_in({x,y}),
    .data_out({x_d11, y_d11})
  );
  
  SHIFT_REGGAE #(.DATA_WIDTH(4), .NO_STAGES(11)) delay_signals_11 (
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(source_valid),
    .data_in({sop, eop, in_valid, packet_video}),
    .data_out({sop_d11, eop_d11, in_valid_d11, packet_video_d11})
  );

  logic obstacle_cols [639:0];

  always_ff @(posedge clk) begin 
    if(sop_d11 & in_valid_d11) begin
      for (integer i = 0; i < 640; i = i + 1) begin
        obstacle_cols[i] <= 1'b0;
      end
    end 
    else if(y_d11 == 359 && x_d11 > 60 && x_d11 < 580) begin
      if( (sobel_col_data[0] == 8'h0) &&
          (sobel_col_data[1] == 8'h0) && 
          (sobel_col_data[2] == 8'h0) &&
          (sobel_col_data[3] == 8'h0) &&
          (sobel_col_data[4] != 8'h0)) begin
            obstacle_cols[x_d11] <= 1'b1;
          end
    end
  end 

  logic obstacle_cols_latched [639:0]; 
  
  always_ff @(posedge clk) begin
    if (eop_d6 & in_valid_d6 & packet_video_d6) begin
      obstacle_cols_latched <= obstacle_cols;
    end
  end

  
  // 7. Delay to match other image processing pipelines
  // Name is a bit of a misnomer - d52 refers to delay of 52
  // of input, not since performing sobel
  logic [23:0] sobel_bounding_box;
  
  always_comb begin
    if((x_d6 == building_xmax_latch) | (x_d6 == building_xmin_latch)) begin
      sobel_bounding_box = 24'hFF0000;
    end else if(obstacle_cols_latched[x_d6] == 1'b1) begin
      sobel_bounding_box = 24'h00FF00;
    end else begin
      sobel_bounding_box = {sobel_thresholded, sobel_thresholded, sobel_thresholded};
    end

  end
  
  
  logic [23:0] sobel_d52;
  SHIFT_REGGAE #(.DATA_WIDTH(24), .NO_STAGES(46)) sobel_delay (
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(source_valid),
    .data_in(sobel_bounding_box),
    .data_out(sobel_d52)
  );


  // _________________ Building Detection End __________________
   
  SHIFT_EXPOSED #(.DATA_WIDTH(26), .NO_STAGES(16)) shift_exposed_1 (
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(source_valid),
    .data_in({source_data_intermediate_step1, source_sop_intermediate_step1, source_eop_intermediate_step1}),
    .internal_out(row_1_data),
    .data_out({source_data_intermediate_modal, source_sop_intermediate_modal, source_eop_intermediate_modal})
  );
  
  logic found_eop_or_sop;
  always_comb begin
    found_eop_or_sop = 0;

    for(integer i = 0; i < 16; i = i + 1) begin
      if(row_1_data[i][0] | row_1_data[i][1])
        begin 
        found_eop_or_sop = 1;
      end
    end
  end

  

  
  logic [25:0] fallback_data_d36;
  logic found_eop_or_sop_d36;

  SHIFT_REGGAE #(.DATA_WIDTH(27), .NO_STAGES(36)) shift_reg_fallback (
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(source_valid),
    .data_in({found_eop_or_sop, row_1_data[0][25:0]}),
    .data_out({found_eop_or_sop_d36, fallback_data_d36})
  );

  logic [23:0] gaus_blur_pixel;
  logic [31:0] gaus_intermidate_r, gaus_intermidate_g, gaus_intermidate_b;

  always_ff @(posedge clk) begin
    if(source_valid) begin
      gaus_intermidate_r <= (
                            {24'b0, row_1_data[0][25:18]} + 
                            ({24'b0, row_1_data[1][25:18]} << 3) +
                            ({24'b0, row_1_data[2][25:18]} * 28) + 
                            ({24'b0, row_1_data[3][25:18]} * 56)  +
                            ({24'b0, row_1_data[4][25:18]} * 70) +
                            ({24'b0, row_1_data[5][25:18]} * 56) + 
                            ({24'b0, row_1_data[6][25:18]} * 28) +
                            ({24'b0, row_1_data[7][25:18]} << 3) +
                            {24'b0, row_1_data[8][25:18]}) >> 8;

      gaus_intermidate_g <= (
                            {24'b0, row_1_data[0][17:10]} + 
                            ({24'b0, row_1_data[1][17:10]} << 3)+
                            ({24'b0, row_1_data[2][17:10]} * 28)+
                            ({24'b0, row_1_data[3][17:10]} *56)+
                            ({24'b0, row_1_data[4][17:10]} *70)+
                            ({24'b0, row_1_data[5][17:10]} *56)+
                            ({24'b0, row_1_data[6][17:10]} * 28)+
                            ({24'b0, row_1_data[7][17:10]} << 3)+
                            {24'b0, row_1_data[8][17:10]}) >> 8;

      gaus_intermidate_b <= (
                            {24'b0, row_1_data[0][9:2]} + 
                            ({24'b0, row_1_data[1][9:2]} << 3 )+
                            ({24'b0, row_1_data[2][9:2]} * 28 ) +
                            ({24'b0, row_1_data[3][9:2]} * 56)+
                            ({24'b0, row_1_data[4][9:2]} * 70 )+
                            ({24'b0, row_1_data[5][9:2]} * 56 ) +
                            ({24'b0, row_1_data[6][9:2]} *28)+
                            ({24'b0, row_1_data[7][9:2]} << 3)+
                            {24'b0, row_1_data[8][9:2]}) >> 8;
    end
  end 

  assign gaus_blur_pixel[23:16] = gaus_intermidate_r[7:0];
  assign gaus_blur_pixel[15:8] = gaus_intermidate_g[7:0];
  assign gaus_blur_pixel[7:0] = gaus_intermidate_b[7:0];

  
  logic [23:0] hsv_d20;
  RGB_TO_HSV hsv_converter (
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(source_valid),
    .rgb_in(gaus_blur_pixel),
    .hsv_out(hsv_d20)
  );

  logic [23:0] hsv_thresholded;

  // always_comb begin
  //   if ((hsv_d20[23:16] < 20 && hsv_d20[23:16] > 8) && hsv_d20[7:0] > 57) begin // red
  //     hsv_thresholded = {8'd255, 8'd0, 8'd0};
  //     //15 to 5 (to be checked) - Hue. 186 for value (apparently)
  //   end
  //   else if ((hsv_d20[23:16] < 55 && hsv_d20[23:16] > 35) && (hsv_d20[7:0] > 160 && hsv_d20[7:0] < 210) && (hsv_d20[15:8] > 130 && hsv_d20[15:8] < 200))// top half yellow
  //   begin
  //     hsv_thresholded = {8'd255, 8'd255, 8'd0};
  //   end
  //   else if ((hsv_d20[23:16] > 250 || hsv_d20[23:16] < 10) && (hsv_d20[7:0] > 140)) //&& (hsv_d20[15:8] > 163 && hsv_d20[15:8] < 199 )) // pink
  //   begin
  //     hsv_thresholded = {8'd168, 8'd50, 8'd153};
  //   end
  //   else if ((hsv_d20[23:16] < 175 && hsv_d20[23:16] > 130)) //&& (hsv_d20[7:0] > 25 && hsv_d20[7:0] < 50)) // && hsv_d20[15:8] > 100) // Dark blue
  //   begin
  //     hsv_thresholded = {8'd0, 8'd0, 8'd255};
  //   end
  //   else if (hsv_d20[23:16] < 85 && hsv_d20[23:16] > 60/*&& hsv_d20[7:0] > 130) */&& hsv_d20[15:8] < 200 && hsv_d20[15:8] > 120) // light green
  //   begin
  //     hsv_thresholded = {8'd0, 8'd255, 8'd0};
  //   end
  //   else if (hsv_d20[23:16] < 110 && hsv_d20[23:16] > 90)//&& hsv_d20[7:0] > 120) // teal
  //   begin
  //     hsv_thresholded = {8'd0, 8'd255, 8'd140};
  //   end
  //   else
  //   begin
  //     hsv_thresholded = {8'd0, 8'd0, 8'd0};
  //   end
  // end

  always_comb begin
    if ((hsv_d20[23:16] < 16 && hsv_d20[23:16] > 8) && hsv_d20[7:0] > 57) begin // red
      hsv_thresholded = {8'd255, 8'd0, 8'd0};
      //15 to 5 (to be checked) - Hue. 186 for value (apparently)
    end
    else if ((hsv_d20[23:16] < 43 && hsv_d20[23:16] > 35) && (hsv_d20[7:0] < 250 && hsv_d20[7:0] > 120))// top half yellow
    begin
      hsv_thresholded = {8'd255, 8'd255, 8'd0};
    end
    else if ((hsv_d20[23:16] > 250 || hsv_d20[23:16] < 10) && (hsv_d20[7:0] > 140)) //&& (hsv_d20[15:8] > 163 && hsv_d20[15:8] < 199 )) // pink
    begin
      hsv_thresholded = {8'd168, 8'd50, 8'd153};
    end
    else if ((hsv_d20[23:16] < 170 && hsv_d20[23:16] > 120) && (hsv_d20[7:0] < 102)) // && hsv_d20[15:8] > 100) // Dark blue
    begin
      hsv_thresholded = {8'd0, 8'd0, 8'd255}; //in gimp - picked up as low value (10-20%) teal NOT BLUE
    end
    else if (hsv_d20[23:16] < 78 && hsv_d20[23:16] > 71 && hsv_d20[7:0] < 200)// && hsv_d20[15:8] > 130) // light green
    begin
      hsv_thresholded = {8'd0, 8'd255, 8'd0};
    end
    else if (hsv_d20[23:16] < 100 && hsv_d20[23:16] > 78 && hsv_d20[7:0] > 51 && hsv_d20[7:0] < 102 && hsv_d20[15:8] < 130) // teal
    begin
      hsv_thresholded = {8'd0, 8'd255, 8'd140};
    end
    else
    begin
      hsv_thresholded = {8'd0, 8'd0, 8'd0};
    end
  end


  //______________________________Modal Kernel Below_____________________

  // FOR Modal Kernel
  logic [23:0] source_data_intermediate_modal;
  logic source_sop_intermediate_modal, source_eop_intermediate_modal;
  logic [23:0] source_data_exposed_modal [4:0][15:0];
  logic source_sop_exposed_modal, source_eop_exposed_modal;
  logic [25:0] modal_data [15:0];

  logic [23:0] throwaway [4:0];
  logic [23:0] hsv_intermediate [4:0];


  SHIFT_EXPOSED #(.DATA_WIDTH(24), .NO_STAGES(16)) shift_exposed_modal_row1 (
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(source_valid),
    .data_in(hsv_thresholded),
    .internal_out(source_data_exposed_modal[0]),
    .data_out(throwaway[0])
  );

  SHIFT_REGGAE #(.DATA_WIDTH(24), .NO_STAGES(640)) shift_reg_row2 (
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(source_valid),
    .data_in(hsv_thresholded),
    .data_out(hsv_intermediate[0])
  );

  SHIFT_EXPOSED #(.DATA_WIDTH(24), .NO_STAGES(16)) shift_exposed_modal_row2 (
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(source_valid),
    .data_in(hsv_intermediate[0]),
    .internal_out(source_data_exposed_modal[1]),
    .data_out(throwaway[1])
  );

  SHIFT_REGGAE #(.DATA_WIDTH(24), .NO_STAGES(640)) shift_reg_row3 (
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(source_valid),
    .data_in(hsv_intermediate[0]),
    .data_out(hsv_intermediate[1])
  );

  SHIFT_EXPOSED #(.DATA_WIDTH(24), .NO_STAGES(16)) shift_exposed_modal_row3 (
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(source_valid),
    .data_in(hsv_intermediate[1]),
    .internal_out(source_data_exposed_modal[2]),
    .data_out(throwaway[2])
  );

  // SHIFT_REGGAE #(.DATA_WIDTH(24), .NO_STAGES(640)) shift_reg_row4 (
  //   .clk(clk),
  //   .rst_n(reset_n),
  //   .valid_in(source_valid),
  //   .data_in(hsv_intermediate[1]),
  //   .data_out(hsv_intermediate[2])
  // );

  // SHIFT_EXPOSED #(.DATA_WIDTH(24), .NO_STAGES(16)) shift_exposed_modal_row4 (
  //   .clk(clk),
  //   .rst_n(reset_n),
  //   .valid_in(source_valid),
  //   .data_in(hsv_intermediate[2]),
  //   .internal_out(source_data_exposed_modal[3]),
  //   .data_out(throwaway[3])
  // );

  // SHIFT_REGGAE #(.DATA_WIDTH(24), .NO_STAGES(640)) shift_reg_row5 (
  //   .clk(clk),
  //   .rst_n(reset_n),
  //   .valid_in(source_valid),
  //   .data_in(hsv_intermediate[2]),
  //   .data_out(hsv_intermediate[3])
  // );

  // SHIFT_EXPOSED #(.DATA_WIDTH(24), .NO_STAGES(16)) shift_exposed_modal_row5 (
  //   .clk(clk),
  //   .rst_n(reset_n),
  //   .valid_in(source_valid),
  //   .data_in(hsv_intermediate[3]),
  //   .internal_out(source_data_exposed_modal[4]),
  //   .data_out(throwaway[4])
  // );

  
  logic [7:0] count_t1; 
  logic [7:0] count_t2; 
  logic [7:0] count_t3; 
  logic [7:0] count_t4; 
  logic [7:0] count_t5; 
  logic [7:0] count_t6; 
  logic [7:0] count_t7;

  logic [7:0] count_max;

  logic [23:0] modal_data_out;

  always_comb begin

    count_t1 = 0; 
    count_t2 = 0; 
    count_t3 = 0; 
    count_t4 = 0; 
    count_t5 = 0; 
    count_t6 = 0; 
    count_t7 = 0;
    count_max = 0;
    
  
    for(integer j = 0; j < 3; j++) begin
      for(integer i = 0; i<16; i++) begin
        if (source_data_exposed_modal[j][i] == {8'd255, 8'd0, 8'd0}) begin
          count_t1 = count_t1 + 1; 
        end
        if (source_data_exposed_modal[j][i] == {8'd255, 8'd255, 8'd0}) begin
          count_t2 = count_t2 + 1; 
        end
        if (source_data_exposed_modal[j][i] == {8'd168, 8'd50, 8'd153}) begin
          count_t3 = count_t3 + 1; 
        end
        if (source_data_exposed_modal[j][i] ==  {8'd0, 8'd0, 8'd255}) begin
          count_t4 = count_t4 + 1; 
        end
        if (source_data_exposed_modal[j][i] == {8'd0, 8'd255, 8'd0}) begin
          count_t5 = count_t5 + 1; 
        end
        if (source_data_exposed_modal[j][i] ==  {8'd0, 8'd255, 8'd140} ) begin
          count_t6 = count_t6 + 1; 
        end
        if (source_data_exposed_modal[j][i] == {8'd0, 8'd0, 8'd0} ) begin
          count_t7 = count_t7 + 1; 
        end
      end
    end

    modal_data_out = source_data_exposed_modal[0][7];

    if(count_t1 > count_t2 && 
       count_t1 > count_t3 && 
       count_t1 > count_t4 && 
       count_t1 > count_t5 &&
       count_t1 > count_t6 &&
       count_t1 > count_t7) begin
        modal_data_out = {8'd255, 8'd0, 8'd0};
        count_max = count_t1;
    end

    else if(count_t2 > count_t1 && 
       count_t2 > count_t3 && 
       count_t2 > count_t4 && 
       count_t2 > count_t5 &&
       count_t2 > count_t6 &&
       count_t2 > count_t7) begin
      modal_data_out = {8'd255, 8'd255, 8'd0};
      count_max = count_t2;
    end
    else if(count_t3 > count_t1 && 
       count_t3 > count_t2 && 
       count_t3 > count_t4 && 
       count_t3 > count_t5 &&
       count_t3 > count_t6 &&
       count_t3 > count_t7) begin
       modal_data_out = {8'd168, 8'd50, 8'd153};
       count_max = count_t3;
    end
    else if(count_t4 > count_t1 && 
       count_t4 > count_t2 && 
       count_t4 > count_t3 && 
       count_t4 > count_t5 &&
       count_t4 > count_t6 &&
       count_t4 > count_t7) begin
      modal_data_out = {8'd0, 8'd0, 8'd255};
      count_max = count_t4;
    end

    else if(count_t5 > count_t1 && 
       count_t5 > count_t2 && 
       count_t5 > count_t3 && 
       count_t5 > count_t4 &&
       count_t5 > count_t6 &&
       count_t5 > count_t7) begin
      modal_data_out = {8'd0, 8'd255, 8'd0};
      count_max = count_t5;
    end


    else if(count_t6 > count_t1 && 
       count_t6 > count_t2 && 
       count_t6 > count_t3 && 
       count_t6 > count_t4 &&
       count_t6 > count_t5 &&
       count_t6 > count_t7) begin
        modal_data_out = {8'd0, 8'd255, 8'd128};
        count_max = count_t6;
    end 

    if(count_t7 > count_t1 && 
       count_t7 > count_t2 && 
       count_t7 > count_t3 && 
       count_t7 > count_t4 &&
       count_t7 > count_t5 &&
       count_t7 > count_t6) begin
        modal_data_out = {8'd0, 8'd0, 8'd0};
        count_max = count_t7;
    end

    if(count_max < 40) begin
      modal_data_out = {8'd0, 8'd0, 8'd0};
    end           
  end

    
//__________________________________end Modal Kernel ___________________________





//----------------- bounding box code--------------------------------

//dealy sop and eop signals by 52 cycles
SHIFT_REGGAE #(.DATA_WIDTH(4), .NO_STAGES(52)) shift_reg_sop_eop_invalid (
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(source_valid),
    .data_in({sop, eop, in_valid, packet_video}),
    .data_out({sop_d52, eop_d52, in_valid_d52, packet_video_d52})
  );
  logic sop_d52, eop_d52, in_valid_d52, packet_video_d52; //delayed start and end of packet and in_valid

//Delay the x,y coordinates calculated by Stott by 52 cycles
SHIFT_REGGAE #(.DATA_WIDTH(22), .NO_STAGES(52)) shift_reg_x_y (
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(source_valid),
    .data_in({x, y}),
    .data_out({x_d52, y_d52})
  );


  //delayed x,y coordinates
  logic [10:0] x_d52,y_d52;
  //current bounderies of red_object
  logic [10:0] x_left_red, x_right_red;
  //current bounderies of yellow_object
  logic [10:0] x_left_yellow, x_right_yellow;
  //current bounderies of pink_object
  logic [10:0] x_left_pink, x_right_pink;
  //current bounderies of blue_object
  logic [10:0] x_left_blue, x_right_blue;
  //current bounderies of green_object
  logic [10:0] x_left_green, x_right_green;
  //current bounderies of teal_object
  logic [10:0] x_left_teal, x_right_teal;

  always_ff @(posedge clk) begin 
    if(sop_d52 & in_valid_d52) begin
      //on receiving new frame set left limit to far right
      //and right limit to far left (horseshoe theory)
      
      //for red
      x_left_red <= IMAGE_W- 11'd1;
      x_right_red <= 11'd0;
      //for yellow
      x_left_yellow <= IMAGE_W- 11'd1;
      x_right_yellow <= 11'd0;
      //for pink
      x_left_pink <= IMAGE_W- 11'd1;
      x_right_pink <= 11'd0;
      //for blue
      x_left_blue <= IMAGE_W- 11'd1;
      x_right_blue <= 11'd0;
      //for green
      x_left_green <= IMAGE_W- 11'd1;
      x_right_green <= 11'd0;
      //for teal
      x_left_teal <= IMAGE_W- 11'd1;
      x_right_teal <= 11'd0;
      
    end
    else if (y_d52 >= 240) begin
      if(modal_data_out == {8'd255,8'd0,8'd0}) begin
        //red
        if(x_d52 < x_left_red) x_left_red <= x_d52;
        if(x_d52 > x_right_red) x_right_red <= x_d52;
      end
      else if(modal_data_out == {8'd255, 8'd255, 8'd0}) begin
        //yellow
        if(x_d52 < x_left_yellow) x_left_yellow <= x_d52;
        if(x_d52 > x_right_yellow) x_right_yellow <= x_d52;
      end
      else if(modal_data_out == {8'd168, 8'd50, 8'd153}) begin
        //pink
        if(x_d52 < x_left_pink) x_left_pink <= x_d52;
        if(x_d52 > x_right_pink) x_right_pink <= x_d52;
      end
      else if(modal_data_out == {8'd0, 8'd0, 8'd255}) begin
        //blue
        if(x_d52 < x_left_blue) x_left_blue <= x_d52;
        if(x_d52 > x_right_blue) x_right_blue <= x_d52;
      end
      else if(modal_data_out == {8'd0, 8'd255, 8'd0}) begin
        //green
        if(x_d52 < x_left_green) x_left_green <= x_d52;
        if(x_d52 > x_right_green) x_right_green <= x_d52;
      end
      else if(modal_data_out == {8'd0, 8'd255, 8'd140}) begin
        //teal
        if(x_d52 < x_left_teal) x_left_teal <= x_d52;
        if(x_d52 > x_right_teal) x_right_teal <= x_d52;
      end    
    end 
  end 


  //We need to keep a latched version of x_left_red and x_right_red upon FINISHING A FRAME
  logic [10:0] x_left_r_frame, x_right_r_frame, x_left_p_frame, x_right_p_frame, x_left_b_frame, x_right_b_frame, x_left_y_frame, x_right_y_frame, x_left_g_frame, x_right_g_frame, x_left_t_frame, x_right_t_frame; 
  always_ff @(posedge clk) begin 
    if(eop_d52 & in_valid_d52 & packet_video_d52) begin //Need packet video to ensure that we only modify non-video packets
      //red
      x_left_r_frame <= x_left_red;
      x_right_r_frame <= x_right_red;
      //yellow
      x_left_y_frame <= x_left_yellow;
      x_right_y_frame <= x_right_yellow;
      //pink
      x_left_p_frame <= x_left_pink;
      x_right_p_frame <= x_right_pink;
      //blue
      x_left_b_frame <= x_left_blue;
      x_right_b_frame <= x_right_blue; 
      //green
      x_left_g_frame <= x_left_green;
      x_right_g_frame <= x_right_green;
      //teal
      x_left_t_frame <= x_left_teal;
      x_right_t_frame <= x_right_teal;  
    end 
    
  end 
  
  logic [23:0] bounding_boxed_data;
  
  always_ff @(posedge clk) begin 
    if (source_valid) begin
      if(x_d52 == x_left_r_frame || x_d52 == x_right_r_frame) begin
        bounding_boxed_data <= {24'hFF0000}; //white borders 
      end 
      else if (x_d52 == x_left_y_frame || x_d52 == x_right_y_frame) begin 
        bounding_boxed_data <= {24'hFFFF00}; //brown borders
      end 
      else if (x_d52 == x_left_p_frame || x_d52 == x_right_p_frame) begin 
        bounding_boxed_data <= {24'hA93399}; //blue borders
      end 
      else if (x_d52 == x_left_b_frame || x_d52 == x_right_b_frame) begin 
        bounding_boxed_data <= {24'h0000FF}; //beige borders
      end 
      else if (x_d52 == x_left_g_frame || x_d52 == x_right_g_frame) begin 
        bounding_boxed_data <= {24'h00FF00}; //violet borders
      end 
      else if (x_d52 == x_left_t_frame || x_d52 == x_right_t_frame) begin 
        bounding_boxed_data <= {24'h00FF8D}; //orange borders
      end 
      else begin
        bounding_boxed_data <= modal_data_out;
      end
    end
  end 

  
  //if left or right frame, white otherwise use the hue output
  // assign bounding_boxed_data = (x_d52 == x_left_r_frame | x_d52 == x_right_r_frame) ? {8'd255, 8'd255, 8'd255} : modal_data_out;
  //__________________________________end bounding box code__________________________________
  
  

  // ___________________________ Communication with peripherals ____________________________
  //assign source_data = found_eop_or_sop_d36 ? fallback_data_d36[25:2] : bounding_boxed_data;

  logic [23:0] final_out_pixel;
  assign final_out_pixel = (sobel_d52 == 24'b0) ? bounding_boxed_data : sobel_d52;
  assign source_data = found_eop_or_sop_d36 ? fallback_data_d36[25:2] : final_out_pixel;

  //assign source_data = centre_pixel_d20[25:2];
  assign source_sop = fallback_data_d36[1];
  assign source_eop = fallback_data_d36[0];


  
  logic [3:0] spi_state;
  parameter SPI_IDLE = 4'd0;
  parameter SPI_READY_TO_TRANS = 4'd1;
  parameter SPI_TRANSMIT_COLS = 4'd2;
  parameter SPI_RED_BB = 4'd3;
  parameter SPI_BLUE_BB = 4'd4;
  parameter SPI_PINK_BB = 4'd5;
  parameter SPI_YELLOW_BB = 4'd6;
  parameter SPI_GREEN_BB = 4'd7;
  parameter SPI_TEAL_BB = 4'd8;

  logic [10:0] cols_transmitted;

  logic [31:0] spi_slave_data_in;
  logic spi_slave_ready;
  logic end_of_frame_d52;

  initial begin
    spi_state = SPI_IDLE;
  end 

  assign sink_ready = stream_reg_1_ready;
  assign end_of_frame_d52 = eop_d52 & in_valid_d52 & packet_video_d52;

  always_ff @(posedge clk) begin
    case (spi_state)
      SPI_IDLE: begin
        //spi_slave_data_in <= {16'hCCCC, 12'b0, spi_slave_ready, eop_d52, in_valid_d52,  packet_video_d52};
		    spi_slave_data_in <= {SPI_IDLE, 28'h0};


        if(end_of_frame_d52) begin
          // if reached end of frame, switch to transmitting data
          //spi_slave_data_in <= 32'hBBBB0000;
          spi_state <= SPI_READY_TO_TRANS;
        end
      end

      SPI_READY_TO_TRANS: begin
        spi_slave_data_in <= {SPI_READY_TO_TRANS, 28'h0};
        if(spi_slave_ready) begin
          spi_state <= SPI_TRANSMIT_COLS;
          cols_transmitted <= 0;
        end
      end

      SPI_TRANSMIT_COLS: begin
        
		    for(integer i = 0; i < 28; i = i + 1) begin
          spi_slave_data_in[i] <= obstacle_cols_latched[cols_transmitted + i - 1];
        end

		    spi_slave_data_in[31:28] <= SPI_TRANSMIT_COLS;

        if(spi_slave_ready) begin
          
          if(cols_transmitted >= 640) begin
            // We have transmitted all columns, go back to idle
            spi_state <= SPI_RED_BB;
            spi_slave_data_in <= {SPI_TRANSMIT_COLS, 28'h9999000};
          end else begin
            // We have more columns to transmit, transmit!
            spi_state <= SPI_TRANSMIT_COLS;
            cols_transmitted <= cols_transmitted + 30;
          end
      	end
	    end

      SPI_RED_BB: begin
        // 32 - 4 - 22 = 6
				spi_slave_data_in <= {SPI_RED_BB, 1'b0, x_left_r_frame, 5'b0, x_right_r_frame};

        if(spi_slave_ready) begin
          spi_state <= SPI_BLUE_BB; 
        end else begin
          spi_state <= SPI_RED_BB;
        end
      end

      SPI_BLUE_BB: begin
        spi_slave_data_in <= {SPI_BLUE_BB, 1'b0, x_left_b_frame, 5'b0, x_right_b_frame};

        if(spi_slave_ready) begin
          spi_state <= SPI_PINK_BB; 
        end else begin
          spi_state <= SPI_BLUE_BB;
        end
      end

			SPI_PINK_BB: begin
        spi_slave_data_in <= {SPI_PINK_BB, 1'b0, x_left_p_frame, 5'b0, x_right_p_frame};

        if(spi_slave_ready) begin
          spi_state <= SPI_YELLOW_BB; 
        end else begin
          spi_state <= SPI_PINK_BB;
        end
      end

			SPI_YELLOW_BB: begin
        spi_slave_data_in <= {SPI_YELLOW_BB, 1'b0, x_left_y_frame, 5'b0, x_right_y_frame};

        if(spi_slave_ready) begin
          spi_state <= SPI_GREEN_BB; 
        end else begin
          spi_state <= SPI_YELLOW_BB;
        end
      end

			SPI_GREEN_BB: begin
        spi_slave_data_in <= {SPI_GREEN_BB, 1'b0, x_left_g_frame, 5'b0, x_right_g_frame};

        if(spi_slave_ready) begin
          spi_state <= SPI_TEAL_BB; 
        end else begin
          spi_state <= SPI_GREEN_BB;
        end
      end

			SPI_TEAL_BB: begin
        spi_slave_data_in <= {SPI_TEAL_BB, 1'b0, x_left_t_frame, 5'b0, x_right_t_frame};

        if(spi_slave_ready) begin
          spi_state <= SPI_IDLE; 
        end else begin
          spi_state <= SPI_TEAL_BB;
        end
      end

      default: begin
        // State not recognised, return to idle state.
        spi_state <= SPI_IDLE;
        spi_slave_data_in <= 32'hFFFF0000;
      end
    endcase

	end

	/*
    if (eop_d52 & in_valid_d52 & packet_video_d52) begin
      
	  // End of frame encountered, we wish to transmit the columns detected
	  // by our edge detection algorithm.
	  spi_state <= SPI_TRANSMIT_COLS;
      cols_transmitted <= 0;
	  // To indicate start of transmission send off BB's to ESP
      spi_slave_data_in <= 32'hBBBB0000; //an arbitrary debug value
    end
	*/

	


	/*

    // Only if the SPI is ready proporgate the messages
    if(spi_slave_ready) begin
      
		// 
		


	  if(cols_transmitted >= 640) begin 
        // We have sent all collumns. Go to next state
        spi_state <= SPI_IDLE;
        cols_transmitted <= 32'h0;
        spi_slave_data_in <= 32'hAAAA0000;
      end else begin
        cols_transmitted <= cols_transmitted + 30;
        
        for(integer i = 0; i < 30; i = i + 1) begin
          spi_slave_data_in[i] <= obstacle_cols_latched[cols_transmitted + i - 1];
        end
        
        spi_slave_data_in[31:30] <= {2'b11};
      end 
    end
	*/
    

    /*
    if (eop_d52 & in_valid_d52 & packet_video_d52) begin
      // end of frame reached, tell ESP we are about to send 
      
      spi_state <= SPI_TRANSMIT_COLS;
      
      spi_slave_data_in <= 32'hFFFF0000;
      cols_transmitted <= 11'h0;
    end else if(spi_slave_ready) begin
      // SPI is ready to recieve, we can transmit data and proporgate the state machine

      if (spi_state == SPI_TRANSMIT_COLS) begin
        
        if(cols_transmitted == 0) begin
          // Start off with a header telling ESP what we are
          // about to send
          spi_slave_data_in <= 32'hBBBB0000;
          cols_transmitted <= cols_transmitted + 1;
        end else if(cols_transmitted >= 641) begin 
          // We have sent all collumns. Go to next state
          spi_state <= SPI_IDLE;
          cols_transmitted <= 32'h0;
          spi_slave_data_in <= 32'hAAAA0000;
        end else begin
          cols_transmitted <= cols_transmitted + 30;
          
          
          // for(integer i = 0; i < 30; i = i + 1) begin
          //   spi_slave_data_in[i] <= obstacle_cols_latched[cols_transmitted + i - 1];
          // end
          
          
          spi_slave_data_in <= {4'h9, 17'b0 , cols_transmitted};
          
        end 
      end else if(spi_state == SPI_IDLE) begin
        spi_slave_data_in <= {5'b0, x_d52, 5'b0, y_d52};
      end
  end
  */
  // end
  

  /*
  logic spi_buffer_valid, spi_buffer_ready;
  
  

  SPI_BUFFER #(.CAPACITY(64), .DATA_WIDTH(32)) spi_buffer_1 (
    //control signals
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(1'b1),
    .ready_in(spi_slave_ready),
    .valid_out(spi_buffer_valid),
    .ready_out(spi_buffer_ready),

    //data signals 
    .data_in({5'b0, x, 5'b0, y}),
    .data_out(spi_slave_data_in)
  );
  */
  


  SPI_Slave #(.CLK_POL(1), .CLK_PHA(1)) spi_slave_1 (
    .clk_in(clk),
    .rst_n_in(reset_n),

    // Signals to interface with rest of FPGA
    .TX_valid_in(1'b1),
    .TX_byte_in(spi_slave_data_in),
	  .ready_out(spi_slave_ready),
    
    // External SPI Interface signals
    .SPI_Clk_in(SPI_Clk),
    .SPI_MISO_out(SPI_MISO),
    .SPI_MOSI_in(SPI_MOSI),
    .SPI_CS_n_in(SPI_CS_n)    // active low
  );

  // assign source_data = row_3_data[2][25:2];

  /////////////////////////////////
  /// Memory-mapped port		 /////
  /////////////////////////////////

  // Addresses
  `define REG_STATUS 0
  `define READ_MSG 1
  `define READ_ID 2
  `define REG_BBCOL 3

  //Status register bits
  // 31:16 - unimplemented
  // 15:8 - number of words in message buffer (read only)
  // 7:5 - unused
  // 4 - flush message buffer (write only - read as 0)
  // 3:0 - unused


  // Process write

  logic [ 7:0] reg_status;
  logic [23:0] bb_col;

  always_ff @(posedge clk) begin
    if (~reset_n) begin
      reg_status <= 8'b0;
      bb_col <= BB_COL_DEFAULT;
    end else begin
      if (s_chipselect & s_write) begin
        if (s_address == `REG_STATUS) reg_status <= s_writedata[7:0];
        if (s_address == `REG_BBCOL) bb_col <= s_writedata[23:0];
      end
    end
  end


  //Flush the message buffer if 1 is written to status register bit 4
  assign msg_buf_flush = (s_chipselect & s_write & (s_address == `REG_STATUS) & s_writedata[4]);

  // Process reads
  logic read_d;  //Store the read signal for correct updating of the message buffer

  // Copy the requested word to the output port when there is a read.
  always_ff @(posedge clk) begin
    if (~reset_n) begin
      s_readdata <= {32'b0};
      read_d <= 1'b0;
    end else if (s_chipselect & s_read) begin
      if (s_address == `REG_STATUS) s_readdata <= {16'b0, msg_buf_size, reg_status};
      if (s_address == `READ_MSG) s_readdata <= {msg_buf_out};
      if (s_address == `READ_ID) s_readdata <= 32'h1234EEE2;
      if (s_address == `REG_BBCOL) s_readdata <= {8'h0, bb_col};
    end

    read_d <= s_read;
  end

  //Fetch next word from message buffer after read from READ_MSG
  assign msg_buf_rd = s_chipselect & s_read & ~read_d & ~msg_buf_empty & (s_address == `READ_MSG);



endmodule