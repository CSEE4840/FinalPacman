#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <libusb-1.0/libusb.h>
#include "usbkeyboard.h" // 你需要有这个头文件

#define INPUT_BUFFER_SIZE 256
#define CHAT_COLS 64
#define INPUT_ROWS 2
#define MAX_KEYS 6

// === USB Keyboard相关 ===
struct usb_keyboard_packet packet;
struct libusb_device_handle *keyboard;
uint8_t endpoint_address;

// 键盘码转ASCII
char usb_to_ascii(uint8_t keycode, uint8_t modifiers) {
    static char ascii_map[256] = {0};
    ascii_map[0x04] = 'a'; ascii_map[0x05] = 'b'; ascii_map[0x06] = 'c';
    ascii_map[0x07] = 'd'; ascii_map[0x08] = 'e'; ascii_map[0x09] = 'f';
    ascii_map[0x0A] = 'g'; ascii_map[0x0B] = 'h'; ascii_map[0x0C] = 'i';
    ascii_map[0x0D] = 'j'; ascii_map[0x0E] = 'k'; ascii_map[0x0F] = 'l';
    ascii_map[0x10] = 'm'; ascii_map[0x11] = 'n'; ascii_map[0x12] = 'o';
    ascii_map[0x13] = 'p'; ascii_map[0x14] = 'q'; ascii_map[0x15] = 'r';
    ascii_map[0x16] = 's'; ascii_map[0x17] = 't'; ascii_map[0x18] = 'u';
    ascii_map[0x19] = 'v'; ascii_map[0x1A] = 'w'; ascii_map[0x1B] = 'x';
    ascii_map[0x1C] = 'y'; ascii_map[0x1D] = 'z';
    ascii_map[0x1E] = '1'; ascii_map[0x1F] = '2'; ascii_map[0x20] = '3';
    ascii_map[0x21] = '4'; ascii_map[0x22] = '5'; ascii_map[0x23] = '6';
    ascii_map[0x24] = '7'; ascii_map[0x25] = '8'; ascii_map[0x26] = '9';
    ascii_map[0x27] = '0';
    ascii_map[0x2C] = ' '; // 空格
    ascii_map[0x28] = '\n'; // Enter
    ascii_map[0x2A] = '\b'; // Backspace
    ascii_map[0x50] = 2;    // Left arrow
    ascii_map[0x4F] = 3;    // Right arrow
    ascii_map[0x52] = 4;    // Up arrow
    ascii_map[0x51] = 5;    // Down arrow

    if (modifiers & USB_LSHIFT || modifiers & USB_RSHIFT) {
        if (keycode >= 0x04 && keycode <= 0x1D) {
            return ascii_map[keycode] - 32; // 大写
        }
    }
    return ascii_map[keycode];
}

// 接收方向键控制
void handle_input(char c) {
    extern uint8_t pacman_dir;
    if (c == 2) { // left
        pacman_dir = 1;
    } else if (c == 3) { // right
        pacman_dir = 3;
    } else if (c == 4) { // up
        pacman_dir = 0;
    } else if (c == 5) { // down
        pacman_dir = 2;
    }
}

// === Pac-Man 游戏逻辑 ===
typedef struct {
    uint8_t x, y;
    uint8_t frame;
    uint8_t visible;
    uint8_t direction;
    uint8_t type_id;
    uint8_t rsv1, rsv2;
} sprite_t;

typedef struct {
    int x, y;
    uint8_t dir;
    sprite_t* sprite;
} ghost_t;

#define TILE_WIDTH 8
#define TILE_HEIGHT 8
#define SCREEN_WIDTH_TILES 28
#define SCREEN_HEIGHT_TILES 33
#define NUM_GHOSTS 4
#define SPRITE_PACMAN 0
#define SPRITE_GHOST_0 1
#define SPRITE_GHOST_1 2
#define SPRITE_GHOST_2 3
#define SPRITE_GHOST_3 4

// 模拟RAM
uint8_t fake_tilemap[40 * 30];
uint32_t fake_pellet_ram[30];
sprite_t fake_sprites[5];
uint16_t fake_score;
uint32_t fake_control = 1;

#define TILEMAP_BASE     (fake_tilemap)
#define PELLET_RAM_BASE  (fake_pellet_ram)
#define SPRITE_BASE      ((uint8_t*) fake_sprites)
#define SCORE_REG        (&fake_score)
#define CONTROL_REG      (&fake_control)

ghost_t ghosts[NUM_GHOSTS];
sprite_t* sprites = (sprite_t*) SPRITE_BASE;

int pacman_x = 15 * TILE_WIDTH + TILE_WIDTH / 2;
int pacman_y = 23 * TILE_HEIGHT + TILE_HEIGHT / 2;
uint8_t pacman_dir = 1; // 初始向左
uint16_t score = 0;

// 工具函数
void set_tile(int x, int y, uint8_t tile_id) {
    TILEMAP_BASE[y * SCREEN_WIDTH_TILES + x] = tile_id;
}

uint8_t get_pellet_bit(int x, int y) {
    return (PELLET_RAM_BASE[y] >> (31 - x)) & 1;
}

void clear_pellet_bit(int x, int y) {
    PELLET_RAM_BASE[y] &= ~(1 << (31 - x));
}

bool can_move_to(int px, int py) {
    int tx = px / TILE_WIDTH;
    int ty = py / TILE_HEIGHT;
    if (tx < 0 || tx >= 40 || ty < 0 || ty >= 30) return false;
    uint8_t tile = TILEMAP_BASE[ty * SCREEN_WIDTH_TILES + tx];
    return (tile == 0x40 || tile == 1 || tile == 0);
}

void update_pacman() {
    int new_x = pacman_x;
    int new_y = pacman_y;
    switch (pacman_dir) {
        case 0: begin new_y -= TILE_HEIGHT;  break; end;
        case 1: begin new_x -= TILE_WIDTH; break; end;
        case 2: begin new_y += TILE_HEIGHT; break; end;
        case 3: begin new_x += TILE_WIDTH; break; end;
    }

    if (can_move_to(new_x, new_y)) {
        pacman_x = new_x;
        pacman_y = new_y;

    }

    int tile_x = pacman_x / TILE_WIDTH;
    int tile_y = pacman_y / TILE_HEIGHT;
    if (get_pellet_bit(tile_x, tile_y)) {
        clear_pellet_bit(tile_x, tile_y);
        set_tile(tile_x, tile_y, 0);
        score += 10;
        *SCORE_REG = score;
        printf("[Pac-Man] Ate pellet at (%d, %d). Score = %d\n", tile_x, tile_y, score);
    }

    sprite_t* pac = &sprites[SPRITE_PACMAN];
    pac->x = pacman_x;
    pac->y = pacman_y;
    pac->direction = pacman_dir;
    pac->visible = 1;
    pac->frame = 0;
}

bool is_ghost_tile(int x, int y) {
    for (int i = 0; i < NUM_GHOSTS; i++) {
        if (ghosts[i].x / TILE_WIDTH == x && ghosts[i].y / TILE_HEIGHT == y) return true;
    }
    return false;
}

void print_tilemap() {
    printf("=== Tilemap View ===\n");
    for (int y = 3; y <= 33; y++) {
        for (int x = 0; x < 28; x++) {
            uint8_t tile = TILEMAP_BASE[y * SCREEN_WIDTH_TILES + x];
            if (pacman_x / TILE_WIDTH == x && pacman_y / TILE_HEIGHT == y) {
                putchar('P');
            } else if (is_ghost_tile(x, y)) {
                putchar('G');
            } else if (tile == 0 || tile == 0x40) {
                putchar(' ');
            } else if (tile == 1) {
                putchar('.');
            } else {
                putchar('#');
            }
        }
        putchar('\n');
    }
    printf("====================\n");
}

void update_ghosts() {
    static int ghost_tick = 0;
    ghost_tick++;
    if (ghost_tick % 10 != 0) return;

    for (int i = 0; i < NUM_GHOSTS; i++) {
        ghost_t* g = &ghosts[i];
        int new_x = g->x;
        int new_y = g->y;
        switch (g->dir) {
            case 0: new_y -= TILE_HEIGHT; break;
            case 1: new_x -= TILE_WIDTH; break;
            case 2: new_y += TILE_HEIGHT; break;
            case 3: new_x += TILE_WIDTH; break;
        }
        if (can_move_to(new_x, new_y)) {
            g->x = new_x;
            g->y = new_y;
        } else {
            g->dir = (g->dir + 1) % 4;
        }
        g->sprite->x = g->x;
        g->sprite->y = g->y;
    }
}

void game_init_playfield(void) {
    static const char* tiles =
       //0123456789012345678901234567
        "0UUUUUUUUUUUU45UUUUUUUUUUUU1" // 3
        "L............rl............R" // 4
        "L.ebbf.ebbbf.rl.ebbbf.ebbf.R" // 5
        "LPr  l.r   l.rl.r   l.r  lPR" // 6
        "L.guuh.guuuh.gh.guuuh.guuh.R" // 7
        "L..........................R" // 8
        "L.ebbf.ef.ebbbbbbf.ef.ebbf.R" // 9
        "L.guuh.rl.guuyxuuh.rl.guuh.R" // 10
        "L......rl....rl....rl......R" // 11
        "2BBBBf.rzbbf rl ebbwl.eBBBB3" // 12
        "     L.rxuuh gh guuyl.R     " // 13
        "     L.rl          rl.R     " // 14
        "     L.rl mjs  tjn rl.R     " // 15
        "UUUUUh.gh i      q gh.gUUUUU" // 16
        "      .   i      q   .      " // 17
        "BBBBBf.ef i      q ef.eBBBBB" // 18
        "     L.rl okkkkkkp rl.R     " // 19
        "     L.rl          rl.R     " // 20
        "     L.rl ebbbbbbf rl.R     " // 21
        "0UUUUh.gh guuyxuuh gh.gUUUU1" // 22
        "L............rl............R" // 23
        "L.ebbf.ebbbf.rl.ebbbf.ebbf.R" // 24
        "L.guyl.guuuh.gh.guuuh.rxuh.R" // 25
        "LP..rl.......  .......rl..PR" // 26
        "6bf.rl.ef.ebbbbbbf.ef.rl.eb8" // 27
        "7uh.gh.rl.guuyxuuh.rl.gh.gu9" // 28
        "L......rl....rl....rl......R" // 29
        "L.ebbbbwzbbf.rl.ebbwzbbbbf.R" // 30
        "L.guuuuuuuuh.gh.guuuuuuuuh.R" // 31
        "L..........................R" // 32
        "2BBBBBBBBBBBBBBBBBBBBBBBBBB3"; // 33
       //0123456789012345678901234567

    uint8_t t[128];
    for (int i = 0; i < 128; i++) t[i] = 1;
    t[' '] = 0x40; t['0'] = 0xD1; t['1'] = 0xD0; t['2'] = 0xD5; t['3'] = 0xD4;
    t['4'] = 0xFB; t['5'] = 0xFA; t['6'] = 0xD7; t['7'] = 0xD9;
    t['8'] = 0xD6; t['9'] = 0xD8; t['U'] = 0xDB; t['L'] = 0xD3;
    t['R'] = 0xD2; t['B'] = 0xDC; t['b'] = 0xDF; t['e'] = 0xE7;
    t['f'] = 0xE6; t['g'] = 0xEB; t['h'] = 0xEA; t['l'] = 0xE8;
    t['r'] = 0xE9; t['u'] = 0xE5; t['w'] = 0xF5; t['x'] = 0xF2;
    t['y'] = 0xF3; t['z'] = 0xF4; t['m'] = 0xED; t['n'] = 0xEC;
    t['o'] = 0xEF; t['p'] = 0xEE; t['j'] = 0xDD; t['i'] = 0xD2;
    t['k'] = 0xDB; t['q'] = 0xD3; t['s'] = 0xF1; t['t'] = 0xF0;
    t['-'] = 0xFE; t['P'] = 0xFD;

    for (int y = 3, i = 0; y <= 33; y++) {
        for (int x = 0; x < 28; x++, i++) {
            set_tile(x, y, t[tiles[i] & 127]);
            if (tiles[i] == '.' || tiles[i] == 'P') {
                PELLET_RAM_BASE[y] |= (1 << (31 - x));
            }
        }
    }
}
void init_ghosts() {
    const int start_positions[4][2] = {
        {13, 14}, {14, 14}, {13, 15}, {14, 15}
        
    };
    for (int i = 0; i < NUM_GHOSTS; i++) {
        ghosts[i].x = start_positions[i][0] * TILE_WIDTH + TILE_WIDTH / 2;
        ghosts[i].y = start_positions[i][1] * TILE_HEIGHT + TILE_HEIGHT / 2;
        ghosts[i].dir = i % 4;
        ghosts[i].sprite = &sprites[SPRITE_GHOST_0 + i];
        ghost_t* g = &ghosts[i];
        g->sprite->x = g->x;
        g->sprite->y = g->y;
        g->sprite->visible = 1;
        g->sprite->frame = 0;
    }
}

void game_init() {
    *SCORE_REG = 0;
    game_init_playfield();
    init_ghosts();
    sprite_t* pac = &sprites[SPRITE_PACMAN];
    pac->x = pacman_x;
    pac->y = pacman_y;
    pac->visible = 1;
    pac->frame = 0;
}

void game_loop() {
    uint8_t prev_keys[MAX_KEYS] = {0};
    int transferred;

    while (1) {
        int r = libusb_interrupt_transfer(keyboard, endpoint_address,
                                          (unsigned char *)&packet, sizeof(packet),
                                          &transferred, 0);
        if (r == 0 && transferred == sizeof(packet)) {
            for (int i = 0; i < MAX_KEYS; i++) {
                uint8_t key = packet.keycode[i];
                if (key != 0) {
                    handle_input(usb_to_ascii(key, packet.modifiers));
                }
            }
            if (packet.keycode[0] == 0x29) { // ESC退出
                printf("ESC pressed. Exiting.\n");
                break;
            }
        }

        update_pacman();
        print_tilemap();
        update_ghosts();
        usleep(100000);
        while (!(*CONTROL_REG & 0x1)) {}
    }
}

int main() {
    game_init();

    if ((keyboard = openkeyboard(&endpoint_address)) == NULL) {
        printf("Cannot find USB keyboard.\n");
        return 1;
    }
    printf("USB keyboard found, start playing...\n");

    game_loop();
    return 0;
}
