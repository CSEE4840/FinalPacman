#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include "controller.h"

char buttons[6] = "_____";

int main() {
    printf("=== Controller Test Start ===\n");

    struct controller_list ctrl = open_controller();

    struct args_list args = {
        .devices = ctrl,
        .buttons = buttons,
        .mode = 0,
        .print = 1,  // 打印输出当前按键状态
    };

    pthread_t tid;
    if (pthread_create(&tid, NULL, listen_controller, &args) != 0) {
        perror("Failed to create listening thread");
        return 1;
    }

    // 主线程轮询查看按键状态
    while (1) {
        printf("Current Buttons: %s\n", buttons);
        usleep(500000);  // 每500ms打印一次
    }

    // 不会真正退出（CTRL+C手动终止），理论上这里应该清理资源
    return 0;
}