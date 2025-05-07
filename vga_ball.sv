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

    // Direction encoding
    localparam DIR_UP = 3'd0, DIR_RIGHT = 3'd1, DIR_DOWN = 3'd2, DIR_LEFT = 3'd3, DIR_EAT = 3'd4;

    // Pac-Man position and direction
    reg [9:0] pacman_x;
    reg [9:0] pacman_y;
    reg [2:0] pacman_dir;
    reg [12:0] trigger_tile_index;


    // Ghosts: 4 ghosts
    reg [9:0] ghost_x[0:3];
    reg [9:0] ghost_y[0:3];
    reg [1:0] ghost_dir[0:3];

    // 1Hz auto-rotate
    reg [25:0] second_counter;
	wire [6:0] pac_tile_x;
	wire [6:0] pac_tile_y;
	wire [12:0] pacman_tile_index;
    reg [11:0] tile[0:4799];
    reg [7:0] tile_bitmaps[0:8191];
    reg [7:0] char_bitmaps[0:575];
    reg [7:0] score;

    integer i;
    integer base_tile;
    integer d0, d1, d2, d3;
    integer base_score_tile;
    reg [31:0] pacman_up[0:15], pacman_right[0:15], pacman_down[0:15], pacman_left[0:15], pacman_eat[0:15]; 
   wire [6:0] tile_x = hcount[10:4];
    wire [6:0] tile_y = vcount[9:3];
    wire [2:0] tx = hcount[3:1];
    wire [2:0] ty = vcount[2:0];

    wire [12:0] tile_index = tile_y * 80 + tile_x;
    wire [11:0] tile_id = tile[tile_index];
    wire [7:0] bitmap_row = tile_bitmaps[tile_id * 8 + ty];
    wire pixel_on = bitmap_row[7 - tx];

    // Pac-Man render
    wire [3:0] pacman_x16 = hcount[10:1] - pacman_x;
    wire [3:0] pacman_y16 = vcount - pacman_y;
    wire on_pacman = (hcount[10:1] >= pacman_x && hcount[10:1] < pacman_x + 16 &&
                      vcount >= pacman_y && vcount < pacman_y + 16);

    reg [31:0] pacman_row;
        integer gi;
    integer gx;
    integer gy;
    reg [1:0] ghost_pixel;
    reg [1:0] pacman_pixel;
always @(posedge clk or posedge reset) begin
    if (reset) begin
        second_counter <= 0;
        pacman_x <= 340;
        pacman_y <= 240;
        pacman_dir <= DIR_RIGHT;
	score <= 0;
        ghost_x[0] <= 100; ghost_y[0] <= 100; ghost_dir[0] <= DIR_LEFT;
        ghost_x[1] <= 200; ghost_y[1] <= 100; ghost_dir[1] <= DIR_RIGHT;
        ghost_x[2] <= 300; ghost_y[2] <= 100; ghost_dir[2] <= DIR_UP;
        ghost_x[3] <= 400; ghost_y[3] <= 100; ghost_dir[3] <= DIR_DOWN;

    end else begin
        second_counter <= second_counter + 1;

        // Handle software writes
        if (chipselect && write) begin
            case (address)
                5'd0: begin
                    pacman_x <= writedata[7:0];
                    pacman_y <= writedata[15:8];
                end
                5'd3: pacman_dir <= writedata[2:0];
		5'd4: trigger_tile_index <= writedata[12:0];  

            endcase
        end

        // Auto-rotate only if no override
        else if (second_counter == 50_000_000) begin
            second_counter <= 0;

            pacman_dir <= (pacman_dir == DIR_EAT) ? DIR_UP : pacman_dir + 1;

            ghost_dir[0] <= ghost_dir[0] + 1;
            ghost_dir[1] <= ghost_dir[1] + 1;
            ghost_dir[2] <= ghost_dir[2] + 1;
            ghost_dir[3] <= ghost_dir[3] + 1;
        end
		pac_tile_x = pacman_x[9:3];
		pac_tile_y = pacman_y[9:3];
		pacman_tile_index = pac_tile_y * 80 + pac_tile_x;
		
		if (pacman_tile_index == trigger_tile_index) begin
		    tile[trigger_tile_index] <= 12'h03;
		end

    end
end


    // Tile and character memory
    
    initial begin
        $readmemh("map.vh", tile);
        $readmemh("tiles.vh", tile_bitmaps);
        $readmemh("characters.vh", char_bitmaps);

        // SCORE at tile[980]
        base_tile = 980;
        tile[base_tile + 0]  = 12'd1000;
        tile[base_tile + 1]  = 12'd1002;
        tile[base_tile + 2]  = 12'd1004;
        tile[base_tile + 3]  = 12'd1006;
        tile[base_tile + 4]  = 12'd1008;

        tile[base_tile + 80] = 12'd1001;
        tile[base_tile + 81] = 12'd1003;
        tile[base_tile + 82] = 12'd1005;
        tile[base_tile + 83] = 12'd1007;
        tile[base_tile + 84] = 12'd1009;

        for (i = 0; i < 8; i++) begin
            tile_bitmaps[1000 * 8 + i] = char_bitmaps[18 * 16 + i];
            tile_bitmaps[1001 * 8 + i] = char_bitmaps[18 * 16 + i + 8];
            tile_bitmaps[1002 * 8 + i] = char_bitmaps[2  * 16 + i];
            tile_bitmaps[1003 * 8 + i] = char_bitmaps[2  * 16 + i + 8];
            tile_bitmaps[1004 * 8 + i] = char_bitmaps[14 * 16 + i];
            tile_bitmaps[1005 * 8 + i] = char_bitmaps[14 * 16 + i + 8];
            tile_bitmaps[1006 * 8 + i] = char_bitmaps[17 * 16 + i];
            tile_bitmaps[1007 * 8 + i] = char_bitmaps[17 * 16 + i + 8];
            tile_bitmaps[1008 * 8 + i] = char_bitmaps[4  * 16 + i];
            tile_bitmaps[1009 * 8 + i] = char_bitmaps[4  * 16 + i + 8];
        end
	    d3 = score / 1000;
	    d2 = (score % 1000) / 100;
	    d1 = (score % 100) / 10;
	    d0 = score % 10;
		
	    base_score_tile = 1000;
		
	    tile[base_score_tile + 0]  = 12'd1010;
	    tile[base_score_tile + 1]  = 12'd1011;
   	    tile[base_score_tile + 2]  = 12'd1012;
	    tile[base_score_tile + 3]  = 12'd1013;
	    tile[base_score_tile + 80] = 12'd1014;
	    tile[base_score_tile + 81] = 12'd1015;
	    tile[base_score_tile + 82] = 12'd1016;
	    tile[base_score_tile + 83] = 12'd1017;

    end

    // Pac-Man sprites
    
    initial begin
        $readmemh("pacman_up.vh",    pacman_up);
        $readmemh("pacman_right.vh", pacman_right);
        $readmemh("pacman_down.vh",  pacman_down);
        $readmemh("pacman_left.vh",  pacman_left);
	$readmemh("pacman_eat.vh",  pacman_eat);
    end

    // Ghost shared sprite
	localparam logic [1:0] GHOST_LEFT [0:15][0:15] = '{
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd3,2'd3,2'd2,2'd2,2'd1,2'd3,2'd3,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd3,2'd3,2'd2,2'd2,2'd1,2'd3,2'd3,2'd2,2'd2,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0,2'd0,2'd1,2'd1,2'd1,2'd0,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd0,2'd1,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0}
};

	localparam logic [1:0] GHOST_RIGHT [0:15][0:15] = '{
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd1,2'd2,2'd2,2'd3,2'd3,2'd1,2'd2,2'd2,2'd3,2'd3,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd2,2'd2,2'd3,2'd3,2'd1,2'd2,2'd2,2'd3,2'd3,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0,2'd0,2'd1,2'd1,2'd1,2'd0,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd0,2'd1,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0}
};
	localparam logic [1:0] GHOST_UP [0:15][0:15] = '{
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd1,2'd3,2'd3,2'd1,2'd1,2'd1,2'd3,2'd3,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd3,2'd3,2'd2,2'd1,2'd2,2'd3,2'd3,2'd2,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0,2'd0,2'd1,2'd1,2'd1,2'd0,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd0,2'd1,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0}
};

	localparam logic [1:0] GHOST_DOWN [0:15][0:15] = '{
     '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd0,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0},
    '{2'd0,2'd1,2'd1,2'd2,2'd3,2'd3,2'd2,2'd1,2'd2,2'd3,2'd3,2'd2,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd3,2'd3,2'd1,2'd1,2'd1,2'd3,2'd3,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0,2'd0,2'd1,2'd1,2'd1,2'd0,2'd1,2'd1,2'd0},
    '{2'd0,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd0,2'd1,2'd0},
    '{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0}
};



    // VGA tile render
   
    // VGA pixel output with ghost overlay
always @(*) begin
    // Default: black screen
    VGA_R = 0;
    VGA_G = 0;
    VGA_B = 0;

    // -------------------------
    // 1. Background tile color
    // -------------------------
    if (pixel_on) begin
        if (tile_id == 12'h0A || (tile_index >= 980 && tile_index <= 980 + 84))
            {VGA_R, VGA_G, VGA_B} = 24'hFFFFFF;  // white
        else
        	VGA_B = 8'hFF;  // blue background
    end

    // -------------------------
    // 2. Pac-Man pixel row decode (MUST BE OUTSIDE case expression)
    // -------------------------
    pacman_row = 32'b0;
    if (vcount >= pacman_y && vcount < pacman_y + 16) begin
        case (pacman_dir)
            DIR_UP:    pacman_row = pacman_up[vcount - pacman_y];
            DIR_RIGHT: pacman_row = pacman_right[vcount - pacman_y];
            DIR_DOWN:  pacman_row = pacman_down[vcount - pacman_y];
            DIR_LEFT:  pacman_row = pacman_left[vcount - pacman_y];
            DIR_EAT:   pacman_row = pacman_eat[vcount - pacman_y];
        endcase
    end

    // -------------------------
    // 3. Pac-Man overlay
    // -------------------------
    if (hcount[10:1] >= pacman_x && hcount[10:1] < pacman_x + 16 &&
        vcount >= pacman_y && vcount < pacman_y + 16) begin
        if (pacman_row[15 - (hcount[10:1] - pacman_x)]) begin
            VGA_R = 8'hFF;
            VGA_G = 8'hFF;
            VGA_B = 8'h00; // Yellow Pac-Man
        end
    end

    // -------------------------
    // 4. Ghost overlay
    // -------------------------
    for (gi = 0; gi < 4; gi = gi + 1) begin
        if (hcount[10:1] >= ghost_x[gi] && hcount[10:1] < ghost_x[gi] + 16 &&
            vcount >= ghost_y[gi] && vcount < ghost_y[gi] + 16) begin

            gx = hcount[10:1] - ghost_x[gi];
            gy = vcount - ghost_y[gi];

            case (ghost_dir[gi])
                DIR_UP:    ghost_pixel = GHOST_UP[gy][gx];
                DIR_DOWN:  ghost_pixel = GHOST_DOWN[gy][gx];
                DIR_LEFT:  ghost_pixel = GHOST_LEFT[gy][gx];
                DIR_RIGHT: ghost_pixel = GHOST_RIGHT[gy][gx];
                default:   ghost_pixel = 2'b00;
            endcase

            case (ghost_pixel)
                2'b01: begin
                    case (gi)
                        0: begin VGA_R = 8'hFF; VGA_G = 0;     VGA_B = 0;     end // Red
                        1: begin VGA_R = 8'hFF; VGA_G = 8'hAA; VGA_B = 8'hFF; end // Pink
                        2: begin VGA_R = 8'hFF; VGA_G = 8'hAA; VGA_B = 0;     end // Orange
                        3: begin VGA_R = 0;     VGA_G = 8'hFF; VGA_B = 8'hFF; end // Light Blue
                    endcase
                end
                2'b10: begin VGA_R = 8'hFF; VGA_G = 8'hFF; VGA_B = 8'hFF; end // White
                2'b11: begin VGA_R = 0;     VGA_G = 0;     VGA_B = 8'h88; end // Dark Blue
            endcase
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
