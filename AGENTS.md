# AGENTS.md

Instructions for AI coding agents working in `~/tuxos`.

## What this is

TuxOS is a Linux distribution built on Artix Linux (Arch without systemd)
with the dinit init system and the CachyOS kernel (`linux-cachyos`). The ISO
(kept under 2 GB) boots into the TuxOS desktop (since build11; COSMIC in
build9-10): greetd logs the live user in and the TuxOS-branded Calamares
installer opens maximized ("Install TuxOS"). If Hyprland cannot start on the
graphics, the installer opens in cage instead and its Desktop page picks XFCE
(`tuxos-session`, `/usr/lib/tuxos/installer-no-hyprland`). It is an online
installer: it installs the base system from the ISO, then downloads the
desktop picked on its "Desktop" page (the TuxOS desktop, first and default;
KDE Plasma, COSMIC, Hyprland, Cinnamon, Budgie, MATE, LXQt, Labwc, XFCE, i3
or none; Pantheon and Lingmo UI were tried and left out, see
`tuxos-build/README.md`), the best drivers for the
hardware (`tuxos-drivers`) and, on its "Gaming" page, Steam and the gaming
apps (`tuxos-gaming`). Internet is required.

The TuxOS desktop is TuxOS' own: Hyprland 0.57 (Lua config) with a
Quickshell shell (bar, dock, launcher, notifications, lock and login screen,
overlays) and TuxOS' own apps (Settings, Files, Store, System manager, Music,
...), all in `tuxos-build/shell/`. Its specification is `shell/SPEC.md`
(owner's rounds of features), `shell/APPS.md`, `shell/PLAN.md`; the status of
every item is in `shell/CHECKLIST.md` (`[x]` only after a test proved it,
`[~]` built but needing the owner's hardware). Look: white / blue glass,
accent `#8fb8ff`, Tux keeps yellow feet; the default wallpaper is the owner's
mountain picture (AI-upscaled); the lock and login screens put the clock
behind the wallpaper's subject when they find one (depth effect), else the
older layout with a note.

Performance is the main goal (a gaming distro meant to beat CachyOS): every
install gets the CachyOS packages built for its CPU (x86-64-v3/v4/Zen 4),
an automatic game mode (performance power profile while a game runs; the
kernel's BORE scheduler stays, sched-ext schedulers are an option), zram
and CachyOS' tuning ported to dinit plus extras. Benchmarks against CachyOS
live in `bench/` (`REPORT.md`, scripts, raw results; the benchmark VMs are
deleted after each run, last on 2026-11-07: rerunning needs fresh installs,
see `bench-run.sh`).
`tuxos-tune status` shows what is active; `tuxos-build/README.md` explains
each part.

Look and feel of the other desktops: black everywhere with the yellow accent `#f5b800`; GRUB and
the login screen (SDDM) in the "Terminal" style with the classic ASCII Tux;
the "Corner glow" wallpaper; fastfetch with the same ASCII Tux. No boot
animation (removed in build7 at the owner's request, for boot speed) and,
since build8 (owner's choice), no GRUB menu on installed systems. It shows
by itself for dual boot, after a start that did not finish and after
`sudo tuxos-tune bootmenu`; Shift works on BIOS only in QEMU (OVMF cannot
report it). See `root-overlay/etc/grub.d/31_tuxos-menu`.

## Folder map

| Path | What it is |
| --- | --- |
| `tuxos-build/` | Everything that makes the ISO: `build.sh`, the ISO profile, artwork generators, tools, QEMU tests. Its `README.md` has the details. |
| `tuxos-build/profile/tuxos/` | The ISO profile: `root-overlay/` (installed system), `live-overlay/` (live installer session), package lists (`*.yaml`), GRUB files |
| `tuxos-build/branding/` | Artwork generators (`make-assets.sh` runs the others); `tux-ascii.txt` is the ASCII Tux (`$1` body, `$2` feet) |
| `tuxos-build/test/` | QEMU tests (see Testing) |
| `tuxos-build/shell/` | The TuxOS desktop: `src/` (Quickshell config "tuxos": shell, login screen, apps `app-*.qml`), `bin/` (tools, `tuxos-*`), `helpers/` (small C programs), `system/` (Hyprland Lua config, portal, dinit, greetd), `package.sh` (builds it into the ISO), `dev/` (dev VM tools), the spec and `CHECKLIST.md` |
| `shell-dev/shelldev.qcow2` | The dev VM for the shell (an installed TuxOS desktop, account tester); keep it |
| `artix-root/` | The Artix build chroot (root-owned). Its pacman cache speeds up builds; keep it. |
| `out/` | Finished ISOs, one folder per build (`build2/`, `build3/`, `build4/`, ...) with the ISO and its `.sha256`; `out/BUILDS.md` lists every build and its test result. `build1.iso` is the original text-only build. |
| `branding/Tux.png` | Source image of Tux (all artwork is generated from it) |
| `README.md`, `SOURCES.md`, `LICENSE` | The project README, where the source of everything on the ISO is, GPL-3.0 |
| `artix-xfce-dinit-20260813-x86_64.iso` | Original Artix ISO the chroot came from; keep it |
| `next steps (...).txt` | The owner's private notes: **never open, read, move or delete this file** |

## Building

```
cd ~/tuxos/tuxos-build && ./build.sh
```

- A new build chroot comes from `tools/make-chroot.sh ARTIX_DINIT_ISO`
  (tested 2026-11-04). sudo is refused in terminals started from the
  Claude app ("no new privileges"): the owner runs sudo commands in their
  own terminal (kitty).

- `build.sh` needs root several times over ~5-10 minutes. There is no
  passwordless sudo (never type or store a password yourself). Instead the
  owner runs `sudo ~/tuxos/tuxos-build/tools/root-helper` once in kitty
  (their login shell is fish); while it runs, `tools/asroot CMD ...` runs
  CMD as root and `tools/asroot --build [ARGS]` runs `build.sh` with its
  `sudo` calls going through the helper (`asroot --check` says whether it
  runs; exit 125 = not running: ask the owner to start it). Without the
  helper, start `build.sh` in the owner's terminal so they type the password.
- Every build goes into a new `out/build<N>/` (highest existing number + 1),
  with a row in `out/BUILDS.md`. Never overwrite or delete a build in `out/`
  unless the owner asks (to redo a build in its own folder, e.g. a fix the
  owner wants kept as build7: `BUILD_DIR=build7 ./build.sh`; the old ISO is
  replaced only once the new one is built); record test results with
  `tools/mark-build build<N>/<iso> "<result>"`.
- The build downloads current packages each time, so two builds of the same
  source can differ in package versions.

## Testing

Headless QEMU tests in `tuxos-build/test/` (account `tester` / `tuxtest123`,
root has the same password):

- The installer is a window: `calamares.py` finds it in screenshots and maps
  the clicks (written for a 1280x800 fullscreen layout) onto it.
- `install-test.sh uefi|bios ISO`: full install, then audits the installed
  system into
  `run/<fw>-serial.log` (dinit services, kernel errors, pacman, broken
  links, installer log).
- `desktop-test.sh <desktop> ISO`: installs a desktop and logs in (3D GPU;
  `GPU=none` for plain software graphics).
- `drivers-test.sh`: driver choices for 15 simulated machines (no VM).

`test/run/` (VM disks, tens of GB) and `test/shots/` are recreated by every
run; delete them when done. **QEMU/KVM tests crash if a VirtualBox VM runs on
the host at the same time** ("KVM: entry failed, hardware error 0x0"). Don't
run tests while the owner uses VirtualBox. Never touch other VMs (for example
`claude-cowork-vm`).

### The TuxOS desktop (shell) in the dev VM

- Start it: `cd tuxos-build/test && NAME=shelldev GPU=gl ./vm.sh uefi -
  ~/tuxos/shell-dev/shelldev.qcow2`, log in as tester. `SECUREBOOT=1` uses
  the Secure Boot firmware (setup mode; use an overlay disk for that).
- `shell/dev/sync.sh` copies `src/` to the VM's `~/.config/quickshell/tuxos`
  (the shell reloads; it restarts the shell when files were added or
  removed: hot reload does not see new QML files). `log.sh` shows the
  shell's log since its last reload, `as-user.sh CMD` runs a command in the
  session, `pointer.sh X Y` moves the pointer; screenshots and keys:
  `python3 -I test/qmp.py test/run/shelldev.qmp shot|keys|type|click`.
  New `bin/` tools and root files go in with `bench/qga.py ... put`.
- Apps run as `qs -p app-NAME.qml` with `QS_APP_ID=tuxos-NAME`
  (`tuxos-app NAME --page ID`); only the shell itself (no `QS_APP_ID`) may
  own process-wide things (notification server, screen time, fetching).
- Programs started outside the session (as-user.sh, qga) get no polkit
  prompt: test password prompts with `hyprctl dispatch
  "hl.dsp.exec_cmd(\"...\")"`. The polkit agent asks one request at a time.

## Working with the owner

- Plan first and say what will change; for anything visual, make options or
  screenshots and let the owner choose or confirm before applying.
- Check results yourself (screenshots, logs, the ISO's contents) before
  calling something done, and say plainly what was and was not tested.
- Clean up what you create: VM disks, extracted images, temp files.
- `~/tuxos` is a git repository whose `main` tracks GitHub
  (`tuxoslinux/tux`, public). The owner chose what GitHub gets: the OS source
  (`tuxos-build/` without `test/`, `logs/`, `branding/out/`), `LICENSE`,
  `AGENTS.md`, and `README.md` + `branding/Tux.png` as the owner keeps them
  (don't change those two unless asked). The allow-list is local, in
  `.git/info/exclude`; `bench/`, the tests, the chroot, ISOs and private
  files stay off GitHub. The ISO is shared through the gofile link in the
  README. Commit, push or publish only when asked.

## Pitfalls already hit

- Artix has no `libsystemd.so.0`; `artix-archlinux-support` only claims to
  provide it. Arch packages that link it (Budgie) need the pacman hook
  `root-overlay/etc/pacman.d/hooks/tuxos-libsystemd-compat.hook`; check new
  Arch packages with `tuxos-build/tools/scan-libsystemd`.
- GRUB only reads 8-bit RGB/RGBA PNGs and fonts from `.pf2` files in the
  theme folder; check theme changes by booting them.
- Qt sends its warnings to the journal unless `QT_FORCE_STDERR_LOGGING=1`.
- The host runs Kaspersky (`kesl`), which holds newly written files open for
  a moment; never kill it.
- `/tmp` is a small tmpfs: extract large images under `~`, then delete them.
- `pgrep -f`/`pkill -f` patterns can match your own shell command; avoid them.
- No systemd means no raised `fs.nr_open`: a `nofile` limit above 1048576 in
  `/etc/security/limits.d` makes pam_limits refuse every login.
- CachyOS' optimized repositories may only sit after the Artix ones, and
  never their `core` repositories (they would pull in systemd). Arch packages
  that depend on `lib32-systemd` (e.g. `proton-cachyos-slr`) cannot be
  installed: it conflicts with Artix' `lib32-udev`.
- `powerprofilesctl` is a Python script and TuxOS has no Python by default;
  talk to power-profiles-daemon over D-Bus (`gdbus`).
- SDDM keeps its Xorg after a login (about 60 MB; by design), and under
  dinit/elogind its greeter sometimes hangs instead of quitting: tuxos-gamed
  ends greeters whose parent is init. SDDM's Wayland greeter does not work
  here ("Failed to take control of /dev/tty1").
- `sh -c 'cmd'` replaces itself with `cmd`: a fake test process needs a
  second command (`sh -c 'sleep 60; true' ...`) to keep its arguments.
- One sysctl key the hardware lacks makes dinit's `sysctl` service fail
  (`kernel.nmi_watchdog` in KVM: "Unknown error 524"). Prefix keys that
  not every CPU/VM has with `-` in `usr/lib/sysctl.d/70-tuxos.conf`.
- Host kernel 7.3 (CachyOS) refuses the new mount API (`fsopen`) to
  processes inside a chroot; util-linux' `mount` / `umount` in the build
  chroot use it first and fail with "must be superuser" even as root
  (leftover mounts then keep the live layer "busy"). `tools/prepare-chroot.sh`
  puts wrappers in the chroot's `/usr/local/bin` that run non-setuid copies
  with `LIBMOUNT_FORCE_MOUNT2=always` (the classic `mount(2)` works).
- Removing a package can take away what it pulled in: `rsync-dinit` was the
  only thing installing `rsync`, which the installer's file copy (unpackfs)
  needs, so `rsync` is now listed in the rootfs packages itself. Before
  dropping a package, check what it brings in.
- os-prober mounts other systems with `grub-mount`, which fails silently
  without `fuse3`: GRUB then never lists Windows or another Linux. `fuse3`
  is in `common.yaml` for that.
- artix-live switches on any swap partition it finds; the installer then
  hides "Erase disk" for that disk. `customize-livefs.sh` turns that off.
- COSMIC opens Calamares (X11 or Wayland) at its minimum size; the installer
  is full screen because of that (`branding.desc`).
- Quickshell: hot reload does not register newly added QML files (restart
  the shell); `Item` already has FINAL properties (`top`, `right`, ...) and
  `SettingCard`'s default property is `rows`: don't declare them again;
  `FileView`'s child slot is its adapter (no `Connections` inside); an
  `IdleMonitor` keeps the timeout it was created with (recreate it, e.g.
  with an `Instantiator`, when the setting changes); a `FileView` watching a
  file that does not exist yet never fires.
- Quickshell singletons are created on first use: a service that must
  watch something in the background has to be touched at login
  (`Desktop.qml`'s `Component.onCompleted`, `void Service.prop`), or it
  silently does nothing (the game summary never opened). PipeWire link
  states are only known for links bound with a `PwObjectTracker`.
- The session must export `DBUS_SESSION_BUS_ADDRESS` (`tuxos-session`):
  GLib and Qt find `$XDG_RUNTIME_DIR/bus` alone, libdbus programs
  (Chromium / Helium, Electron, VLC) do not, so they had no MPRIS player.
- Hyprland 0.57 sends no event when a floating window is moved or resized:
  a non-consuming mouse-button release bind asks the shell to look again.
- QEMU in the dev VM: virtio-gpu does not come back from S3 (test sleep
  with plain VGA); `input-send-event` with `device` crashes QEMU under
  egl-headless; the USB keyboard has no media keys (add
  `QEMU_EXTRA="-device virtio-keyboard-pci"`). `shell/dev/install-system.sh`
  unpacks exactly what `package.sh` builds.
- Hyprland 0.57 Lua: `hyprctl dispatch` takes Lua (`"hl.dsp.window.fullscreen()"`);
  `float({ action = "set" })` toggles an already floating window (use
  `tux_float` in `hyprland.lua`).
- pkexec refuses to run when its parent is gone: `Quickshell.execDetached`
  double-forks, and `sh -c 'pkexec ...'` alone execs into pkexec. Use
  `["sh", "-c", "pkexec \"$@\" || exit 1", "sh", ...]` or a `Process`.
- `checkupdates` needs `fakeroot` (installed with the TuxOS desktop); the
  first update after an install changes packages that came from the ISO
  image and are not in pacman's cache: `tuxos-pkg update` rebuilds those old
  versions first so Undo can put all of them back.
- VirtualBox's default graphics (VMSVGA without 3D acceleration) load
  `vmwgfx`, whose OpenGL refuses ("VMware: No 3D enabled") without Mesa
  falling back to software on EGL's device platform, which wlroots and
  Hyprland use. `tuxos-glcheck` tests that path; the session and the
  greeter then set `GBM_ALWAYS_SOFTWARE=1 LIBGL_ALWAYS_SOFTWARE=1
  WLR_RENDERER_ALLOW_SOFTWARE=1` (wlroots refuses llvmpipe without the
  last). The screen reports 0x0 mm and Hyprland's auto scale picks 2:
  `hyprland.lua` uses 1 on such screens, set whenever the config runs (a
  monitor rule set from an event is lost on the next config reload, and the
  shell reloads it at its first start). While the session is not on screen
  (a text console in front), Hyprland cannot change modes: test monitor
  changes with the desktop in front. QEMU's `-vga vmware` is no
  stand-in (its screen freezes); test with VirtualBox itself
  (`VBoxManage`, headless, `--nat-localhostreachable1 on` to fetch files
  from the host), never together with a QEMU VM.
- `start-hyprland` exits with 0 even when Hyprland crashed at once: judge
  by how long it ran, not by the exit code.
- Secure Boot in OVMF: the `mokutil --import` request did not reach
  MokManager; "Enroll key from disk" with `EFI/TuxOS/TuxOS-key.cer` does.
  MokManager's own Reboot hangs in QEMU (reset the VM from QMP).
- LUKS: GRUB opens LUKS2 only with PBKDF2 key slots (the installer's
  `tuxoscrypt` module converts them). With /boot inside the encrypted root,
  GRUB asks for the password before the kernel, so a TPM unlock in the
  initramfs would not remove the prompt: `tuxos-tpm` makes GRUB itself ask
  the TPM (tpm2_key_protector, PCRs 0, 2, 7, Secure Boot required). Not
  PCR 4: in Linux it also holds the kernel GRUB loaded, so it never matches
  what GRUB sees. GRUB's early config has no `if`. After a firmware or
  hardware change GRUB prints a "PCR Mismatch" table before asking for the
  password (GRUB's own text). Test with `TPM=1 SECUREBOOT=1` (swtpm),
  Microsoft keys via `sbctl enroll-keys --microsoft` in the guest, and
  `QEMU_EXTRA="-netdev user,id=n2 -device e1000,netdev=n2"` to change PCR 2.
