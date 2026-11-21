// tuxos-glcheck: can the compositors draw with this PC's GPU? Opens each
// GPU the way Hyprland and wlroots (cage) do, through EGL's device platform
// (GBM when that is missing), and makes an OpenGL ES 3 context, without
// touching the screen. Prints what it found; exits 0 when a GPU draws, 1
// when none does (an EGL error, or only Mesa's software renderer).
//
// Some graphics load a GPU driver that then refuses to draw, and Mesa does
// not fall back to software on that path: VirtualBox's VMSVGA without "3D
// acceleration" (vmwgfx: "VMware: No 3D enabled"), some old or broken GPUs.
// tuxos-session and tuxos-greeter run this first and, when it fails, let
// Mesa's software renderer (llvmpipe) draw everything instead.
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <fcntl.h>
#include <gbm.h>
#include <glob.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static PFNEGLGETPLATFORMDISPLAYEXTPROC get_display;

// a context on this display; 1 when a hardware renderer draws
static int try_display(EGLDisplay dpy, const char *what) {
    int ok = 0;
    EGLint major, minor;
    if (dpy == EGL_NO_DISPLAY || !eglInitialize(dpy, &major, &minor)) {
        printf("%s: EGL does not start\n", what);
        return 0;
    }
    if (eglBindAPI(EGL_OPENGL_ES_API)) {
        const EGLint attr[] = { EGL_CONTEXT_MAJOR_VERSION, 3, EGL_NONE };
        EGLContext ctx = eglCreateContext(dpy, EGL_NO_CONFIG_KHR, EGL_NO_CONTEXT, attr);
        if (ctx != EGL_NO_CONTEXT && eglMakeCurrent(dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, ctx)) {
            const char *r = (const char *)glGetString(GL_RENDERER);
            const char *v = (const char *)glGetString(GL_VERSION);
            int soft = !r || strstr(r, "llvmpipe") || strstr(r, "softpipe") || strstr(r, "Software");
            printf("%s: %s (%s)%s\n", what, r ? r : "?", v ? v : "?", soft ? " = software" : "");
            ok = !soft;
            eglMakeCurrent(dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        } else {
            printf("%s: no OpenGL ES 3 context\n", what);
        }
        if (ctx != EGL_NO_CONTEXT) eglDestroyContext(dpy, ctx);
    }
    eglTerminate(dpy);
    return ok;
}

// EGL's device platform: one EGL device per GPU (what wlroots and Hyprland use)
static int try_devices(int *found) {
    PFNEGLQUERYDEVICESEXTPROC query = (PFNEGLQUERYDEVICESEXTPROC)eglGetProcAddress("eglQueryDevicesEXT");
    PFNEGLQUERYDEVICESTRINGEXTPROC qstr = (PFNEGLQUERYDEVICESTRINGEXTPROC)eglGetProcAddress("eglQueryDeviceStringEXT");
    EGLDeviceEXT devs[16];
    EGLint n = 0;
    if (!query || !qstr || !query(16, devs, &n)) return 0;
    for (EGLint i = 0; i < n; i++) {
        const char *file = qstr(devs[i], EGL_DRM_DEVICE_FILE_EXT);
        if (!file) continue;   // Mesa's software device
        (*found)++;
        if (try_display(get_display(EGL_PLATFORM_DEVICE_EXT, devs[i], NULL), file)) return 1;
    }
    return 0;
}

// GBM on each DRM card (EGL without the device platform)
static int try_gbm(void) {
    glob_t g;
    int ok = 0;
    if (glob("/dev/dri/card[0-9]*", 0, NULL, &g) != 0) return 0;
    for (size_t i = 0; i < g.gl_pathc && !ok; i++) {
        int fd = open(g.gl_pathv[i], O_RDWR | O_CLOEXEC);
        if (fd < 0) continue;
        struct gbm_device *gbm = gbm_create_device(fd);
        if (gbm) {
            ok = try_display(get_display(EGL_PLATFORM_GBM_KHR, gbm, NULL), g.gl_pathv[i]);
            gbm_device_destroy(gbm);
        }
        close(fd);
    }
    globfree(&g);
    return ok;
}

int main(void) {
    get_display = (PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
    if (!get_display) { fprintf(stderr, "tuxos-glcheck: EGL is missing\n"); return 1; }
    int found = 0;
    int ok = try_devices(&found);
    if (!ok && !found) ok = try_gbm();
    if (!ok) fprintf(stderr, "tuxos-glcheck: no GPU draws OpenGL ES 3 here\n");
    return ok ? 0 : 1;
}
