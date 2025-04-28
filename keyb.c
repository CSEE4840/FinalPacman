#include <stdio.h>
#include <string.h>
#include <libusb-1.0/libusb.h>
#include "usbkeyboard.h"
#include <time.h>
#define INPUT_BUFFER_SIZE 256
#define CHAT_COLS 64
#define INPUT_ROWS 2
#define MAX_KEYS 6

// USB Keyboard 相关
struct usb_keyboard_packet packet;
struct libusb_device_handle *keyboard;
uint8_t endpoint_address;
int use_terminal_input = 0; // fallback 标志

// 输入缓存
char input_buffer[INPUT_BUFFER_SIZE];
char display_buffer[INPUT_ROWS][CHAT_COLS];
int cursor_pos = 0;
int start_idx = 0;

// 转换USB键盘 scancode 到 ASCII
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
    ascii_map[0x2C] = ' '; // space
    ascii_map[0x28] = '\n'; // enter
    ascii_map[0x2A] = '\b'; // backspace
    ascii_map[0x50] = 2; // left arrow
    ascii_map[0x4F] = 3; // right arrow

    if (modifiers & USB_LSHIFT || modifiers & USB_RSHIFT) {
        if (keycode >= 0x04 && keycode <= 0x1D) {
            return ascii_map[keycode] - 32; // 大写字母
        }
    }
    return ascii_map[keycode];
}

// // 更新显示缓存
// void update_display_buffer() {
//     memset(display_buffer, ' ', sizeof(display_buffer));
//     start_idx = (cursor_pos < CHAT_COLS * INPUT_ROWS) ? 0 : (cursor_pos / CHAT_COLS - 1) * CHAT_COLS;
//     int len = strlen(input_buffer + start_idx);
//     int to_copy = (len > CHAT_COLS * INPUT_ROWS) ? CHAT_COLS * INPUT_ROWS : len;
//     for (int i = 0; i < to_copy; i++) {
//         display_buffer[i / CHAT_COLS][i % CHAT_COLS] = input_buffer[start_idx + i];
//     }
// }

// // 简单打印（终端用，替代 fbputchar）
// void print_display_buffer() {
//     printf("\033[2J\033[H"); // 清屏+光标归位
//     for (int row = 0; row < INPUT_ROWS; row++) {
//         for (int col = 0; col < CHAT_COLS; col++) {
//             putchar(display_buffer[row][col]);
//         }
//         putchar('\n');
//     }
//     printf("> "); // 输入提示符
// }

// 处理按键逻辑
void handle_input(char c) {
    if (c == '\n') {
        printf("\n[Send] %s\n", input_buffer);
        memset(input_buffer, 0, sizeof(input_buffer));
        cursor_pos = 0;
    } else if (c == '\b') {
        if (cursor_pos > 0) {
            cursor_pos--;
            for (int i = cursor_pos; i < INPUT_BUFFER_SIZE - 1; i++) {
                input_buffer[i] = input_buffer[i + 1];
            }
            input_buffer[INPUT_BUFFER_SIZE - 1] = '\0';
        }
    } else if (c == 2) { // left arrow
        if (cursor_pos > 0) cursor_pos--;
    } else if (c == 3) { // right arrow
        if (cursor_pos < strlen(input_buffer)) cursor_pos++;
    } else {
        if (cursor_pos < INPUT_BUFFER_SIZE - 1) {
            for (int i = INPUT_BUFFER_SIZE - 1; i > cursor_pos; i--) {
                input_buffer[i] = input_buffer[i-1];
            }
            input_buffer[cursor_pos++] = c;
        }
    }
    // update_display_buffer();
    // print_display_buffer();
}

// 主入口
int main() {
    uint8_t prev_keys[MAX_KEYS] = {0};
    int transferred;

    if ((keyboard = openkeyboard(&endpoint_address)) == NULL) {
        printf("Cannot find USB keyboard.\n");
        return 1;
    }
    printf("USB keyboard found, start typing...\n");

    // update_display_buffer();
    // print_display_buffer();

    while (1) {
        int r = libusb_interrupt_transfer(keyboard, endpoint_address,
                                          (unsigned char *)&packet, sizeof(packet),
                                          &transferred, 0);
        // printf("libusb_interrupt_transfer returned: %d\n", r);
        if (r == 0 && transferred == sizeof(packet)) {
            for (int i = 0; i < MAX_KEYS; i++) {
                uint8_t key = packet.keycode[i];
                if (key != 0) {
                    printf("Key pressed: %02X\n", key);
                    handle_input(usb_to_ascii(key, packet.modifiers));
                }
            }
            if (packet.keycode[0] == 0x29) { // ESC to exit
                printf("ESC pressed. Exiting.\n");
                break;
            }
        }
    
        // 延迟 0.1 秒（100 毫秒）
        struct timespec ts;
        ts.tv_sec = 0;
        ts.tv_nsec = 100 * 1000 * 1000; // 100ms = 100,000,000ns
        nanosleep(&ts, NULL);
    }

    return 0;
}