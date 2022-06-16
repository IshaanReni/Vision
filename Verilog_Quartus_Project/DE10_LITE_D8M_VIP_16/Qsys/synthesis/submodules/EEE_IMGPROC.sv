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

    /*
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


  //PERSO Addition
  //Solid Kernel relying on delay line
  //integer k_halfwidth = 4;
  //integer k_tot_size = (2 * k_halfwidth + 1) * (2 * k_halfwidth + 1);  //this is 9x9 kernel


  //NB : coordinates are [y][x] in JLS code
  // logic to read from buffer (from 3D coordinates):
  // we use x,y coordinate already calculated (end of buffer and bottom right of kernel)
  //attempt to rewrite:
  /*
generate
genvar i;
for (i=0; i< IMAGE_W; i = i + 1) begin
	genvar j;
	for (always< IMAGE_H; j = j + 1) begin
		if( (x>(2*k_halfwidth+1)) && (y>(2*k_halfwidth+1)) ) begin //check we are not out of bounds

			for (integer m=0; m<(2*k_halfwidth+1)) begin 
				for(integer n=0<(2*k_halfwidth+1)) begin
					p+= hsv_delayline[j+i*(2*k_halfwidth+1)];
				end
			end

			p /= k_tot_size - 10; 
			
			
			hsv_delayline[k_halfwidth] = p; //middle of the kernel
		end
	end
end
endgenerate
*/

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
    .data_out({source_data_exposed_step1,source_sop_exposed_step1,source_eop_exposed_step1})
  );
  
  // SHIFT_REGGAE #(.DATA_WIDTH(26), .NO_STAGES(624)) shift_reg_1 (
  //   .clk(clk),
  //   .rst_n(reset_n),
  //   .valid_in(source_valid),
  //   .data_in({source_data_exposed_step1, source_sop_exposed_step1, source_eop_exposed_step1}),
  //   .data_out({, , })
  // );

  // // STAGE 2
  // SHIFT_EXPOSED #(.DATA_WIDTH(26), .NO_STAGES(16)) shift_exposed_2 (
  //   .clk(clk),
  //   .rst_n(reset_n),
  //   .valid_in(source_valid),
  //   .data_in({sink_data_fifo1, sink_sop_fifo1, sink_eop_fifo1}),
  //   .internal_out(row_2_data),
  //   .data_out({source_data_exposed_step2, source_sop_exposed_step2, source_eop_exposed_step2})
  // );
  
  logic found_eop_or_sop;

  always_comb begin
    found_eop_or_sop = 0;

    for(integer i = 0; i < 16; i = i + 1) begin
      if(/*row_5_data[i][0] | row_5_data[i][1] | 
        row_4_data[i][0] | row_4_data[i][1] | 
        row_3_data[i][0] | row_3_data[i][1] |
        row_2_data[i][0] | row_2_data[i][1] | */
        row_1_data[i][0] | row_1_data[i][1])
        begin 
        found_eop_or_sop = 1;
      end
    end
  end
  
  logic [25:0] centre_pixel_d20;
  logic found_eop_or_sop_d20;

  SHIFT_REGGAE #(.DATA_WIDTH(27), .NO_STAGES(20)) shift_reg_centre_pixel (
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(source_valid),
    .data_in({found_eop_or_sop, row_1_data[7]}),
    .data_out({found_eop_or_sop_d20, centre_pixel_d20})
  );

  logic [23:0] hsv_d20;
  RGB_TO_HSV hsv_converter (
    .clk(clk),
    .rst_n(reset_n),
    .valid_in(source_valid),
    .rgb_in(row_1_data[7][25:2]),
    .hsv_out(hsv_d20)
  );

  logic [23:0] hsv_thresholded;

  always_comb begin
    if ((hsv_d20[23:16] < 15 || hsv_d20[23:16] > 250) && hsv_d20[7:0] > 57) begin // red
      hsv_thresholded = {8'd255, 8'd0, 8'd0};
    end
    else if ((hsv_d20[23:16] < 50 && hsv_d20[23:16] > 35) && (hsv_d20[7:0] > 160 && hsv_d20[7:0] < 210) && (hsv_d20[15:8] > 130 && hsv_d20[15:8] < 200))// top half yellow 
    begin
      hsv_thresholded = {8'd255, 8'd255, 8'd0};
    end
    else if (hsv_d20[23:16] < 230 && hsv_d20[23:16] > 220) // pink
    begin
      hsv_thresholded = {8'd168, 8'd50, 8'd153};
    end
    else if ((hsv_d20[23:16] < 155 && hsv_d20[23:16] > 113) && (hsv_d20[7:0] > 25 && hsv_d20[7:0] < 50)) // && hsv_d20[15:8] > 100) // Dark blue
    begin
      hsv_thresholded = {8'd0, 8'd0, 8'd255};
    end
    else if (hsv_d20[23:16] < 80 && hsv_d20[23:16] > 70 && hsv_d20[7:0] > 130 && hsv_d20[15:8] < 200 && hsv_d20[15:8] > 120) // light green
    begin
      hsv_thresholded = {8'd0, 8'd255, 8'd0};
    end
    else if (hsv_d20[23:16] < 85 && hsv_d20[23:16] > 80 && hsv_d20[7:0] > 120) // teal
    begin
      hsv_thresholded = {8'd0, 8'd255, 8'd128};
    end
    else
    begin
      hsv_thresholded = {8'd0, 8'd0, 8'd0};
    end
  end


  //______________________________Modal Kernel Below_____________________

  //NEED to Add Buffering for line of pixels

  

 //__________________________________end Modal Kernel ___________________________
  // assign source_data = found_eop_or_sop ? centre_pixel : {out_pixel_r_s4[13:6], out_pixel_g_s4[13:6], out_pixel_b_s4[13:6]};
  assign source_data = found_eop_or_sop_d20 ? centre_pixel_d20[25:2] : hsv_thresholded;
  
  //assign source_data = centre_pixel_d20[25:2];
  assign source_sop = centre_pixel_d20[1];
  assign source_eop = centre_pixel_d20[0];

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