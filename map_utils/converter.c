/*
Convert maze tiles to a simple format for export.

This program reads a maze representation from a string, maps each character to a unique ID,
and writes the mapping to a CSV file and the maze data to a TIF-like text file.

Put the maze representation in the `tiles` string and run the program to generate the output files.
*/
#include <stdio.h>
#include <stdint.h>

int main() {
    const char* tiles =
        "0UUUUUUUUUUUU45UUUUUUUUUUUU1"
        "L............rl............R"
        "L.ebbf.ebbbf.rl.ebbbf.ebbf.R"
        "LPr  l.r   l.rl.r   l.r  lPR"
        "L.guuh.guuuh.gh.guuuh.guuh.R"
        "L..........................R"
        "L.ebbf.ef.ebbbbbbf.ef.ebbf.R"
        "L.guuh.rl.guuyxuuh.rl.guuh.R"
        "L......rl....rl....rl......R"
        "2BBBBf.rzbbf rl ebbwl.eBBBB3"
        "     L.rxuuh gh guuyl.R     "
        "     L.rl          rl.R     "
        "     L.rl mjs  tjn rl.R     "
        "UUUUUh.gh i      q gh.gUUUUU"
        "      .   i      q   .      "
        "BBBBBf.ef i      q ef.eBBBBB"
        "     L.rl okkkkkkp rl.R     "
        "     L.rl          rl.R     "
        "     L.rl ebbbbbbf rl.R     "
        "0UUUUh.gh guuyxuuh gh.gUUUU1"
        "L............rl............R"
        "L.ebbf.ebbbf.rl.ebbbf.ebbf.R"
        "L.guyl.guuuh.gh.guuuh.rxuh.R"
        "LP..rl.......  .......rl..PR"
        "6bf.rl.ef.ebbbbbbf.ef.rl.eb8"
        "7uh.gh.rl.guuyxuuh.rl.gh.gu9"
        "L......rl....rl....rl......R"
        "L.ebbbbwzbbf.rl.ebbwzbbbbf.R"
        "L.guuuuuuuuh.gh.guuuuuuuuh.R"
        "L..........................R"
        "2BBBBBBBBBBBBBBBBBBBBBBBBBB3";

    int width = 28;
    int height = 31;

    int mapping[128];
    for (int i = 0; i < 128; i++) mapping[i] = -1;

    mapping[' '] = 0;
    mapping['.'] = 1;
    mapping['0'] = 2;
    mapping['1'] = 3;
    mapping['2'] = 4;
    mapping['3'] = 5;
    mapping['4'] = 6;
    mapping['5'] = 7;
    mapping['6'] = 8;
    mapping['7'] = 9;
    mapping['8'] = 10;
    mapping['9'] = 11;
    mapping['U'] = 12;
    mapping['D'] = 13;
    mapping['L'] = 14;
    mapping['R'] = 15;
    mapping['B'] = 16;
    mapping['e'] = 17;
    mapping['b'] = 18;
    mapping['f'] = 19;
    mapping['g'] = 20;
    mapping['h'] = 21;
    mapping['i'] = 22;
    mapping['j'] = 23;
    mapping['k'] = 24;
    mapping['l'] = 25;
    mapping['m'] = 26;
    mapping['n'] = 27;
    mapping['o'] = 28;
    mapping['p'] = 29;
    mapping['q'] = 30;
    mapping['r'] = 31;
    mapping['s'] = 32;
    mapping['t'] = 33;
    mapping['u'] = 34;
    mapping['w'] = 35;
    mapping['x'] = 36;
    mapping['y'] = 37;
    mapping['z'] = 38;
    mapping['P'] = 39;
    mapping['G'] = 40;

    FILE* tif_fp = fopen("maze_output.tif", "w");
    FILE* csv_fp = fopen("mapping.csv", "w");

    if (!tif_fp || !csv_fp) {
        printf("Cannot open output files!\n");
        return 1;
    }

    fprintf(csv_fp, "Character,MappingID\n");
    for (int i = 0; i < 128; i++) {
        if (mapping[i] != -1) {
            if (i == ' ') fprintf(csv_fp, "' '"); // 空格单独处理
            else fprintf(csv_fp, "%c", i);
            fprintf(csv_fp, ",%d\n", mapping[i]);
        }
    }

    int total_tiles = width * height;
    for (int idx = 0; idx < total_tiles; idx++) {
        char tile_char = tiles[idx];
        int tile_id = (tile_char >= 0 && tile_char < 128) ? mapping[(int)tile_char] : -1;
        if (tile_id == -1) tile_id = 99; // 未知tile用99占位

        fprintf(tif_fp, "%02X: %d\n", idx, tile_id); // index用两位十六进制
    }

    fclose(tif_fp);
    fclose(csv_fp);

    printf("Maze export done: maze_output.tif + mapping.csv generated!\n");

    return 0;
}