/*
 * Avalon memory-mapped peripheral that generates VGA
 *
 * Stephen A. Edwards
 * Columbia University
 */
module vga_ball (
    input clk,
    input reset,
    input [15:0] writedata,
    input write,
    input chipselect,
    input [2:0] address,

    output reg [7:0] VGA_R, VGA_G, VGA_B,
    output VGA_CLK, VGA_HS, VGA_VS,
    output VGA_BLANK_n, VGA_SYNC_n
);

    // VGA sync counters
    wire [10:0] hcount;
    wire [9:0]  vcount;

    // VGA sync generator instance
    vga_counters counters_inst (
        .clk50(clk),
        .hcount(hcount),
        .vcount(vcount),
        .VGA_CLK(VGA_CLK),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_BLANK_n(VGA_BLANK_n),
        .VGA_SYNC_n(VGA_SYNC_n)
    );

    // Register for Pac-Man's position
    reg [9:0] pacman_x;
    reg [9:0] pacman_y;

    // Ghost position (fixed)
    wire [9:0] ghost_x = 300;
    wire [9:0] ghost_y = 240;

    // Tile addressing
    wire [6:0] tile_x = hcount[10:4];
    wire [6:0] tile_y = vcount[9:3];
    wire [2:0] tx = hcount[3:1];
    wire [2:0] ty = vcount[2:0];

    // Write logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pacman_x <= 340;
            pacman_y <= 240;
        end else if (chipselect && write) begin
            case (address)
                3'd0: pacman_x <= writedata[9:0];
                3'd1: pacman_y <= writedata[9:0];
            endcase
        end
    end

    // Tile bitmaps
    reg [7:0] straight_tile[0:7];
    reg [7:0] corner_tile[0:7];
    initial begin
        straight_tile[0] = 8'b00011000;
        straight_tile[1] = 8'b00011000;
        straight_tile[2] = 8'b00011000;
        straight_tile[3] = 8'b00011000;
        straight_tile[4] = 8'b00011000;
        straight_tile[5] = 8'b00011000;
        straight_tile[6] = 8'b00011000;
        straight_tile[7] = 8'b00011000;

        corner_tile[0] = 8'b00000000;
        corner_tile[1] = 8'b00000000;
        corner_tile[2] = 8'b00000000;
        corner_tile[3] = 8'b00001111;
        corner_tile[4] = 8'b00011111;
        corner_tile[5] = 8'b00011100;
        corner_tile[6] = 8'b00011000;
        corner_tile[7] = 8'b00011000;
    end

    // Bitmaps
    reg [15:0] ghost_bitmap[0:15];
    reg [15:0] pacman_bitmap[0:15];
    initial begin
        ghost_bitmap[ 0] = 16'b0000000000000000;
        ghost_bitmap[ 1] = 16'b0000001111000000;
        ghost_bitmap[ 2] = 16'b0001111111110000;
        ghost_bitmap[ 3] = 16'b0111111111111100;
        ghost_bitmap[ 4] = 16'b0111111111111100;
        ghost_bitmap[ 5] = 16'b0111001111001110;
        ghost_bitmap[ 6] = 16'b0110000110000110;
        ghost_bitmap[ 7] = 16'b0110000110000110;
        ghost_bitmap[ 8] = 16'b0110000110000110;
        ghost_bitmap[ 9] = 16'b0111001111001110;
        ghost_bitmap[10] = 16'b0111111111111110;
        ghost_bitmap[11] = 16'b0111111111111110;
        ghost_bitmap[12] = 16'b0111111111111110;
        ghost_bitmap[13] = 16'b0110011100110010;
        ghost_bitmap[14] = 16'b1000001100110001;
        ghost_bitmap[15] = 16'b0000000000000000;

        pacman_bitmap[ 0] = 16'b0000000000000000;
        pacman_bitmap[ 1] = 16'b0000011111000000;
        pacman_bitmap[ 2] = 16'b0001111111110000;
        pacman_bitmap[ 3] = 16'b0011111111111000;
        pacman_bitmap[ 4] = 16'b0011111111111000;
        pacman_bitmap[ 5] = 16'b0000111111111100;
        pacman_bitmap[ 6] = 16'b0000000111111100;
        pacman_bitmap[ 7] = 16'b0000000000111100;
        pacman_bitmap[ 8] = 16'b0000000111111100;
        pacman_bitmap[ 9] = 16'b0001111111111100;
        pacman_bitmap[10] = 16'b0011111111111000;
        pacman_bitmap[11] = 16'b0011111111111000;
        pacman_bitmap[12] = 16'b0001111111110000;
        pacman_bitmap[13] = 16'b0000011111000000;
        pacman_bitmap[14] = 16'b0000000000000000;
        pacman_bitmap[15] = 16'b0000000000000000;
    end

    // VGA Output
    always @(*) begin
        VGA_R = 8'd0;
        VGA_G = 8'd0;
        VGA_B = 8'd0;

        // Walls (same as before)
        if ((tile_x == 12 || tile_x == 67) && (tile_y >= 12 && tile_y <= 46)) begin
            if (straight_tile[ty][7 - tx]) VGA_B = 8'hFF;
        end else if ((tile_y == 12 || tile_y == 46) && (tile_x >= 12 && tile_x <= 67)) begin
            if (straight_tile[tx][7 - ty]) VGA_B = 8'hFF;
        end else begin
            if (tile_x == 11 && tile_y == 11 && corner_tile[ty][7 - tx]) VGA_B = 8'hFF;
            else if (tile_x == 68 && tile_y == 11 && corner_tile[7-tx][7-ty]) VGA_B = 8'hFF;
            else if (tile_x == 68 && tile_y == 47 && corner_tile[7 - ty][tx]) VGA_B = 8'hFF;
            else if (tile_x == 11 && tile_y == 47 && corner_tile[tx][ty]) VGA_B = 8'hFF;
        end

        // Extra tile example
        if ((tile_x == 25 || tile_x == 54) && (tile_y >= 14 && tile_y <= 17)) begin
            if (straight_tile[ty][7 - tx]) VGA_B = 8'hFF;
        end else if ((tile_y == 14 || tile_y == 17) && (tile_x >= 25 && tile_x <= 54)) begin
            if (straight_tile[tx][7 - ty]) VGA_B = 8'hFF;
        end else begin
            if (tile_x == 25 && tile_y == 14 && corner_tile[ty][7 - tx]) VGA_B = 8'hFF;
            else if (tile_x == 54 && tile_y == 14 && corner_tile[7-tx][7-ty]) VGA_B = 8'hFF;
            else if (tile_x == 54 && tile_y == 17 && corner_tile[7 - ty][tx]) VGA_B = 8'hFF;
            else if (tile_x == 25 && tile_y == 17 && corner_tile[tx][ty]) VGA_B = 8'hFF;
        end

        // Ghost drawing
        if (hcount[10:1] >= ghost_x && hcount[10:1] < ghost_x + 16 &&
            vcount >= ghost_y && vcount < ghost_y + 16) begin
            if (ghost_bitmap[vcount - ghost_y][15 - (hcount[10:1] - ghost_x)]) begin
                VGA_R = 8'hFF;
                VGA_B = 8'hFF;
            end
        end

        // Pac-Man drawing
        if (hcount[10:1] >= pacman_x && hcount[10:1] < pacman_x + 16 &&
            vcount >= pacman_y && vcount < pacman_y + 16) begin
            if (pacman_bitmap[vcount - pacman_y][15 - (hcount[10:1] - pacman_x)]) begin
                VGA_R = 8'hFF;
                VGA_G = 8'hFF;
            end
        end
    end

endmodule



module vga_counters(
 input logic 	     clk50, reset,
 output logic [10:0] hcount,  // hcount[10:1] is pixel column
 output logic [9:0]  vcount,  // vcount[9:0] is pixel row
 output logic 	     VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_n, VGA_SYNC_n);

/*
 * 640 X 480 VGA timing for a 50 MHz clock: one pixel every other cycle
 * 
 * HCOUNT 1599 0             1279       1599 0
 *             _______________              ________
 * ___________|    Video      |____________|  Video
 * 
 * 
 * |SYNC| BP |<-- HACTIVE -->|FP|SYNC| BP |<-- HACTIVE
 *       _______________________      _____________
 * |____|       VGA_HS          |____|
 */
   // Parameters for hcount
   parameter HACTIVE      = 11'd 1280,
             HFRONT_PORCH = 11'd 32,
             HSYNC        = 11'd 192,
             HBACK_PORCH  = 11'd 96,   
             HTOTAL       = HACTIVE + HFRONT_PORCH + HSYNC +
                            HBACK_PORCH; // 1600
   
   // Parameters for vcount
   parameter VACTIVE      = 10'd 480,
             VFRONT_PORCH = 10'd 10,
             VSYNC        = 10'd 2,
             VBACK_PORCH  = 10'd 33,
             VTOTAL       = VACTIVE + VFRONT_PORCH + VSYNC +
                            VBACK_PORCH; // 525

   logic endOfLine;
   
   always_ff @(posedge clk50 or posedge reset)
     if (reset)          hcount <= 0;
     else if (endOfLine) hcount <= 0;
     else  	         hcount <= hcount + 11'd 1;

   assign endOfLine = hcount == HTOTAL - 1;
       
   logic endOfField;
   
   always_ff @(posedge clk50 or posedge reset)
     if (reset)          vcount <= 0;
     else if (endOfLine)
       if (endOfField)   vcount <= 0;
       else              vcount <= vcount + 10'd 1;

   assign endOfField = vcount == VTOTAL - 1;

   // Horizontal sync: from 0x520 to 0x5DF (0x57F)
   // 101 0010 0000 to 101 1101 1111 (active LOW during 1312-1503) (192 cycles)
   assign VGA_HS = !( (hcount[10:8] == 3'b101) & !(hcount[7:5] == 3'b111));
   assign VGA_VS = !( vcount[9:1] == (VACTIVE + VFRONT_PORCH) / 2);

   assign VGA_SYNC_n = 1'b0; // For putting sync on the green signal; unused
   
   // Horizontal active: 0 to 1279     Vertical active: 0 to 479
   // 101 0000 0000  1280	       01 1110 0000  480
   // 110 0011 1111  1599	       10 0000 1100  524
   assign VGA_BLANK_n = !( hcount[10] & (hcount[9] | hcount[8]) ) &
			!( vcount[9] | (vcount[8:5] == 4'b1111) );

   /* VGA_CLK is 25 MHz
    *             __    __    __
    * clk50    __|  |__|  |__|
    *        
    *             _____       __
    * hcount[0]__|     |_____|
    */
   assign VGA_CLK = hcount[0]; // 25 MHz clock: rising edge sensitive
   
endmodule
