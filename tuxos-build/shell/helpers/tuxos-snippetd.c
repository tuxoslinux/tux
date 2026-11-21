/* tuxos-snippetd: text snippets (SPEC: ";mail" -> the address). Reads the
 * keyboards (root, dinit service) and tells the desktop's shell only that one
 * of ITS triggers was just typed; keystrokes themselves never leave this
 * program. The shell then erases the trigger and types the text (wtype).
 *   socket /run/tuxos-snippetd.sock (one client: the latest desktop user)
 *   client -> "T ;mail" adds a trigger (";" + 2-31 letters / digits),
 *             "C" clears them
 *   daemon -> "M ;mail" when it was typed
 * Letters are read by their position (US layout, like the trigger keys).
 * Build: cc -O2 -Wall -o tuxos-snippetd tuxos-snippetd.c */
#define _GNU_SOURCE
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <poll.h>
#include <stdio.h>
#include <string.h>
#include <sys/inotify.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

#define SOCK "/run/tuxos-snippetd.sock"
#define MAXDEV 24
#define MAXTRIG 200
#define BITS(n) (((n) + 8 * sizeof(long) - 1) / (8 * sizeof(long)))

static int kbd[MAXDEV], nkbd;
static char kpath[MAXDEV][300];
static char trig[MAXTRIG][33];
static int ntrig;
static char buf[40];
static int blen, shift;
static int client = -1;
static char cin[512];
static int cinlen;

static int test_bit(int b, const unsigned long *a) { return (a[b / (8 * sizeof(long))] >> (b % (8 * sizeof(long)))) & 1; }

static void scan(void) {
    DIR *d = opendir("/dev/input");
    if (!d) return;
    struct dirent *e;
    while ((e = readdir(d)) && nkbd < MAXDEV) {
        if (strncmp(e->d_name, "event", 5)) continue;
        char p[300];
        snprintf(p, sizeof p, "/dev/input/%s", e->d_name);
        int known = 0;
        for (int i = 0; i < nkbd; i++) if (!strcmp(kpath[i], p)) known = 1;
        if (known) continue;
        int fd = open(p, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
        if (fd < 0) continue;
        unsigned long key[BITS(KEY_MAX + 1)] = {0};
        ioctl(fd, EVIOCGBIT(EV_KEY, sizeof key), key);
        /* a keyboard: letters and Enter (not a mouse, a pad or a power button) */
        if (!test_bit(KEY_A, key) || !test_bit(KEY_ENTER, key) || !test_bit(KEY_SEMICOLON, key)) { close(fd); continue; }
        kbd[nkbd] = fd;
        snprintf(kpath[nkbd], sizeof kpath[nkbd], "%s", p);
        nkbd++;
    }
    closedir(d);
}

/* the character a key gives on a US layout, or 0 */
static char ch(int code) {
    static const char *row1 = "qwertyuiop", *row2 = "asdfghjkl", *row3 = "zxcvbnm";
    if (code >= KEY_Q && code <= KEY_P) return row1[code - KEY_Q];
    if (code >= KEY_A && code <= KEY_L) return row2[code - KEY_A];
    if (code >= KEY_Z && code <= KEY_M) return row3[code - KEY_Z];
    if (code >= KEY_1 && code <= KEY_9) return (char)('1' + code - KEY_1);
    if (code == KEY_0) return '0';
    if (code == KEY_SEMICOLON && !shift) return ';';
    if (code == KEY_MINUS) return '-';
    return 0;
}

static void say(const char *t) {
    if (client < 0) return;
    char m[48];
    int n = snprintf(m, sizeof m, "M %s\n", t);
    if (write(client, m, (size_t)n) != n) { close(client); client = -1; }
}

static void key(int code, int value) {
    if (code == KEY_LEFTSHIFT || code == KEY_RIGHTSHIFT) { shift = value != 0; return; }
    if (value == 0) return;                                  /* presses and repeats */
    if (code == KEY_BACKSPACE) { if (blen) buf[--blen] = 0; return; }
    char c = ch(code);
    if (!c) { blen = 0; buf[0] = 0; return; }                /* anything else breaks a trigger */
    if (blen >= (int)sizeof buf - 1) { memmove(buf, buf + 1, sizeof buf - 1); blen--; }
    buf[blen++] = shift && c >= 'a' && c <= 'z' ? (char)(c - 32) : c;
    buf[blen] = 0;
    for (int i = 0; i < ntrig; i++) {
        size_t l = strlen(trig[i]);
        if ((size_t)blen >= l && !strcmp(buf + blen - l, trig[i])) { say(trig[i]); blen = 0; buf[0] = 0; return; }
    }
}

static void command(char *line) {
    if (line[0] == 'C') { ntrig = 0; return; }
    if (line[0] != 'T' || line[1] != ' ' || ntrig >= MAXTRIG) return;
    char *t = line + 2;
    size_t l = strlen(t);
    if (l < 3 || l > 32 || t[0] != ';') return;
    for (size_t i = 1; i < l; i++) if (!((t[i] >= 'a' && t[i] <= 'z') || (t[i] >= '0' && t[i] <= '9') || t[i] == '-')) return;
    snprintf(trig[ntrig++], sizeof trig[0], "%s", t);
}

int main(void) {
    unlink(SOCK);
    int srv = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    struct sockaddr_un a = { .sun_family = AF_UNIX };
    snprintf(a.sun_path, sizeof a.sun_path, "%s", SOCK);
    if (srv < 0 || bind(srv, (struct sockaddr *)&a, sizeof a) < 0 || listen(srv, 4) < 0) { perror("tuxos-snippetd"); return 1; }
    chmod(SOCK, 0666);
    int in = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    if (in >= 0) inotify_add_watch(in, "/dev/input", IN_CREATE | IN_ATTRIB);
    scan();
    for (;;) {
        struct pollfd p[MAXDEV + 3];
        int n = 0;
        for (int i = 0; i < nkbd; i++) p[n++] = (struct pollfd){ kbd[i], POLLIN, 0 };
        int is = n; p[n++] = (struct pollfd){ srv, POLLIN, 0 };
        int ii = n; p[n++] = (struct pollfd){ in, POLLIN, 0 };
        int ic = -1; if (client >= 0) { ic = n; p[n++] = (struct pollfd){ client, POLLIN, 0 }; }
        if (poll(p, n, -1) < 0 && errno != EINTR) return 1;
        for (int i = nkbd - 1; i >= 0; i--) {
            if (p[i].revents & (POLLERR | POLLHUP | POLLNVAL)) { close(kbd[i]); kbd[i] = kbd[--nkbd]; snprintf(kpath[i], sizeof kpath[i], "%s", kpath[nkbd]); continue; }
            if (!(p[i].revents & POLLIN)) continue;
            struct input_event ev;
            while (read(kbd[i], &ev, sizeof ev) == sizeof ev) if (ev.type == EV_KEY) key(ev.code, ev.value);
        }
        if (p[is].revents & POLLIN) {
            int c = accept4(srv, NULL, NULL, SOCK_CLOEXEC | SOCK_NONBLOCK);
            if (c >= 0) {
                struct ucred cr; socklen_t cl = sizeof cr;
                /* a desktop user (not a system account); the newest one wins */
                if (getsockopt(c, SOL_SOCKET, SO_PEERCRED, &cr, &cl) == 0 && cr.uid >= 1000 && cr.uid < 60000) {
                    if (client >= 0) close(client);
                    client = c; ntrig = 0; cinlen = 0;
                } else close(c);
            }
        }
        if (p[ii].revents & POLLIN) { char b[4096]; while (read(in, b, sizeof b) > 0) {} usleep(200000); scan(); }
        if (ic >= 0 && (p[ic].revents & (POLLIN | POLLHUP))) {
            ssize_t r = read(client, cin + cinlen, sizeof cin - 1 - (size_t)cinlen);
            if (r <= 0) { if (r == 0 || errno != EAGAIN) { close(client); client = -1; ntrig = 0; } continue; }
            cinlen += (int)r; cin[cinlen] = 0;
            char *nl;
            while ((nl = strchr(cin, '\n'))) {
                *nl = 0; command(cin);
                cinlen -= (int)(nl + 1 - cin);
                memmove(cin, nl + 1, (size_t)cinlen + 1);
            }
            if (cinlen >= (int)sizeof cin - 1) cinlen = 0;
        }
    }
}
