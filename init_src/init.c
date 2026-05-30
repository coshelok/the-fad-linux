#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mount.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/reboot.h>
#include <sys/sysmacros.h>
#include <sys/utsname.h>
#include <fcntl.h>
#include <string.h>
#include <errno.h>
#include <stdarg.h>
#include <sys/wait.h>
#include <signal.h>

void log_info(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    printf("[INIT] ");
    vprintf(fmt, args);
    printf("\n");
    va_end(args);
}

static int mount_fs(const char *source, const char *target, const char *type, unsigned long flags, const void *data) {
    if (mount(source, target, type, flags, data) == 0) {
        log_info("Mounted %s on %s (%s)", source, target, type);
        return 0;
    }
    fprintf(stderr, "[ERROR] Failed to mount %s on %s (%s): %s\n", source, target, type, strerror(errno));
    return -1;
}

static int make_dev(const char *path, mode_t mode, int major, int minor) {
    dev_t dev = makedev(major, minor);
    if (mknod(path, mode | S_IFCHR, dev) == 0) return 0;
    if (errno == EEXIST) return 0;
    fprintf(stderr, "[ERROR] Failed to create %s: %s\n", path, strerror(errno));
    return -1;
}

int main() {
    log_info("Booting FAD Linux...");

    const char *dirs[] = {"/proc", "/sys", "/dev", "/dev/pts", "/run", "/mnt", "/bin", "/etc", "/home", "/root", "/tmp", "/var", "/cdrom"};
    for (size_t i = 0; i < sizeof(dirs) / sizeof(dirs[0]); i++) {
        if (mkdir(dirs[i], 0755) < 0 && errno != EEXIST) {
            fprintf(stderr, "[ERROR] Failed to create %s: %s\n", dirs[i], strerror(errno));
        }
    }

    mount_fs("proc", "/proc", "proc", 0, NULL);
    mount_fs("sysfs", "/sys", "sysfs", 0, NULL);
    mount_fs("devtmpfs", "/dev", "devtmpfs", 0, NULL);
    mkdir("/dev/pts", 0755);
    mount_fs("devpts", "/dev/pts", "devpts", 0, NULL);
    mount_fs("tmpfs", "/run", "tmpfs", 0, NULL);

    // Даем ядру время проснуться и инициализировать драйверы устройств
    log_info("Waiting for devices to settle...");
    sleep(1);

    make_dev("/dev/console", 0600, 5, 1);
    make_dev("/dev/tty",     0666, 5, 0);
    make_dev("/dev/null",    0666, 1, 3);
    make_dev("/dev/zero",    0666, 1, 5);
    make_dev("/dev/random",  0666, 1, 8);
    make_dev("/dev/urandom", 0666, 1, 9);
    
    make_dev("/dev/console", 0600, 5, 1);

    int fd = open("/dev/console", O_RDWR);
    if (fd >= 0) {
        dup2(fd, 0);
        dup2(fd, 1);
        dup2(fd, 2);
        if (fd > 2) close(fd);
    }

    log_info("Mounting CD-ROM...");
    if (mount_fs("/dev/sr0", "/cdrom", "iso9660", MS_RDONLY, NULL) == 0) {
        log_info("Attaching loop0 device to rootfs.ext4...");
        int loop_fd = open("/dev/loop0", O_RDONLY);
        int img_fd = open("/cdrom/rootfs.ext4", O_RDONLY);
        if (loop_fd >= 0 && img_fd >= 0) {
            if (ioctl(loop_fd, 0x4C00, img_fd) == 0) {
                log_info("Successfully linked rootfs.ext4 to /dev/loop0");
                log_info("Mounting main root filesystem...");
                mount_fs("/dev/loop0", "/mnt", "ext4", MS_RDONLY, NULL);
            } else {
                fprintf(stderr, "[ERROR] ioctl LOOP_SET_FD failed: %s\n", strerror(errno));
            }
            close(loop_fd);
            close(img_fd);
        } else {
            fprintf(stderr, "[ERROR] Couldn't open loop0 or rootfs.ext4\n");
        }
    }

    sethostname("fadlinux", strlen("fadlinux"));
    setenv("PATH", "/bin:/sbin:/mnt/bin:/mnt/sbin", 1); // Добавили пути к нашему внешнему диску
    setenv("HOME", "/root", 1);
    setenv("USER", "root", 1);
    setenv("SHELL", "/bin/sh", 0);

    log_info("System ready.");

    printf("\n  Welcome to FAD Linux\n");
    printf("  Type 'help' for available commands.\n\n");

    static char env_store[64][256];
    int env_idx = 0;

    char line[4096];
    char *args[128];

    while (1) {
        char cwd[256];
        if (getcwd(cwd, sizeof(cwd)) == NULL) snprintf(cwd, sizeof(cwd), "?");

        printf("fad:%s# ", cwd);
        fflush(stdout);
        if (fgets(line, sizeof(line), stdin) == NULL) break;

        line[strcspn(line, "\n")] = 0;

        int argc = 0;
        char *tok = strtok(line, " \t");
        while (tok && argc < 127) {
            args[argc++] = tok;
            tok = strtok(NULL, " \t");
        }
        args[argc] = NULL;

        if (argc == 0) continue;

        if (strcmp(args[0], "help") == 0) {
            printf("Built-in commands:\n");
            printf("  help              Show this message\n");
            printf("  cd [dir]          Change directory\n");
            printf("  echo [args...]    Print text\n");
            printf("  export KEY=VAL    Set environment variable\n");
            printf("  clear             Clear the screen\n");
            printf("  reboot            Reboot the system\n");
            printf("  poweroff          Power off the system\n");
            printf("\nExternal commands (in /bin):\n");
            printf("  ls, cat, mkdir, rm, pwd\n");

        } else if (strcmp(args[0], "cd") == 0) {
            const char *path = argc > 1 ? args[1] : "/";
            if (chdir(path) != 0)
                fprintf(stderr, "cd: %s: %s\n", path, strerror(errno));

        } else if (strcmp(args[0], "echo") == 0) {
            for (int i = 1; i < argc; i++) {
                printf("%s", args[i]);
                if (i < argc - 1) printf(" ");
            }
            printf("\n");

        } else if (strcmp(args[0], "export") == 0) {
            for (int i = 1; i < argc; i++) {
                if (env_idx < 64) {
                    snprintf(env_store[env_idx], sizeof(env_store[env_idx]), "%s", args[i]);
                    putenv(env_store[env_idx]);
                    env_idx++;
                }
            }

        } else if (strcmp(args[0], "reboot") == 0) {
            log_info("Rebooting system...");
            sync();
            reboot(RB_AUTOBOOT);

        } else if (strcmp(args[0], "poweroff") == 0) {
            log_info("Powering off...");
            sync();
            reboot(RB_POWER_OFF);

        } else if (strcmp(args[0], "clear") == 0) {
            printf("\033[H\033[J");

        } else {
            pid_t pid = fork();
            if (pid == 0) {
                execvp(args[0], args);
                fprintf(stderr, "fuckass-shell: command not found: %s\n", args[0]);
                _exit(127);
            } else if (pid > 0) {
                int status;
                waitpid(pid, &status, 0);
            } else {
                perror("fork failed");
            }
        }
    }

    sync();
    reboot(RB_POWER_OFF);
    return 0;
}
