#ifndef _VGA_BALL_H_
#define _VGA_BALL_H_

#include <linux/ioctl.h>

#define VGA_BALL_MAGIC            'q'
#define VGA_BALL_WRITE_PACMAN_POS _IOW(VGA_BALL_MAGIC, 1, struct vga_ball_arg)
#define VGA_BALL_READ_PACMAN_POS  _IOR(VGA_BALL_MAGIC, 2, struct vga_ball_arg)

struct vga_ball_arg {
    unsigned short pacman_x;
    unsigned short pacman_y;
    unsigned short old_pacman_x;
    unsigned short old_pacman_y;
};

typedef struct vga_ball_arg vga_ball_arg_t;

#endif
