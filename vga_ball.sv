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
    input [4:0] address,

    output reg [7:0] VGA_R, VGA_G, VGA_B,
    output VGA_CLK, VGA_HS, VGA_VS,
    output VGA_BLANK_n, VGA_SYNC_n
);

    // VGA sync counters
    wire [10:0] hcount;
    wire [9:0]  vcount;

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

    // Pac-Man position and direction
    reg [9:0] pacman_x;
    reg [9:0] pacman_y;
    reg [1:0] pacman_dir;

    // Ghost position
    wire [9:0] ghost_x = 300;
    wire [9:0] ghost_y = 240;

    // Direction encoding
    localparam DIR_UP = 2'd0, DIR_RIGHT = 2'd1, DIR_DOWN = 2'd2, DIR_LEFT = 2'd3;

    // Tile coordinates
    wire [6:0] tile_x = hcount[10:4];  // 640 / 16 = 40
    wire [6:0] tile_y = vcount[9:3];   // 480 / 8 = 60
    wire [2:0] tx = hcount[3:1];
    wire [2:0] ty = vcount[2:0];

    // Write position and direction from software
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pacman_x <= 340;
            pacman_y <= 240;
            pacman_dir <= DIR_RIGHT;
        end else if (chipselect && write) begin
            case (address)
		5'd0: begin
		    pacman_x <= writedata[7:0];
		    pacman_y <= writedata[15:8];
		end
                5'd3: pacman_dir <= writedata[1:0];
            endcase
        end
    end

    // Tile map: 80x60 = 4800 tiles
    reg [11:0] tile[0:4799];
    initial begin
        $readmemh("map.vh", tile);
    end

    // Tile bitmaps
    reg [7:0] tile_bitmaps[0:36*8-1];
	reg [7:0] bitmap_memory[0:4799*8-1]; // 80x60 tiles, 8 rows per tile = 38400 entries

    initial begin
        $readmemh("tiles.vh", tile_bitmaps);
    end

  integer i;
integer base_tile;
reg [7:0] char_bitmaps[0:575];  // 36 chars × 16 rows

initial begin
    $readmemh("characters.vh", char_bitmaps);

    base_tile = 15 * 80 + 26;  // (row 15, col 26)

    for (i = 0; i < 8; i++) begin
        bitmap_memory[(base_tile + 0) * 8 + i] = char_bitmaps[18*16 + i]; // S
        bitmap_memory[(base_tile + 1) * 8 + i] = char_bitmaps[2*16  + i]; // C
        bitmap_memory[(base_tile + 2) * 8 + i] = char_bitmaps[14*16 + i]; // O
        bitmap_memory[(base_tile + 3) * 8 + i] = char_bitmaps[17*16 + i]; // R
        bitmap_memory[(base_tile + 4) * 8 + i] = char_bitmaps[4*16  + i]; // E
    end
end


    // Ghost sprite (16x16)
    reg [15:0] ghost_bitmap[0:15];
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
    end

    // Pac-Man sprites
    reg [15:0] pacman_up[0:15], pacman_right[0:15], pacman_down[0:15], pacman_left[0:15];
    initial begin
        $readmemh("pacman_up.vh",    pacman_up);
        $readmemh("pacman_right.vh", pacman_right);
        $readmemh("pacman_down.vh",  pacman_down);
        $readmemh("pacman_left.vh",  pacman_left);
    end

    // VGA tile rendering
    wire [12:0] tile_index = tile_y * 80 + tile_x;
    wire [11:0] tile_id = tile[tile_index];
    wire [7:0] bitmap_row = tile_bitmaps[tile_id * 8 + ty];
    wire pixel_on = bitmap_row[7 - tx];

    always @(*) begin
        VGA_R = 0; VGA_G = 0; VGA_B = 0;

        if (pixel_on)
            VGA_B = 8'hFF;

        // Ghost rendering
        if (hcount[10:1] >= ghost_x && hcount[10:1] < ghost_x + 16 &&
            vcount >= ghost_y && vcount < ghost_y + 16) begin
            if (ghost_bitmap[vcount - ghost_y][15 - (hcount[10:1] - ghost_x)]) begin
                VGA_R = 8'hFF; VGA_B = 8'hFF;
            end
        end

        // Pac-Man rendering
        if (hcount[10:1] >= pacman_x && hcount[10:1] < pacman_x + 16 &&
            vcount >= pacman_y && vcount < pacman_y + 16) begin
            case (pacman_dir)
                DIR_UP:    if (pacman_up[vcount - pacman_y][15 - (hcount[10:1] - pacman_x)]) begin VGA_R = 8'hFF; VGA_G = 8'hFF; end
                DIR_RIGHT: if (pacman_right[vcount - pacman_y][15 - (hcount[10:1] - pacman_x)]) begin VGA_R = 8'hFF; VGA_G = 8'hFF; end
                DIR_DOWN:  if (pacman_down[vcount - pacman_y][15 - (hcount[10:1] - pacman_x)]) begin VGA_R = 8'hFF; VGA_G = 8'hFF; end
                DIR_LEFT:  if (pacman_left[vcount - pacman_y][15 - (hcount[10:1] - pacman_x)]) begin VGA_R = 8'hFF; VGA_G = 8'hFF; end
            endcase
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
