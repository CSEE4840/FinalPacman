// vga_ball.h
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


// vga_ball.c
#include <linux/module.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/platform_device.h>
#include <linux/miscdevice.h>
#include <linux/io.h>
#include <linux/of.h>
#include <linux/of_address.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include "vga_ball.h"

#define DRIVER_NAME "vga_ball"

#define PACMAN_X(x)        ((x) + 0)
#define PACMAN_Y(x)        ((x) + 2)
#define PACMAN_OLD_X(x)    ((x) + 4)
#define PACMAN_OLD_Y(x)    ((x) + 6)

struct vga_ball_dev {
    struct resource res;
    void __iomem *virtbase;
    unsigned short pacman_x, pacman_y;
    unsigned short old_pacman_x, old_pacman_y;
} dev;

static void write_pacman_position(vga_ball_arg_t *vla) {
    iowrite16(vla->pacman_x,     PACMAN_X(dev.virtbase));
    iowrite16(vla->pacman_y,     PACMAN_Y(dev.virtbase));
    iowrite16(vla->old_pacman_x, PACMAN_OLD_X(dev.virtbase));
    iowrite16(vla->old_pacman_y, PACMAN_OLD_Y(dev.virtbase));

    dev.pacman_x = vla->pacman_x;
    dev.pacman_y = vla->pacman_y;
    dev.old_pacman_x = vla->old_pacman_x;
    dev.old_pacman_y = vla->old_pacman_y;
}

static long vga_ball_ioctl(struct file *f, unsigned int cmd, unsigned long arg) {
    vga_ball_arg_t vla;

    switch (cmd) {
        case VGA_BALL_WRITE_PACMAN_POS:
            if (copy_from_user(&vla, (void __user *)arg, sizeof(vga_ball_arg_t)))
                return -EFAULT;
            write_pacman_position(&vla);
            break;

        case VGA_BALL_READ_PACMAN_POS:
            vla.pacman_x = dev.pacman_x;
            vla.pacman_y = dev.pacman_y;
            vla.old_pacman_x = dev.old_pacman_x;
            vla.old_pacman_y = dev.old_pacman_y;

            if (copy_to_user((void __user *)arg, &vla, sizeof(vga_ball_arg_t)))
                return -EFAULT;
            break;

        default:
            return -EINVAL;
    }

    return 0;
}

static const struct file_operations vga_ball_fops = {
    .owner = THIS_MODULE,
    .unlocked_ioctl = vga_ball_ioctl,
};

static struct miscdevice vga_ball_misc_device = {
    .minor = MISC_DYNAMIC_MINOR,
    .name = DRIVER_NAME,
    .fops = &vga_ball_fops,
};

static int __init vga_ball_probe(struct platform_device *pdev) {
    int ret;

    ret = misc_register(&vga_ball_misc_device);
    if (ret)
        return ret;

    ret = of_address_to_resource(pdev->dev.of_node, 0, &dev.res);
    if (ret)
        goto out_deregister;

    if (request_mem_region(dev.res.start, resource_size(&dev.res), DRIVER_NAME) == NULL) {
        ret = -EBUSY;
        goto out_deregister;
    }

    dev.virtbase = of_iomap(pdev->dev.of_node, 0);
    if (dev.virtbase == NULL) {
        ret = -ENOMEM;
        goto out_release_mem;
    }

    return 0;

out_release_mem:
    release_mem_region(dev.res.start, resource_size(&dev.res));
out_deregister:
    misc_deregister(&vga_ball_misc_device);
    return ret;
}

static int vga_ball_remove(struct platform_device *pdev) {
    iounmap(dev.virtbase);
    release_mem_region(dev.res.start, resource_size(&dev.res));
    misc_deregister(&vga_ball_misc_device);
    return 0;
}

#ifdef CONFIG_OF
static const struct of_device_id vga_ball_of_match[] = {
    { .compatible = "csee4840,vga_ball-1.0" },
    {},
};
MODULE_DEVICE_TABLE(of, vga_ball_of_match);
#endif

static struct platform_driver vga_ball_driver = {
    .driver = {
        .name = DRIVER_NAME,
        .owner = THIS_MODULE,
        .of_match_table = of_match_ptr(vga_ball_of_match),
    },
    .remove = __exit_p(vga_ball_remove),
};

static int __init vga_ball_init(void) {
    pr_info(DRIVER_NAME ": init\n");
    return platform_driver_probe(&vga_ball_driver, vga_ball_probe);
}

static void __exit vga_ball_exit(void) {
    platform_driver_unregister(&vga_ball_driver);
    pr_info(DRIVER_NAME ": exit\n");
}

module_init(vga_ball_init);
module_exit(vga_ball_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Your Name");
MODULE_DESCRIPTION("Pac-Man VGA Controller - Position via Software");


// hello.c
#include <stdio.h>
#include "vga_ball.h"
#include <sys/ioctl.h>
#include <fcntl.h>
#include <unistd.h>

#define WIDTH 640
#define HEIGHT 480

int vga_ball_fd;

void update_pacman_position(unsigned short x, unsigned short y, unsigned short old_x, unsigned short old_y) {
    vga_ball_arg_t vla;
    vla.pacman_x = x;
    vla.pacman_y = y;
    vla.old_pacman_x = old_x;
    vla.old_pacman_y = old_y;

    if (ioctl(vga_ball_fd, VGA_BALL_WRITE_PACMAN_POS, &vla) < 0) {
        perror("ioctl(VGA_BALL_WRITE_PACMAN_POS) failed");
    }
}

int main() {
    unsigned short x = 0, y = 0;
    unsigned short old_x = 0, old_y = 0;

    vga_ball_fd = open("/dev/vga_ball", O_RDWR);
    if (vga_ball_fd == -1) {
        perror("Failed to open /dev/vga_ball");
        return 1;
    }

    printf("Pac-Man software position control started\n");

    while (1) {
        update_pacman_position(x, y, old_x, old_y);
        printf("Pac-Man at (%d, %d)\n", x, y);

        old_x = x;
        old_y = y;
        x = (x + 1) % WIDTH;
        y = (y + 1) % HEIGHT;

        usleep(30000); // ~30ms delay (adjust as needed)
    }

    close(vga_ball_fd);
    return 0;
}
