#ifndef _VGA_BALL_H_
#define _VGA_BALL_H_

#include <linux/ioctl.h>
#include <stdint.h>
#define VGA_BALL_MAGIC 'q'

// Sprite descriptor structure (matches your memory map)
struct sprite_desc {
    uint8_t x;
    uint8_t y;
    uint8_t frame;
    uint8_t visible;
    uint8_t direction;
    uint8_t type_id;
    uint8_t reserved1;
    uint8_t reserved2;
};

// IOCTL interface
#define VGA_BALL_WRITE_ALL _IOW(VGA_BALL_MAGIC, 1, struct vga_all_state)
#define VGA_BALL_READ_ALL  _IOR(VGA_BALL_MAGIC, 2, struct vga_all_state)

// Aggregate structure
struct vga_all_state {
    struct sprite_desc sprites[5]; // Pac-Man + 4 ghosts
    uint16_t score;
    uint8_t control;
};

typedef struct sprite_desc sprite_desc_t;
typedef struct vga_all_state vga_all_state_t;

#endif
