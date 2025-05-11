module vga_ball (
    input clk,
    input reset,
    input [15:0] writedata,
    input write,
    input chipselect,
    input [4:0] address,

    output reg [7:0] VGA_R, VGA_G, VGA_B,
    output VGA_CLK, VGA_HS, VGA_VS,
    output VGA_BLANK_n, VGA_SYNC_n,
    input  logic        L_READY,
    input  logic        R_READY,
    output logic [7:0] L_DATA,
    output logic [7:0] R_DATA,
    output logic        L_VALID,
    output logic        R_VALID

);

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

    localparam DIR_UP = 3'd0, DIR_RIGHT = 3'd1, DIR_DOWN = 3'd2, DIR_LEFT = 3'd3, DIR_EAT = 3'd4;
localparam SCREEN_X_OFFSET = 26 * 8;  // 8 pixels per tile
localparam SCREEN_Y_OFFSET = 15 * 8;

    reg [9:0] pacman_x;
    reg [9:0] pacman_y;
    reg [2:0] pacman_dir;
    reg [12:0] trigger_tile_index;

    reg [9:0] ghost_x[0:3];
    reg [9:0] ghost_y[0:3];
    reg [1:0] ghost_dir[0:3];

    reg [25:0] second_counter;
    reg gameover_latched;
    reg [25:0] gameover_wait;

    wire [6:0] pac_tile_x = pacman_x[9:3];
    wire [6:0] pac_tile_y = pacman_y[9:3];
    wire [12:0] pacman_tile_index = pac_tile_y * 80 + pac_tile_x;//

    reg [11:0] tile[0:4799];
    reg [7:0] tile_bitmaps[0:879];

    reg [16:0] score;
    reg [31:0] pacman_up[0:15], pacman_right[0:15], pacman_down[0:15], pacman_left[0:15], pacman_eat[0:15];

    wire [6:0] tile_x = hcount[10:4];
    wire [6:0] tile_y = vcount[9:3];
    wire [2:0] tx = hcount[3:1];
    wire [2:0] ty = vcount[2:0];

    wire [12:0] tile_index = tile_y * 80 + tile_x;
    wire [11:0] tile_id = tile[tile_index];
    wire [7:0] bitmap_row = tile_bitmaps[tile_id * 8 + ty];
    wire pixel_on = bitmap_row[7 - tx];

    wire on_pacman = (hcount[10:1] >= pacman_x && hcount[10:1] < pacman_x + 16 &&
                      vcount >= pacman_y && vcount < pacman_y + 16);

    reg [31:0] pacman_row;
    integer i, gi, gx, gy;
    integer d0, d1, d2, d3;
    integer base_tile;
    integer base_score_tile;
    reg [1:0] ghost_pixel;

    initial begin
        $readmemh("map.vh", tile);
        $readmemh("tiles.vh", tile_bitmaps);
        base_tile = 752;
    end

reg [15:0] audio_data[0:17554];
reg [18:0] sample_index;
reg [15:0] sample_clock;
reg [15:0] current_sample;

initial $readmemh("audio.vh", audio_data);


    always @(posedge clk or posedge reset) begin
    if (reset) begin
        second_counter <= 0;
        gameover_latched <= 0;
        gameover_wait <= 0;
        pacman_x <= 340;
        pacman_y <= 240;
        pacman_dir <= DIR_RIGHT;
        score <= 0;
        ghost_x[0] <= 100; ghost_y[0] <= 100; ghost_dir[0] <= DIR_LEFT;
        ghost_x[1] <= 200; ghost_y[1] <= 100; ghost_dir[1] <= DIR_RIGHT;
        ghost_x[2] <= 300; ghost_y[2] <= 100; ghost_dir[2] <= DIR_UP;
        ghost_x[3] <= 400; ghost_y[3] <= 100; ghost_dir[3] <= DIR_DOWN;
    end else begin
	// Audio Streaming - 48kHz @ 50MHz (every 1041 cycles)
	if (sample_clock == 1041) begin
	    sample_clock <= 0;
	    current_sample <= audio_data[sample_index];
	    sample_index <= (sample_index == 479999) ? 0 : sample_index + 1;
	end else begin
	    sample_clock <= sample_clock + 1;
	end
	
	// Send to Audio Core when ready
	if (L_READY) begin
	    L_DATA <= current_sample;
	    L_VALID <= 1;
	end else begin
	    L_VALID <= 0;
	end
	
	if (R_READY) begin
	    R_DATA <= current_sample;
	    R_VALID <= 1;
	end else begin
	    R_VALID <= 0;
	end

        if (!gameover_latched)
            second_counter <= second_counter + 1;
        if (chipselect && write) begin
            case (address[4:0])
                // === Sprite 0: Pac-Man ===
                6'h00: begin pacman_x <= writedata[7:0]; pacman_y <= writedata[15:8]; end
                // 6'h01: begin sprite_frame[0] <= writedata[7:0]; sprite_visible[0] <= writedata[15:8]; end
                6'h02: begin pacman_dir <= writedata[1:0]; end
                // 6'h03: begin sprite_rsv1[0] <= writedata[7:0]; sprite_rsv2[0] <= writedata[15:8]; end

                // === Sprite 1: Ghost 0 ===
                6'h04: begin ghost_x[0] <= writedata[7:0]; ghost_y[0] <= writedata[15:8]; end
                // 6'h05: begin sprite_frame[1] <= writedata[7:0]; sprite_visible[1] <= writedata[15:8]; end
                6'h06: begin ghost_dir[0] <= writedata[1:0];end
                // 6'h07: begin sprite_rsv1[1] <= writedata[7:0]; sprite_rsv2[1] <= writedata[15:8]; end

                // === Sprite 2: Ghost 1 ===
                6'h08: begin ghost_x[1] <= writedata[7:0]; ghost_y[1] <= writedata[15:8]; end
                // 6'h09: begin sprite_frame[2] <= writedata[7:0]; sprite_visible[2] <= writedata[15:8]; end
                6'h0A: begin ghost_dir[1] <= writedata[1:0];end
                // 6'h0B: begin sprite_rsv1[2] <= writedata[7:0]; sprite_rsv2[2] <= writedata[15:8]; end

                // === Sprite 3: Ghost 2 ===
                6'h0C: begin ghost_x[2] <= writedata[7:0]; ghost_y[2] <= writedata[15:8]; end
                // 6'h0D: begin sprite_frame[3] <= writedata[7:0]; sprite_visible[3] <= writedata[15:8]; end
                6'h0E: begin ghost_dir[2] <= writedata[1:0];end
                // 6'h0F: begin sprite_rsv1[3] <= writedata[7:0]; sprite_rsv2[3] <= writedata[15:8]; end

                // === Sprite 4: Ghost 3 ===
                6'h10: begin ghost_x[3] <= writedata[7:0]; ghost_y[3] <= writedata[15:8]; end
                // 6'h11: begin sprite_frame[4] <= writedata[7:0]; sprite_visible[4] <= writedata[15:8]; end
                6'h12: begin ghost_dir[3] <= writedata[1:0]; end
                // 6'h13: begin sprite_rsv1[4] <= writedata[7:0]; sprite_rsv2[4] <= writedata[15:8]; end

                // === Score Register (4-digit decimal packed) ===
                6'h14: score <= writedata;

                // === Control Register (only lower 8 bits used) ===
                6'h15: begin  

                    if (writedata == 16'h0000) begin
                        $readmemh("map.vh", tile);
                        score <= 0;
                        pacman_x <= 340;
                        pacman_y <= 240;
                        pacman_dir <= DIR_RIGHT;
                        ghost_dir[0] <= DIR_LEFT;
                        ghost_dir[1] <= DIR_RIGHT;
                        ghost_dir[2] <= DIR_UP;
                        ghost_dir[3] <= DIR_DOWN;
                        ghost_x[0] <= 100; ghost_y[0] <= 100;
                        ghost_x[1] <= 200; ghost_y[1] <= 100;
                        ghost_x[2] <= 300; ghost_y[2] <= 100;
                        ghost_x[3] <= 400; ghost_y[3] <= 100;
                    end
                    else if (writedata[4] == 1'b1) begin
                        gameover_latched <= 1;
                        second_counter <= 0;
                    end

                end

                // === Pellet eat register ===
                6'h16: trigger_tile_index <= writedata;
            endcase
        end
        // if (chipselect && write) begin
        //     case (address)
        //         5'd0: begin
        //             pacman_x <= writedata[7:0];
        //             pacman_y <= writedata[15:8];
        //         end
        //         5'd2: pacman_dir <= writedata[10:8];
        //         5'd4: trigger_tile_index <= writedata[12:0];
        //         5'd5: begin
        //             if (writedata == 16'h0001) begin
        //                 gameover_latched <= 1;
        //                 second_counter <= 0;
        //             end else if (writedata == 16'h0000) begin
        //                 $readmemh("map.vh", tile);
        //                 score <= 0;
        //                 game_timer <= 0;
        //                 demo_index <= 13'd4088;
        //                 pacman_x <= 340;
        //                 pacman_y <= 240;
        //                 pacman_dir <= DIR_RIGHT;
        //                 ghost_dir[0] <= DIR_LEFT;
        //                 ghost_dir[1] <= DIR_RIGHT;
        //                 ghost_dir[2] <= DIR_UP;
        //                 ghost_dir[3] <= DIR_DOWN;
        //                 ghost_x[0] <= 100; ghost_y[0] <= 100;
        //                 ghost_x[1] <= 200; ghost_y[1] <= 100;
        //                 ghost_x[2] <= 300; ghost_y[2] <= 100;
        //                 ghost_x[3] <= 400; ghost_y[3] <= 100;
        //                 gameover_latched <= 0;
        //                 gameover_wait <= 0;
        //             end
        //         end
        //         5'd6: begin ghost_x[0] <= writedata[7:0]; ghost_y[0] <= writedata[15:8]; end 
        //         5'd7: begin ghost_x[1] <= writedata[7:0]; ghost_y[1] <= writedata[15:8]; end
        //         5'd8: begin ghost_x[2] <= writedata[7:0]; ghost_y[2] <= writedata[15:8]; end
        //         5'd9: begin ghost_x[3] <= writedata[7:0]; ghost_y[3] <= writedata[15:8]; end
        //         5'd10: ghost_dir[0] <= writedata[1:0];
        //         5'd11: ghost_dir[1] <= writedata[1:0];
        //         5'd12: ghost_dir[2] <= writedata[1:0];
        //         5'd13: ghost_dir[3] <= writedata[1:0];
        //         5'd14: score <= writedata[7:0];
        //     endcase
        // end

        if (gameover_latched) begin
            // Display GAME OVER text
            tile[3712 + 0]  <= 38 + (6 * 2);   // G
            tile[3712 + 1]  <= 38 + (0 * 2);   // A
            tile[3712 + 2]  <= 38 + (12 * 2);  // M
            tile[3712 + 3]  <= 38 + (4 * 2);   // E
            tile[3712 + 4]  <= 12'h25;         // blank tile
            tile[3712 + 5]  <= 38 + (14 * 2);  // O
            tile[3712 + 6]  <= 38 + (21 * 2);  // V
            tile[3712 + 7]  <= 38 + (4 * 2);   // E
            tile[3712 + 8]  <= 38 + (17 * 2);  // R

            tile[3792 + 0]  <= 38 + (6 * 2) + 1;
            tile[3792 + 1]  <= 38 + (0 * 2) + 1;
            tile[3792 + 2]  <= 38 + (12 * 2) + 1;
            tile[3792 + 3]  <= 38 + (4 * 2) + 1;
            tile[3792 + 4]  <= 12'h25;
            tile[3792 + 5]  <= 38 + (14 * 2) + 1;
            tile[3792 + 6]  <= 38 + (21 * 2) + 1;
            tile[3792 + 7]  <= 38 + (4 * 2) + 1;
            tile[3792 + 8]  <= 38 + (17 * 2) + 1;

            gameover_wait <= gameover_wait + 1;
            if (gameover_wait == 50_000_000) begin
                $readmemh("map.vh", tile);
                score <= 0;
                pacman_x <= 340;
                pacman_y <= 240;
                pacman_dir <= DIR_RIGHT;
                ghost_dir[0] <= DIR_LEFT;
                ghost_dir[1] <= DIR_RIGHT;
                ghost_dir[2] <= DIR_UP;
                ghost_dir[3] <= DIR_DOWN;
                ghost_x[0] <= 100; ghost_y[0] <= 100;
                ghost_x[1] <= 200; ghost_y[1] <= 100;
                ghost_x[2] <= 300; ghost_y[2] <= 100;
                ghost_x[3] <= 400; ghost_y[3] <= 100;
                gameover_latched <= 0;
                gameover_wait <= 0;
            end
        end

        // Constant score display
        tile[base_tile + 0]  = 38 + (18 * 2);
        tile[base_tile + 1]  = 38 + (2 * 2);
        tile[base_tile + 2]  = 38 + (14 * 2);
        tile[base_tile + 3]  = 38 + (17 * 2);
        tile[base_tile + 4]  = 38 + (4 * 2);
        tile[base_tile + 80] = 38 + (18 * 2) + 1;
        tile[base_tile + 81] = 38 + (2 * 2) + 1;
        tile[base_tile + 82] = 38 + (14 * 2) + 1;
        tile[base_tile + 83] = 38 + (17 * 2) + 1;
        tile[base_tile + 84] = 38 + (4 * 2) + 1;

        d3 = score[15:12];
        d2 = score[11:8];
        d1 = score[7:4];
        d0 = score[3:0];

        base_score_tile = 761;
        tile[base_score_tile + 0]  = 38 + (26 * 2) + d3 * 2;
        tile[base_score_tile + 1]  = 38 + (26 * 2) + d2 * 2;
        tile[base_score_tile + 2]  = 38 + (26 * 2) + d1 * 2;
        tile[base_score_tile + 3]  = 38 + (26 * 2) + d0 * 2;
        tile[base_score_tile + 80] = 38 + (26 * 2) + d3 * 2 + 1;
        tile[base_score_tile + 81] = 38 + (26 * 2) + d2 * 2 + 1;
        tile[base_score_tile + 82] = 38 + (26 * 2) + d1 * 2 + 1;
        tile[base_score_tile + 83] = 38 + (26 * 2) + d0 * 2 + 1;
        if (trigger_tile_index != 65535)
        begin
            // if ((pacman_y[9:3] * 80 + pacman_x[9:3]) == trigger_tile_index) begin
                tile[trigger_tile_index] <= 12'h25;
            // end
        end
            // if ((pacman_y[9:3] * 80 + pacman_x[9:3]) == trigger_tile_index) begin
            //     tile[trigger_tile_index] <= 12'h25;
            // end
    end
end
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


always @(*) begin
    VGA_R = 0; VGA_G = 0; VGA_B = 0;

    if (pixel_on) begin
        if (tile_id == 12'h0A || tile_id >= 12'h26 || tile_id == 12'h14)
            {VGA_R, VGA_G, VGA_B} = 24'hFFFFFF;
        else
            VGA_B = 8'hFF;
    end

    pacman_row = 32'b0;
    if (vcount >= pacman_y + SCREEN_Y_OFFSET &&
        vcount < pacman_y + SCREEN_Y_OFFSET + 16) begin
        case (pacman_dir)
            DIR_UP:    pacman_row = pacman_up[vcount - pacman_y - SCREEN_Y_OFFSET];
            DIR_RIGHT: pacman_row = pacman_right[vcount - pacman_y - SCREEN_Y_OFFSET];
            DIR_DOWN:  pacman_row = pacman_down[vcount - pacman_y - SCREEN_Y_OFFSET];
            DIR_LEFT:  pacman_row = pacman_left[vcount - pacman_y - SCREEN_Y_OFFSET];
            DIR_EAT:   pacman_row = pacman_eat[vcount - pacman_y - SCREEN_Y_OFFSET];
        endcase
    end

    if (hcount[10:1] >= pacman_x + SCREEN_X_OFFSET &&
        hcount[10:1] < pacman_x + SCREEN_X_OFFSET + 16 &&
        vcount >= pacman_y + SCREEN_Y_OFFSET &&
        vcount < pacman_y + SCREEN_Y_OFFSET + 16 &&
        pacman_row[15 - (hcount[10:1] - pacman_x - SCREEN_X_OFFSET)]) begin
        VGA_R = 8'hFF;
        VGA_G = 8'hFF;
        VGA_B = 8'h00;
    end

    for (gi = 0; gi < 4; gi = gi + 1) begin
        if (hcount[10:1] >= ghost_x[gi] + SCREEN_X_OFFSET &&
            hcount[10:1] < ghost_x[gi] + SCREEN_X_OFFSET + 16 &&
            vcount >= ghost_y[gi] + SCREEN_Y_OFFSET &&
            vcount < ghost_y[gi] + SCREEN_Y_OFFSET + 16) begin

            gx = hcount[10:1] - ghost_x[gi] - SCREEN_X_OFFSET;
            gy = vcount - ghost_y[gi] - SCREEN_Y_OFFSET;

            case (ghost_dir[gi])
                DIR_UP:    ghost_pixel = GHOST_UP[gy][gx];
                DIR_DOWN:  ghost_pixel = GHOST_DOWN[gy][gx];
                DIR_LEFT:  ghost_pixel = GHOST_LEFT[gy][gx];
                DIR_RIGHT: ghost_pixel = GHOST_RIGHT[gy][gx];
                default:   ghost_pixel = 2'b00;
            endcase

            case (ghost_pixel)
                2'b01: case (gi)
                    0: begin VGA_R = 8'hFF; VGA_G = 0;     VGA_B = 0;     end
                    1: begin VGA_R = 8'hFF; VGA_G = 8'hAA; VGA_B = 8'hFF; end
                    2: begin VGA_R = 8'hFF; VGA_G = 8'hAA; VGA_B = 0;     end
                    3: begin VGA_R = 0;     VGA_G = 8'hFF; VGA_B = 8'hFF; end
                endcase
                2'b10: begin VGA_R = 8'hFF; VGA_G = 8'hFF; VGA_B = 8'hFF; end
                2'b11: begin VGA_R = 0;     VGA_G = 0;     VGA_B = 8'h88; end
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
