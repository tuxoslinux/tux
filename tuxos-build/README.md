# TuxOS installer build

Builds `tuxos-<date>-x86_64.iso`: a live ISO (under 2 GB) that boots into a
COSMIC live desktop (stock look, since build9), where the TuxOS-branded
Calamares installer opens by itself, full screen ("Install TuxOS" in the
dock reopens it). It installs the build2 system (TuxOS with NetworkManager,
dinit) plus the desktop picked on the installer's "Desktop" page: KDE
Plasma, COSMIC, Hyprland, Cinnamon, Budgie, MATE, LXQt, Labwc, XFCE, i3 or
none. COSMIC and MATE come from Artix itself. Pantheon was tried for build9
and left out: Artix' gnome-session cannot start it without systemd, and
Arch's Pantheon 8 packages are broken (applications menu built for the old
panel, power indicator crashes the panel). Lingmo UI has no working Arch
packages. It is an online installer: the desktop and the
drivers are downloaded during the installation, so the installer requires
an internet connection (an empty file `profile/tuxos/offline-repo` brings
back the 1.1 GB offline repository).

The installed system runs the CachyOS kernel (`linux-cachyos`), has the
Artix `system`/`world`/`galaxy`/`lib32` repositories plus Arch `extra` and
`multilib` and CachyOS (listed last, so same-named packages come from
Artix/Arch), `yay` and fastfetch with the classic ASCII Tux. It boots
without a boot animation (no Plymouth) and without a GRUB menu, straight to
the login screen. The menu still shows when it may be needed
(`root-overlay/etc/grub.d/31_tuxos-menu`): for 5 s with another operating
system installed, for 10 s after a start that did not reach the login
screen (dinit service `tuxos-bootok` marks a good start), once after
`sudo tuxos-tune bootmenu`, and with Shift held (BIOS and UEFI firmware that
reports it; with a timeout of 0 GRUB reads no other keys). On btrfs, LVM,
RAID or encrypted /boot, where GRUB cannot save its state, it waits 1 s
hidden and Esc shows the menu. Look: black everywhere with the #f5b800 accent, the
"Terminal" GRUB theme (monospace menu, ASCII Tux), the "Terminal" login
screen (SDDM) and the "Corner glow" wallpaper (Tux kept clear of bottom
panels and of the cropping on 4:3/5:4/21:9 screens). The installer's "Drivers" page installs the best official drivers
for the detected hardware when online (`tuxos-drivers`, also usable later as
`sudo tuxos-drivers`). The "Gaming" page installs Steam, Proton-CachyOS
(native build), umu, ProtonPlus, MangoHud, gamemode and gamescope
(`tuxos-gaming`, also `sudo tuxos-gaming` later).

Performance layer (every install; `tuxos-tune status` shows it, settings in
`/etc/tuxos/performance.conf`):

- CPU-optimized packages: the installer runs `tuxos-tune setup`, which puts
  CachyOS' x86-64-v3, -v4 or Zen 4/5 repositories (whatever the CPU
  supports) between the Artix ones and Arch `extra`, and reinstalls the
  kernel and every other non-Artix package from them. Artix' own packages
  always win, so the systemd-free base is never replaced (CachyOS' `core`
  repositories are left out on purpose: they would pull in systemd).
  `pacman.conf` gets `Architecture = x86_64 x86_64_v3[ x86_64_v4]`; the mirror
  lists are generated from `cachyos-mirrorlist` (pacman hook).
- Automatic game mode (`usr/lib/tuxos/gamed`, dinit `tuxos-gamed`): while a
  Steam/Proton/umu/gamescope game runs, the "performance" power profile
  (over D-Bus; `powerprofilesctl` needs Python, which TuxOS does not ship).
  The CPU scheduler stays the kernel's BORE by default: in the benchmark
  (`../bench/REPORT.md`) BORE beat scx_lavd and scx_bpfland on a 144 Hz frame
  timer under load. `GAME_SCHEDULER=scx_lavd|scx_bpfland` switches one on
  for games (through `scx_loader`/`scxctl`).
- zram (`usr/lib/tuxos/zram-setup`, dinit `tuxos-zram`): lz4, idle pages
  recompressed with zstd every hour (cron), priority above the swap
  partition, zswap off.
- CachyOS' settings ported to dinit (sysctl, udev I/O schedulers, SATA link
  power, hdparm, audio power saving, NVIDIA runtime PM, modprobe options,
  watchdogs off, THP, ntsync, realtime limits) plus TuxOS extras: MGLRU
  `min_ttl_ms=1000`, `split_lock_mitigate=0`, SteamOS `max_map_count`, no
  proactive compaction, no watermark-boost reclaim bursts (a bigger
  free-memory reserve was tried and dropped: about 100 MiB less usable RAM,
  no measurable gain), `vm.stat_interval=10`, 16 MiB TCP
  windows, `split_lock_detect=off`, no I/O scheduler on NVMe and virtual
  disks, BBR + fq, `nowatchdog`, 10 GB shader caches, ext4
  `noatime`, weekly fstrim, power-profiles-daemon on, Bluetooth only with
  Bluetooth hardware, Plasma tearing allowed in full-screen games and file
  contents not indexed, earlyoom (CachyOS uses systemd-oomd), and on desktop
  PCs (no battery) the "performance" power profile from the first boot and
  NVMe drives without deep idle states (`DESKTOP_NVME_POWER_SAVING`). The
  hourly zram recompression and the weekly fstrim wait while a game runs.
- ananicy-cpp starts through `usr/lib/tuxos/ananicy-start`: it mounts tracefs
  (its BPF listener needs it; only systemd mounts it by itself) and removes
  a stale `/dev/shm/AnanicyCppMutex` left by a crashed run.
- Pitfall: the `nofile` hard limit must stay at or below `fs.nr_open`
  (1048576 without systemd), or pam_limits refuses every login.

```
tools/make-chroot.sh ARTIX_DINIT_ISO   # once: the build chroot ../artix-root
./build.sh      # needs sudo; adds ../out/build<N>/tuxos-<date>-<time>-x86_64.iso
BUILD_DIR=build7 ./build.sh   # redo build7 in its folder (replaces its ISO once built)
CHROOT_DIR=DIR OUT_DIR=DIR ./build.sh  # another chroot / output folder
tools/list-packages ISO > packages.txt # every package on an ISO, with versions
```

Every build gets a new folder `../out/build<N>` (the next number; nothing is
ever overwritten) with the ISO and its `.sha256`, and a row in
`../out/BUILDS.md`; record test results with
`tools/mark-build build<N>/<iso-name> "<result>"`.

| Path | What it is |
| --- | --- |
| `build.sh` | Copies the profile and the build tool into `../artix-root`, prepares the chroot's Arch/CachyOS repositories (`tools/prepare-chroot.sh`, `tools/pacman.conf.d/`), builds there, adds the ISO to `../out/build<N>/` |
| `tools/tuxos-buildiso` + `tools/lib/` | artools `buildiso` with TuxOS names (ISO file/label/metadata, GRUB files and theme from the profile) and per-profile customize hooks |
| `profile/tuxos/` | The ISO profile: `profile.yaml`, `common.yaml`, `grub/`, `root-overlay/` (installed system), `live-overlay/` (installer session), `customize-*.sh` |
| `branding/make-assets.sh` | Generates every image from `../branding/Tux.png` and installs it into the profile (run by `build.sh`); `make-designs.py` the wallpaper and GRUB backgrounds; `make-sddm-terminal.py` the login screen; `tux-ascii.txt` is the ASCII Tux of fastfetch, GRUB and the login screen (`$1` body, `$2` feet) |
| `profile/tuxos/root-overlay/usr/bin/tuxos-drivers` | Hardware detection and driver install (NVIDIA: driver series from `usr/share/tuxos/drivers/*.ids`, refreshed by `tools/update-nvidia-ids`; AMD/Intel Vulkan and video; Broadcom Wi-Fi; VM guest tools) |
| `profile/tuxos/live-overlay/usr/share/tuxos/desktop/` | Per-desktop package lists (`packages/*.list`, downloaded by the installer) and TuxOS defaults (`<desktop>/root`, `<desktop>/skel`, `common/` incl. the SDDM theme) |
| `profile/tuxos/live-overlay/usr/lib/tuxos/install-desktop` | Run by the installer: pacman keyring, desktop packages (downloaded, with a full upgrade), login screen, per-desktop setup |
| `test/` | Headless QEMU tests: `install-test.sh uefi|bios ISO`, `desktop-test.sh <desktop> ISO` (3D GPU, logs in and checks the session), `drivers-test.sh` (driver choices for 15 simulated machines). The installer fills the live desktop between COSMIC's panel and dock: `calamares.py` finds it in a screenshot and maps the tests' clicks onto it. `desktop-test.sh` with `SKIP_INSTALL=1` boots and checks the disk of an earlier run. The install test ends with an audit of the installed system (dinit services, kernel errors, pacman database and files, broken links, installer log) written to `run/<fw>-serial.log`. QEMU/KVM tests crash if a VirtualBox VM runs at the same time |

How the live ISO reaches the installer: GRUB boots "Install TuxOS" after
5 seconds (`quiet`, no boot animation) → SDDM logs the live
user `tuxos` (password `tuxos`) into COSMIC (Wayland) → the autostart entry
runs `/usr/lib/tuxos/run-installer`, which writes the Drivers page for this
computer and starts Calamares as root, full screen (through XWayland;
COSMIC opens a Calamares window only at its 1024x520 minimum size, where
the sidebar scrolls). The live session never turns the screen off or
suspends (`live-overlay/etc/skel/.config/cosmic/com.system76.CosmicIdle`,
`etc/elogind/logind.conf.d`). Only COSMIC's default wallpaper is kept on the
ISO, and the live ISO does not switch on swap partitions it finds
(artix-live does): the installer would treat that disk as in use and hide
"Erase disk". Dual boot: the installer offers "Install alongside" when it
finds another system, and the installed GRUB lists it through os-prober,
which needs `fuse3` (for `grub-mount`) on the installed system. The live initramfs leaves
out nouveau and NVIDIA's firmware (`live-overlay/etc/initcpio/install/
tuxos_no_nouveau`): they load from the live system, which keeps the ISO
small.

Test VMs create the account `tester` / `tuxtest123` (root has the same
password) on a throwaway disk.

Workarounds for upstream Artix bugs: the installed system gets a pacman
keyring (none otherwise), and `/etc/skel/.config/dinit.d/boot.d` exists so the
stock `postcfg` installer step cannot leave `~/.config` owned by root (which
stops the user's D-Bus/PipeWire services and breaks Cinnamon and XFCE).
Budgie comes from Arch `[extra]` (Budgie 10.10, Wayland on labwc); its whole
dependency tree resolves to Artix' elogind packages, and its session runs
without systemd (`budgie-session --builtin`). The installer keeps its log
on the new system (`/var/log/Calamares.log`).

Build7 debloat and boot speed (the owner chose to drop the boot animation
for speed): no Plymouth; GRUB menu for 1 s (hidden since build8); lz4 initramfs
(`etc/mkinitcpio.conf.d/20-tuxos-boot.conf`); removed packages nobody uses
on a gaming desktop (old X drivers for Voodoo/SiS/QXL/dummy, Intel's
outdated DDX, nouveau DDX, VMware mouse driver, dmraid, ecryptfs, JFS, NBD,
b43-fwcutter, dhclient, dhcpcd, haveged, s-nail, texinfo, ttf-droid, the NFS,
rsync and ntp services); no acpid (elogind handles ACPI events); metalog
instead of syslog-ng (1 MB instead of 24 MB, and syslog-ng wrote no logs
anyway); chrony keeps the clock right; Bluetooth only with Bluetooth
hardware (it used to be re-enabled by the installer's service list); gnome-keyring only on desktops other than Plasma (Plasma
has its own secret service); Plasma's global-menu proxy is off by default;
Wi-Fi power saving off (no ping spikes); tuxos-gamed ends a login screen SDDM
fails to stop after a login (about 90 MB).

NVIDIA drivers are the DKMS packages (`nvidia-open-dkms`, `nvidia-580xx-dkms`
for GTX 900/1000 cards) built for `linux-cachyos`, because CachyOS' prebuilt
modules pin an older `nvidia-utils` than Artix ships. Real NVIDIA hardware
cannot be tested in QEMU.

Still Artix underneath, on purpose: package names (`artix-*`), internal
paths/module names (`/run/artix`, `services-artix`) and the Artix mirrors.
Changing those would break updates or the live boot.
