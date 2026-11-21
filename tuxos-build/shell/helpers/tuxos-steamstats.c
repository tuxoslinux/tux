/* tuxos-steamstats FILE : prints a Steam binary KeyValues file (appcache/
 * stats/UserGameStats*.bin, UserGameStatsSchema_*.bin) as "path=value"
 * lines, path parts joined with "/", for tuxos-games achievements.
 * Types: 0 nested, 1 string, 2 int32, 3 float32, 4 pointer, 5 wide string
 * (skipped), 6 colour, 7 uint64, 8 end, 10 int64.
 * Build: cc -O2 -Wall -o tuxos-steamstats tuxos-steamstats.c */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static unsigned char *buf;
static size_t len, pos;
static char path[4096];

static int cstr(const char **out) {
    size_t s = pos;
    while (pos < len && buf[pos]) pos++;
    if (pos >= len) return 0;
    *out = (const char *)buf + s;
    pos++;
    return 1;
}
static void clean(const char *s, char *o, size_t n) {        /* one line, no '=' or '/' surprises */
    size_t j = 0;
    for (size_t i = 0; s[i] && j + 1 < n; i++) o[j++] = (s[i] == '\n' || s[i] == '\r') ? ' ' : s[i];
    o[j] = 0;
}
static int walk(int depth) {
    if (depth > 64) return 0;
    while (pos < len) {
        unsigned char t = buf[pos++];
        if (t == 8 || t == 11) return 1;                     /* end of this map */
        const char *name;
        if (!cstr(&name)) return 0;
        size_t keep = strlen(path);
        char nm[512];
        clean(name, nm, sizeof nm);
        snprintf(path + keep, sizeof path - keep, "%s%s", keep ? "/" : "", nm);
        char v[2048];
        switch (t) {
        case 0: if (!walk(depth + 1)) return 0; break;
        case 1: { const char *s; if (!cstr(&s)) return 0; clean(s, v, sizeof v); printf("%s=%s\n", path, v); break; }
        case 2: case 4: case 6: { if (pos + 4 > len) return 0; int32_t x; memcpy(&x, buf + pos, 4); pos += 4; printf("%s=%d\n", path, x); break; }
        case 3: { if (pos + 4 > len) return 0; float f; memcpy(&f, buf + pos, 4); pos += 4; printf("%s=%g\n", path, f); break; }
        case 7: case 10: { if (pos + 8 > len) return 0; uint64_t x; memcpy(&x, buf + pos, 8); pos += 8; printf("%s=%llu\n", path, (unsigned long long)x); break; }
        case 5: { while (pos + 1 < len && (buf[pos] || buf[pos + 1])) pos += 2; pos += 2; break; }
        default: return 0;                                     /* not a file we know */
        }
        path[keep] = 0;
    }
    return 1;
}
int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: tuxos-steamstats FILE\n"); return 2; }
    FILE *f = fopen(argv[1], "rb");
    if (!f) return 1;
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    if (n <= 0 || n > 64L * 1024 * 1024) { fclose(f); return 1; }
    buf = malloc((size_t)n); len = fread(buf, 1, (size_t)n, f); fclose(f);
    return walk(0) ? 0 : 1;
}
