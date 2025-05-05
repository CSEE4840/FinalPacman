CFLAGS = -Wall -I/opt/homebrew/Cellar/libusb/1.0.27/include -L/opt/homebrew/lib
LDFLAGS = -lusb-1.0
CC = gcc

# 源文件和目标文件
SRC = main.c usbkeyboard.c vga_ball.c
OBJ = $(SRC:.c=.o)

# 所有相关文件（用于打包）
TARFILES = Makefile main.c usbkeyboard.h usbkeyboard.c vga_ball.c vga_ball.h

# 最终目标
lab2: $(OBJ)
	$(CC) $(CFLAGS) -o $@ $(OBJ) $(LDFLAGS) -pthread

# 打包命令
lab2.tar.gz: $(TARFILES)
	rm -rf lab2
	mkdir lab2
	ln $(TARFILES) lab2
	tar zcf lab2.tar.gz lab2
	rm -rf lab2

# 自动生成依赖关系
main.o: main.c usbkeyboard.h vga_ball.h
usbkeyboard.o: usbkeyboard.c usbkeyboard.h
vga_ball.o: vga_ball.c vga_ball.h

.PHONY: clean
clean:
	rm -f *.o lab2 lab2.tar.gz