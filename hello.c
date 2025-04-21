#include <stdio.h>
#include "vga_ball.h"
#include "usbkeyboard.h"
#include <sys/ioctl.h>
#include <fcntl.h>
#include <unistd.h>
#include <libusb-1.0/libusb.h>

#define WIDTH 640
#define HEIGHT 480

int vga_ball_fd;

void update_pacman_position(unsigned short x, unsigned short y, unsigned short old_x, unsigned short old_y) {
    vga_ball_arg_t vla;
    vla.pacman_x = x;
    vla.pacman_y = y;
    vla.old_pacman_x = old_x;
    vla.old_pacman_y = old_y;

    if (ioctl(vga_ball_fd, VGA_BALL_WRITE_PACMAN_POS, &vla)) {
        perror("ioctl(VGA_BALL_WRITE_PACMAN_POS) failed");
    }
}

int main() {
    unsigned short x = 320, y = 240;
    unsigned short old_x = x, old_y = y;

    uint8_t endpoint_address;
    struct libusb_device_handle *keyboard;
    struct usb_keyboard_packet packet;

    vga_ball_fd = open("/dev/vga_ball", O_RDWR);
    if (vga_ball_fd == -1) {
        perror("Failed to open /dev/vga_ball");
        return 1;
    }

    keyboard = openkeyboard(&endpoint_address);
    if (!keyboard) {
        fprintf(stderr, "Could not find a keyboard\n");
        return 1;
    }

    printf("Pac-Man USB keyboard control started\n");

    while (1) {
        int transferred;
        int r = libusb_interrupt_transfer(keyboard, endpoint_address, (unsigned char *)&packet, sizeof(packet), &transferred, 0);
        if (r == 0 && transferred == sizeof(packet)) {
            old_x = x;
            old_y = y;

            switch (packet.keycode[0]) {
                case 0x52: // Up arrow
                    if (y > 0) y--;
                    break;
                case 0x51: // Down arrow
                    if (y < HEIGHT - 1) y++;
                    break;
                case 0x50: // Left arrow
                    if (x > 0) x--;
                    break;
                case 0x4F: // Right arrow
                    if (x < WIDTH - 1) x++;
                    break;
                default:
                    break;
            }

            update_pacman_position(x, y, old_x, old_y);
            printf("Pac-Man at (%d, %d)\n", x, y);
        }

        usleep(10000); // Delay to prevent CPU overload
    }

    libusb_close(keyboard);
    libusb_exit(NULL);
    close(vga_ball_fd);
    return 0;
}
