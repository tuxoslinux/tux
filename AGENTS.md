# AGENTS.md

Instructions for AI coding agents working in `~/tuxos`.

## What this is

TuxOS is a Linux distribution built on Artix Linux (Arch without systemd)
with the dinit init system and the CachyOS kernel (`linux-cachyos`). The ISO
(kept under 2 GB) boots into a KDE Plasma live desktop where the
TuxOS-branded Calamares installer opens as a window ("Install TuxOS"). It is
an online installer: it installs the base system from the ISO, then
downloads the desktop picked on its "Desktop" page (KDE Plasma, Hyprland,
Cinnamon, Budgie, LXQt, Labwc, XFCE, i3 or none), the best drivers for the
hardware (`tuxos-drivers`) and, on its "Gaming" page, Steam and the gaming
apps (`tuxos-gaming`). Internet is required.

Performance is the main goal (a gaming distro meant to beat CachyOS): every
install gets the CachyOS packages built for its CPU (x86-64-v3/v4/Zen 4),
an automatic game mode (performance power profile while a game runs; the
kernel's BORE scheduler stays, sched-ext schedulers are an option), zram
and CachyOS' tuning ported to dinit plus extras. Benchmarks against CachyOS
live in `bench/` (`REPORT.md`, scripts, raw results; the benchmark VMs are
deleted after each run, last on 2026-11-04: rerunning needs fresh installs,
see `bench-run.sh`).
`tuxos-tune status` shows what is active; `tuxos-build/README.md` explains
each part.

Look and feel: black everywhere with the yellow accent `#f5b800`; GRUB and
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
  Claude app ("no new privileges"): the owner runs sudo commands in Konsole.

- `build.sh` needs root several times over ~5-10 minutes. There is no
  passwordless sudo: start it in the owner's terminal so they type the
  password (never type or store a password yourself).
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
- Removing a package can take away what it pulled in: `rsync-dinit` was the
  only thing installing `rsync`, which the installer's file copy (unpackfs)
  needs, so `rsync` is now listed in the rootfs packages itself. Before
  dropping a package, check what it brings in.
