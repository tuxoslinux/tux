/* tuxos-portal: TuxOS' file chooser for xdg-desktop-portal (SPEC: "TuxOS
 * file chooser"): apps that open or save files through the portal (Flatpak
 * apps, browsers, Electron, GTK / Qt with the portal) get TuxOS Files in
 * pick mode instead of a GTK dialog.
 *   D-Bus name   org.freedesktop.impl.portal.desktop.tuxos
 *   interface    org.freedesktop.impl.portal.FileChooser (OpenFile,
 *                SaveFile, SaveFiles)
 * Files is started with TUXOS_PICK (open / openmulti / folder / save),
 * TUXOS_PICK_TITLE, TUXOS_PICK_NAME, TUXOS_PICK_FILTER (globs, ";"),
 * TUXOS_PAGE (start folder) and TUXOS_PICK_OUT (a file it writes the chosen
 * file:// URIs to; empty = cancelled).
 * Build: cc -O2 -Wall -o tuxos-portal tuxos-portal.c $(pkg-config --cflags --libs gio-2.0) */
#include <gio/gio.h>
#include <glib/gstdio.h>
#include <string.h>
#include <unistd.h>

static const char *xml =
    "<node><interface name='org.freedesktop.impl.portal.FileChooser'>"
    "<method name='OpenFile'><arg type='o' name='handle' direction='in'/><arg type='s' name='app_id' direction='in'/>"
    "<arg type='s' name='parent_window' direction='in'/><arg type='s' name='title' direction='in'/>"
    "<arg type='a{sv}' name='options' direction='in'/><arg type='u' name='response' direction='out'/>"
    "<arg type='a{sv}' name='results' direction='out'/></method>"
    "<method name='SaveFile'><arg type='o' name='handle' direction='in'/><arg type='s' name='app_id' direction='in'/>"
    "<arg type='s' name='parent_window' direction='in'/><arg type='s' name='title' direction='in'/>"
    "<arg type='a{sv}' name='options' direction='in'/><arg type='u' name='response' direction='out'/>"
    "<arg type='a{sv}' name='results' direction='out'/></method>"
    "<method name='SaveFiles'><arg type='o' name='handle' direction='in'/><arg type='s' name='app_id' direction='in'/>"
    "<arg type='s' name='parent_window' direction='in'/><arg type='s' name='title' direction='in'/>"
    "<arg type='a{sv}' name='options' direction='in'/><arg type='u' name='response' direction='out'/>"
    "<arg type='a{sv}' name='results' direction='out'/></method>"
    "</interface></node>";

typedef struct { GDBusMethodInvocation *inv; char *out; } Job;

static char *app_file(void) {
    const char *cfg = g_get_user_config_dir();
    char *f = g_build_filename(cfg, "quickshell", "tuxos", "app-files.qml", NULL);
    if (g_file_test(f, G_FILE_TEST_EXISTS)) return f;
    g_free(f);
    return g_strdup("/etc/xdg/quickshell/tuxos/app-files.qml");
}

/* "*.png;*.jpg" from the first filter (globs; a few common mime types too) */
static char *filters(GVariant *opts) {
    GVariant *list = g_variant_lookup_value(opts, "current_filter", G_VARIANT_TYPE("(sa(us))"));
    if (!list) {
        GVariant *all = g_variant_lookup_value(opts, "filters", G_VARIANT_TYPE("a(sa(us))"));
        if (all && g_variant_n_children(all) > 0) list = g_variant_get_child_value(all, 0);
        if (all) g_variant_unref(all);
    }
    if (!list) return g_strdup("");
    GString *s = g_string_new("");
    GVariant *pats = g_variant_get_child_value(list, 1);
    for (gsize i = 0; i < g_variant_n_children(pats); i++) {
        guint32 kind; const char *p;
        g_variant_get_child(pats, i, "(u&s)", &kind, &p);
        const char *g = NULL;
        if (kind == 0) g = p;
        else if (g_str_has_prefix(p, "image/")) g = "*.png;*.jpg;*.jpeg;*.webp;*.gif;*.svg;*.avif;*.bmp";
        else if (g_str_has_prefix(p, "video/")) g = "*.mp4;*.mkv;*.webm;*.mov;*.avi";
        else if (g_str_has_prefix(p, "audio/")) g = "*.mp3;*.flac;*.ogg;*.opus;*.wav;*.m4a";
        else if (!strcmp(p, "application/pdf")) g = "*.pdf";
        else if (g_str_has_prefix(p, "text/")) g = "*.txt;*.md;*.csv;*.log;*.html";
        if (!g) { g_string_truncate(s, 0); break; }          /* a type we cannot name: show everything */
        if (s->len) g_string_append_c(s, ';');
        g_string_append(s, g);
    }
    g_variant_unref(pats); g_variant_unref(list);
    return g_string_free(s, FALSE);
}

static void finished(GObject *src, GAsyncResult *res, gpointer data) {
    Job *j = data;
    g_subprocess_wait_finish(G_SUBPROCESS(src), res, NULL);
    char *text = NULL;
    g_file_get_contents(j->out, &text, NULL, NULL);
    g_unlink(j->out);
    GVariantBuilder uris; g_variant_builder_init(&uris, G_VARIANT_TYPE("as"));
    int n = 0;
    if (text) {
        char **lines = g_strsplit(text, "\n", -1);
        for (char **l = lines; *l; l++) if (**l) { g_variant_builder_add(&uris, "s", *l); n++; }
        g_strfreev(lines);
    }
    GVariantBuilder r; g_variant_builder_init(&r, G_VARIANT_TYPE("a{sv}"));
    if (n) g_variant_builder_add(&r, "{sv}", "uris", g_variant_builder_end(&uris)); else g_variant_builder_clear(&uris);
    g_dbus_method_invocation_return_value(j->inv, g_variant_new("(u@a{sv})", n ? 0 : 1, g_variant_builder_end(&r)));
    g_free(text); g_free(j->out); g_free(j);
}

static void call(GDBusConnection *c, const char *sender, const char *path, const char *iface, const char *method,
                 GVariant *params, GDBusMethodInvocation *inv, gpointer data) {
    const char *handle, *app_id, *parent, *title; GVariant *opts;
    g_variant_get(params, "(&o&s&s&s@a{sv})", &handle, &app_id, &parent, &title, &opts);
    gboolean multiple = FALSE, directory = FALSE;
    g_variant_lookup(opts, "multiple", "b", &multiple);
    g_variant_lookup(opts, "directory", "b", &directory);
    const char *mode = !strcmp(method, "OpenFile") ? (directory ? "folder" : multiple ? "openmulti" : "open") : (!strcmp(method, "SaveFiles") ? "folder" : "save");
    const char *name = ""; g_variant_lookup(opts, "current_name", "&s", &name);
    char *folder = NULL;
    GVariant *cf = g_variant_lookup_value(opts, "current_folder", G_VARIANT_TYPE_BYTESTRING);
    if (cf) { folder = g_strdup(g_variant_get_bytestring(cf)); g_variant_unref(cf); }
    if (!folder || !*folder) { g_free(folder); folder = g_strdup(g_get_home_dir()); }
    char *globs = filters(opts);

    Job *j = g_new0(Job, 1);
    j->inv = inv;
    int fd = g_file_open_tmp("tuxos-pick-XXXXXX", &j->out, NULL);
    if (fd >= 0) close(fd);
    GSubprocessLauncher *l = g_subprocess_launcher_new(G_SUBPROCESS_FLAGS_STDOUT_SILENCE | G_SUBPROCESS_FLAGS_STDERR_SILENCE);
    g_subprocess_launcher_setenv(l, "TUXOS_PICK", mode, TRUE);
    g_subprocess_launcher_setenv(l, "TUXOS_PICK_TITLE", title, TRUE);
    g_subprocess_launcher_setenv(l, "TUXOS_PICK_NAME", name, TRUE);
    g_subprocess_launcher_setenv(l, "TUXOS_PICK_FILTER", globs, TRUE);
    g_subprocess_launcher_setenv(l, "TUXOS_PICK_OUT", j->out, TRUE);
    g_subprocess_launcher_setenv(l, "TUXOS_PAGE", folder, TRUE);
    g_subprocess_launcher_setenv(l, "QS_APP_ID", "tuxos-files", TRUE);
    char *qml = app_file();
    GSubprocess *p = g_subprocess_launcher_spawn(l, NULL, "qs", "-p", qml, NULL);
    if (p) g_subprocess_wait_async(p, NULL, finished, j);
    else g_dbus_method_invocation_return_value(inv, g_variant_new("(u@a{sv})", 2, g_variant_new_array(G_VARIANT_TYPE("{sv}"), NULL, 0)));
    g_free(qml); g_free(globs); g_free(folder); g_object_unref(l); g_variant_unref(opts);
}

static const GDBusInterfaceVTable vt = { call, NULL, NULL, { 0 } };

static void acquired(GDBusConnection *c, const char *name, gpointer data) {
    GDBusNodeInfo *info = g_dbus_node_info_new_for_xml(xml, NULL);
    g_dbus_connection_register_object(c, "/org/freedesktop/portal/desktop", info->interfaces[0], &vt, NULL, NULL, NULL);
}

int main(void) {
    GMainLoop *loop = g_main_loop_new(NULL, FALSE);
    g_bus_own_name(G_BUS_TYPE_SESSION, "org.freedesktop.impl.portal.desktop.tuxos", G_BUS_NAME_OWNER_FLAGS_NONE,
                   acquired, NULL, NULL, NULL, NULL);
    g_main_loop_run(loop);
    return 0;
}
