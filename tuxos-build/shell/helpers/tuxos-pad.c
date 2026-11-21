/* tuxos-pad: gamepad buttons for the TuxOS shell (SPEC "Controller support":
 * the launcher, Mission Control, power menu, notifications and the Game HUD
 * work with a gamepad; the home / Steam button opens Steam Big Picture).
 * Reads every gamepad among /dev/input/event* (re-scanned when devices come
 * and go) and prints one word per press:
 *   up down left right   D-pad, or the left stick pushed past half way
 *                        (repeats while held)
 *   a b x y start select home lb rb
 * The shell runs it only while no game is running. Build:
 *   cc -O2 -Wall -o tuxos-pad tuxos-pad.c */
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <poll.h>
#include <stdio.h>
#include <string.h>
#include <sys/inotify.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

#define MAXDEV 16
#define BITS(n) (((n) + 8 * sizeof(long) - 1) / (8 * sizeof(long)))
static int test_bit(int b, const unsigned long *a) { return (a[b / (8 * sizeof(long))] >> (b % (8 * sizeof(long)))) & 1; }

struct dev { int fd; char path[300]; int absmin, absmax; int stick_x, stick_y; };
static struct dev devs[MAXDEV];
static int ndev;

static int is_gamepad(int fd) {
    unsigned long key[BITS(KEY_MAX + 1)] = {0}, abs[BITS(ABS_MAX + 1)] = {0};
    if (ioctl(fd, EVIOCGBIT(EV_KEY, sizeof key), key) < 0) return 0;
    ioctl(fd, EVIOCGBIT(EV_ABS, sizeof abs), abs);
    return test_bit(BTN_SOUTH, key) && (test_bit(ABS_X, abs) || test_bit(ABS_HAT0X, abs));
}

static void scan(void) {
    DIR *d = opendir("/dev/input");
    if (!d) return;
    struct dirent *e;
    while ((e = readdir(d)) && ndev < MAXDEV) {
        if (strncmp(e->d_name, "event", 5)) continue;
        char p[300];
        snprintf(p, sizeof p, "/dev/input/%s", e->d_name);
        int known = 0;
        for (int i = 0; i < ndev; i++) if (!strcmp(devs[i].path, p)) known = 1;
        if (known) continue;
        int fd = open(p, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
        if (fd < 0) continue;
        if (!is_gamepad(fd)) { close(fd); continue; }
        struct input_absinfo ai = {0};
        ioctl(fd, EVIOCGABS(ABS_X), &ai);
        struct dev *v = &devs[ndev++];
        memset(v, 0, sizeof *v);
        v->fd = fd;
        snprintf(v->path, sizeof v->path, "%s", p);
        v->absmin = ai.minimum; v->absmax = ai.maximum > ai.minimum ? ai.maximum : 32767;
    }
    closedir(d);
}

static void drop(int i) { close(devs[i].fd); devs[i] = devs[--ndev]; }
static void say(const char *w) { printf("%s\n", w); fflush(stdout); }
static long now_ms(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1000 + t.tv_nsec / 1000000; }

/* the stick as a direction: -1 / 0 / 1 past half way */
static int dir(struct dev *v, int val) {
    int mid = (v->absmin + v->absmax) / 2, half = (v->absmax - v->absmin) / 4;
    return val > mid + half ? 1 : val < mid - half ? -1 : 0;
}

int main(void) {
    int in = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    if (in >= 0) inotify_add_watch(in, "/dev/input", IN_CREATE | IN_ATTRIB);
    scan();
    const char *held = NULL;       /* a direction being held, for repeats */
    long next = 0;
    for (;;) {
        struct pollfd p[MAXDEV + 1];
        int n = 0;
        for (int i = 0; i < ndev; i++) p[n++] = (struct pollfd){ devs[i].fd, POLLIN, 0 };
        p[n] = (struct pollfd){ in, POLLIN, 0 };
        int timeout = held ? (int)(next - now_ms() > 0 ? next - now_ms() : 0) : -1;
        int r = poll(p, n + 1, timeout);
        if (r < 0 && errno != EINTR) return 1;
        if (held && now_ms() >= next) { say(held); next = now_ms() + 110; }
        if (in >= 0 && (p[n].revents & POLLIN)) {
            char buf[4096];
            while (read(in, buf, sizeof buf) > 0) {}
            usleep(200000);        /* udev sets the permissions a moment later */
            scan();
        }
        for (int i = n - 1; i >= 0; i--) {
            if (p[i].revents & (POLLERR | POLLHUP | POLLNVAL)) { drop(i); held = NULL; continue; }
            if (!(p[i].revents & POLLIN)) continue;
            struct input_event ev;
            struct dev *v = &devs[i];
            while (read(v->fd, &ev, sizeof ev) == sizeof ev) {
                if (ev.type == EV_KEY && ev.value == 1) {
                    switch (ev.code) {
                    case BTN_SOUTH: say("a"); break;
                    case BTN_EAST: say("b"); break;
                    case BTN_NORTH: say("x"); break;   /* kernel: NORTH = X on Xbox pads */
                    case BTN_WEST: say("y"); break;
                    case BTN_START: say("start"); break;
                    case BTN_SELECT: say("select"); break;
                    case BTN_MODE: say("home"); break;
                    case BTN_TL: say("lb"); break;
                    case BTN_TR: say("rb"); break;
                    case BTN_DPAD_UP: say("up"); break;
                    case BTN_DPAD_DOWN: say("down"); break;
                    case BTN_DPAD_LEFT: say("left"); break;
                    case BTN_DPAD_RIGHT: say("right"); break;
                    }
                } else if (ev.type == EV_ABS) {
                    const char *w = NULL;
                    int d = 0;
                    if (ev.code == ABS_HAT0X) { d = ev.value; w = d > 0 ? "right" : d < 0 ? "left" : NULL; }
                    else if (ev.code == ABS_HAT0Y) { d = ev.value; w = d > 0 ? "down" : d < 0 ? "up" : NULL; }
                    else if (ev.code == ABS_X) { d = dir(v, ev.value); if (d == v->stick_x) continue; v->stick_x = d; w = d > 0 ? "right" : d < 0 ? "left" : NULL; }
                    else if (ev.code == ABS_Y) { d = dir(v, ev.value); if (d == v->stick_y) continue; v->stick_y = d; w = d > 0 ? "down" : d < 0 ? "up" : NULL; }
                    else continue;
                    if (w) { say(w); held = w; next = now_ms() + 380; }   /* first repeat after a pause */
                    else held = NULL;
                }
            }
        }
    }
}
