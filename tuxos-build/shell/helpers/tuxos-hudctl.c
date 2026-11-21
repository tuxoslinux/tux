/* tuxos-hudctl: talks to MangoHud's control socket (MangoHud.conf:
 * control=mangohud, an abstract unix socket) for the TuxOS shell.
 *   tuxos-hudctl hud       show / hide the Game HUD
 *   tuxos-hudctl logging   start / stop logging
 * Exit 1 when no game with MangoHud is running. Build: cc -O2 -o tuxos-hudctl tuxos-hudctl.c */
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

int main(int argc, char **argv) {
    const char *cmd = argc > 1 ? argv[1] : "hud";
    const char *name = argc > 2 ? argv[2] : "mangohud";
    if (strcmp(cmd, "hud") && strcmp(cmd, "logging")) { fprintf(stderr, "usage: tuxos-hudctl hud|logging [socket]\n"); return 2; }
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return 1;
    struct sockaddr_un a;
    memset(&a, 0, sizeof a);
    a.sun_family = AF_UNIX;
    size_t n = strlen(name);
    if (n > sizeof a.sun_path - 2) return 2;
    memcpy(a.sun_path + 1, name, n);               /* abstract: leading NUL */
    if (connect(fd, (struct sockaddr *)&a, (socklen_t)(offsetof(struct sockaddr_un, sun_path) + 1 + n)) < 0) { close(fd); return 1; }
    char msg[64];
    int len = snprintf(msg, sizeof msg, ":%s;", cmd);
    ssize_t w = write(fd, msg, (size_t)len);
    close(fd);
    return w == len ? 0 : 1;
}
