#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <linux/fb.h>
#include <stdint.h>
#include <string.h>

#define COLOR_BG      0x1E1E2E 
#define COLOR_BAR     0x11111B
#define COLOR_WIN_HDR 0x89B4FA
#define COLOR_WIN_BDY 0x252538
#define COLOR_CURSOR  0xF38BA8
#define COLOR_BUTTON  0xF9E2AF

int fb_fd = -1, mouse_fd = -1;
uint32_t *fbp = NULL;
uint32_t *back_buffer = NULL;
struct fb_var_screeninfo vinfo;
struct fb_fix_screeninfo finfo;
long screensize = 0;

void draw_pixel(int x, int y, uint32_t color) {
    if (x >= 0 && x < vinfo.xres && y >= 0 && y < vinfo.yres) {
        back_buffer[y * vinfo.xres + x] = color;
    }
}

void draw_rect(int x, int y, int w, int h, uint32_t color) {
    for (int i = 0; i < h; i++) {
        for (int j = 0; j < w; j++) {
            draw_pixel(x + j, y + i, color);
        }
    }
}

void draw_cursor(int cx, int cy) {
    for (int i = -5; i <= 5; i++) {
        draw_pixel(cx + i, cy, COLOR_CURSOR);
        draw_pixel(cx, cy + i, COLOR_CURSOR);
    }
}

int main() {
    fb_fd = open("/dev/fb0", O_RDWR);
    if (fb_fd == -1) {
        perror("Error: cannot open framebuffer device");
        return 1;
    }

    if (ioctl(fb_fd, FBIOGET_FSCREENINFO, &finfo) < 0) return 1;
    if (ioctl(fb_fd, FBIOGET_VSCREENINFO, &vinfo) < 0) return 1;

    if (vinfo.bits_per_pixel != 32) {
        printf("Error: Screen is not in 32-bit mode! current: %d bpp\n", vinfo.bits_per_pixel);
        close(fb_fd);
        return 1;
    }

    screensize = vinfo.xres * vinfo.yres * 4; // 4 байта на пиксель

    fbp = (uint32_t *)mmap(0, screensize, PROT_READ | PROT_WRITE, MAP_SHARED, fb_fd, 0);
    if ((intptr_t)fbp == -1) {
        perror("Error: failed to mmap framebuffer");
        return 1;
    }

    back_buffer = malloc(screensize);

    mouse_fd = open("/dev/input/mice", O_RDONLY | O_NONBLOCK);
    if (mouse_fd == -1) {
        mouse_fd = open("/dev/mice", O_RDONLY | O_NONBLOCK);
    }

    int mx = vinfo.xres / 2;
    int my = vinfo.yres / 2;

    int wx = 150, wy = 100; 
    int ww = 350, wh = 220; 
    int wh_size = 30;
    
    int is_dragging = 0;
    int drag_off_x = 0, drag_off_y = 0;

    printf("FAD-UI Started successfully! Resolution: %dx%d\n", vinfo.xres, vinfo.yres);

    while (1) {
        signed char mouse_data[3];
        if (mouse_fd != -1 && read(mouse_fd, mouse_data, 3) == 3) {
            int left_click = mouse_data[0] & 0x1;
            int rel_x = mouse_data[1];
            int rel_y = mouse_data[2]; 

            mx += rel_x;
            my -= rel_y; 

            if (mx < 0) mx = 0;
            if (mx >= vinfo.xres) mx = vinfo.xres - 1;
            if (my < 0) my = 0;
            if (my >= vinfo.yres) my = vinfo.yres - 1;

            if (left_click) {
                if (!is_dragging) {
                    if (mx >= wx && mx <= (wx + ww) && my >= wy && my <= (wy + wh_size)) {
                        is_dragging = 1;
                        drag_off_x = mx - wx;
                        drag_off_y = my - wy;
                    }
                } else {
                    wx = mx - drag_off_x;
                    wy = my - drag_off_y;
                }
            } else {
                is_dragging = 0; 
            }
        }

        draw_rect(0, 0, vinfo.xres, vinfo.yres, COLOR_BG);

        int bar_h = 40;
        draw_rect(0, vinfo.yres - bar_h, vinfo.xres, bar_h, COLOR_BAR);
        draw_rect(10, vinfo.yres - bar_h + 8, 50, 24, COLOR_WIN_HDR);

        draw_rect(wx, wy, ww, wh_size, COLOR_WIN_HDR);          // Заголовок окна
        draw_rect(wx, wy + wh_size, ww, wh - wh_size, COLOR_WIN_BDY); // Тело окна
        
        draw_rect(wx + 15, wy + wh_size + 20, 80, 25, COLOR_BUTTON);
        draw_rect(wx + ww - 25, wy + 8, 14, 14, COLOR_CURSOR); // Кнопка закрытия X

        draw_cursor(mx, my);

        memcpy(fbp, back_buffer, screensize);

        usleep(16666);
    }

    free(back_buffer);
    munmap(fbp, screensize);
    close(fb_fd);
    if (mouse_fd != -1) close(mouse_fd);
    return 0;
}