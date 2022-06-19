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

    
    // streaming sink fifo1
    input logic [31:0] sink_data_fifo1,
    input logic sink_valid_fifo1,
    output logic sink_ready_fifo1,
    input logic sink_sop_fifo1,
    input logic sink_eop_fifo1,

    // streaming source fifo1
    output logic [31:0] source_data_fifo1,
    output logic source_valid_fifo1,
    input logic source_ready_fifo1,
    output logic source_sop_fifo1,
    output logic source_eop_fifo1,


    // streaming sink fifo2
    input logic [31:0] sink_data_fifo2,
    input logic sink_valid_fifo2,
    output logic sink_ready_fifo2,
    input logic sink_sop_fifo2,
    input logic sink_eop_fifo2,

    // streaming source fifo2
    output logic [31:0] source_data_fifo2,
    output logic source_valid_fifo2,
    input logic source_ready_fifo2,
    output logic source_sop_fifo2,
    output logic source_eop_fifo2,


    // streaming sink fifo3
    input logic [31:0] sink_data_fifo3,
    input logic sink_valid_fifo3,
    output logic sink_ready_fifo3,
    input logic sink_sop_fifo3,
    input logic sink_eop_fifo3,

    // streaming source fifo3
    output logic [31:0] source_data_fifo3,
    output logic source_valid_fifo3,
    input logic source_ready_fifo3,
    output logic source_sop_fifo3,
    output logic source_eop_fifo3,


    // streaming sink fifo4
    input logic [31:0] sink_data_fifo4,
    input logic sink_valid_fifo4,
    output logic sink_ready_fifo4,
    input logic sink_sop_fifo4,
    input logic sink_eop_fifo4,

    // streaming source fifo4
    output logic [31:0] source_data_fifo4,
    output logic source_valid_fifo4,
    input logic source_ready_fifo4,
    output logic source_sop_fifo4,
    output logic source_eop_fifo4,

    /*
    //FIFO ADDED FOR MODAL KERNEL

    // streaming sink fifo5
    input logic [31:0] sink_data_fifo4,
    input logic sink_valid_fifo5,
    output logic sink_ready_fifo5,
    input logic sink_sop_fifo5,
    input logic sink_eop_fifo5,

    // streaming source fifo5
    output logic [31:0] source_data_fifo5,
    output logic source_valid_fifo5,
    input logic source_ready_fifo5,
    output logic source_sop_fifo5,
    output logic source_eop_fifo5,
    */
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
  // feeds into the ring buffer
  //Streaming registers to buffer video signal
  STREAM_REG #(.DATA_WIDTH(26)) in_reg (
    .clk(clk),
    .rst_n(reset_n),
    .ready_out(sink_ready),
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

  // STAGE 1
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

  always_comb begin
    if ((hsv_d20[23:16] < 15 && hsv_d20[23:16] > 5) && hsv_d20[7:0] > 57) begin // red
      hsv_thresholded = {8'd255, 8'd0, 8'd0};
    end
    else if ((hsv_d20[23:16] < 50 && hsv_d20[23:16] > 35) && (hsv_d20[7:0] > 160 && hsv_d20[7:0] < 210) && (hsv_d20[15:8] > 130 && hsv_d20[15:8] < 200))// top half yellow 
    begin
      hsv_thresholded = {8'd255, 8'd255, 8'd0};
    end
    else if (hsv_d20[23:16] > 250 || hsv_d20[23:16] < 5) // pink
    begin
      hsv_thresholded = {8'd168, 8'd50, 8'd153};
    end
    else if ((hsv_d20[23:16] < 170 && hsv_d20[23:16] > 130)) //&& (hsv_d20[7:0] > 25 && hsv_d20[7:0] < 50)) // && hsv_d20[15:8] > 100) // Dark blue
    begin
      hsv_thresholded = {8'd0, 8'd0, 8'd255};
    end
    else if (hsv_d20[23:16] < 85 && hsv_d20[23:16] > 60/*&& hsv_d20[7:0] > 130) */&& hsv_d20[15:8] < 200 && hsv_d20[15:8] > 120) // light green
    begin
      hsv_thresholded = {8'd0, 8'd255, 8'd0};
    end
    else if (hsv_d20[23:16] < 130 && hsv_d20[23:16] > 113)//&& hsv_d20[7:0] > 120) // teal
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
    .data_in({sop, eop, in_valid,packet_video}),
    .data_out({sop_d52, eop_d52, in_valid_d52,packet_video_d52})
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

  always_ff @(posedge clk) begin 
    if(sop_d52 & in_valid_d52) begin
      /*on receiving new frame set left limit to far right
       and right limit to far left (horseshoe theory)
      */
      x_left_red <= IMAGE_W- 11'd1; 
      x_right_red <= 11'd0;
    end
    else if(modal_data_out == {8'd255,8'd0,8'd0}) begin
      if(x_d52 < x_left_red) x_left_red <= x_d52;
      if(x_d52 > x_right_red) x_right_red <= x_d52;
    end
  end 


  //need to keep a latched version of x_left_red and x_right_red upon FINISHING A FRAME
  logic [10:0] x_left_r_frame, x_right_r_frame; 
  always_ff @(posedge clk) begin 
    if(eop_d52 & in_valid_d52 & packet_video_d52) begin
      x_left_r_frame <= x_left_red;
      x_right_r_frame <= x_right_red; 
    end 
  end 

  logic [23:0] bounding_boxed_data;
  assign bounding_boxed_data = (x_d52 == x_left_r_frame | x_d52 == x_right_r_frame) ? {8'd256, 8'd0, 8'd0} : modal_data_out; 
//---------------------------end bounding box code---------------------
  // assign source_data = found_eop_or_sop ? centre_pixel : {out_pixel_r_s4[13:6], out_pixel_g_s4[13:6], out_pixel_b_s4[13:6]};
  assign source_data = found_eop_or_sop_d36 ? fallback_data_d36[25:2] : bounding_boxed_data;
  //assign source_data = found_eop_or_sop ? row_1_data[6][25:2] : gaus_blur_pixel;
  // assign source_sop = row_1_data[6][1];
  // assign source_eop = row_1_data[6][0];


  //assign source_data = centre_pixel_d20[25:2];
  assign source_sop = fallback_data_d36[1];
  assign source_eop = fallback_data_d36[0];

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