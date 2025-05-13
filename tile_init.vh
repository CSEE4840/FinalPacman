module tonegen (
    input  logic        clk,
    input  logic        reset,
    input  logic        left_chan_ready,
    input  logic        right_chan_ready,
    output logic [15:0] sample_data,
    output logic        sample_valid
);

    logic [16:0] bg_address;
    logic [15:0] bg_data;
    logic [15:0] bg_rom [0:121593];  // Match the number of samples

    initial $readmemh("background.vh", bg_rom);  // Load hex file at synthesis or simulation time

    logic [12:0] sample_clock;

    always_ff @(posedge clk) begin
        if (reset) begin
            bg_address    <= 0;
            sample_clock  <= 0;
            sample_data   <= 0;
            sample_valid  <= 0;
        end else if (left_chan_ready && right_chan_ready) begin
            if (sample_clock >= 13'd6250) begin  // ~8kHz
                sample_clock <= 0;

                // Loop
                if (bg_address < 17'd121593)
                    bg_address <= bg_address + 1;
                else
                    bg_address <= 0;

                sample_data  <= bg_rom[bg_address];
                sample_valid <= 1;
            end else begin
                sample_clock <= sample_clock + 1;
                sample_valid <= 0;
            end
        end else begin
            sample_valid <= 0;
        end
    end
endmodule
