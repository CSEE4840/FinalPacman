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
        case 0: new_y -= TILE_HEIGHT; break;
        case 1: new_x -= TILE_WIDTH; break;
        case 2: new_y += TILE_HEIGHT; break;
        case 3: new_x += TILE_WIDTH; break;
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

void game_init_playfield();
void init_ghosts();

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
