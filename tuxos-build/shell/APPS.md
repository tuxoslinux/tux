# TuxOS built-in apps: plan

Apps that ship with the TuxOS desktop. Own apps are written in Qt 6 / QML
like the shell, use the shell's design tokens (one glass, white/blue,
smart symbols) and are designed one by one with mockups before they are
built. Status: full list approved by the owner 2026-11-08 (their list and
all additions below); nothing designed yet.

## Owner's list

| App | Type | Notes |
| --- | --- | --- |
| Browser | Helium, preinstalled | `helium-browser-bin` from the CachyOS repo TuxOS already uses (no AUR build; needs `udev`, which Artix has). Default browser for Super + B |
| Calculator | own | Basic, scientific, converter: currency (rates fetched online, last rates kept offline), length, area, volume, mass, temperature, speed, time, data, energy, pressure, angle, fuel use, ... Also used by "=" in the launcher |
| Settings (TuxOS Control) | own | Very extensive settings and customization; includes TuxOS' own: game mode, scheduler, CPU packages, drivers, updates, boot menu, default apps (terminal, music, messaging ...) |
| System manager | own | Task manager + system monitor in one (details below) |
| Clock | own | World clock, alarms, stopwatch, timers; running timers / stopwatch show as live activities in the bar |
| Calendar | own | Month / week / day, events, reminders |

## System manager: what it shows, and where the data comes from

Some values are not reported by every machine; the app shows them when
the hardware or driver reports them and "-" otherwise, never a guess.

- Tasks: apps and processes with CPU, RAM, GPU, disk and network use;
  sort, search; right click: end, kill, open its folder, details.
  TuxOS extras: dinit services (start / stop / restart), startup apps.
- CPU: name, one graph and % per core, clock speeds, temperature
  (hwmon/k10temp/coretemp), power in W (RAPL, through a small root
  helper), voltage only where the motherboard's sensor chip reports it
  (often not on laptops).
- RAM: usage graph, used / cached / free, swap and zram; type (DDR3/4/5,
  LPDDR4/5/5X), speed, size and model per module from SMBIOS, which needs
  root: read once at boot by a small root helper and cached.
- Disks: type (NVMe, SATA SSD, HDD, USB, microSD, eMMC), model, read /
  write graph and current speed, temperature and health (SMART), space
  used. "Rated speed" is not something drives report: the app shows the
  connection's maximum instead (e.g. PCIe 4.0 x4 = ~7.9 GB/s, SATA III =
  600 MB/s) and can run a short benchmark on request.
- Network (Wi-Fi / Ethernet): live download / upload graph, totals since
  the computer started, link speed, signal; a "Run speed test" button
  (LibreSpeed, open source; runs only when pressed).
- GPU: model, utilisation graph, VRAM, temperature, clock, fan speed and
  power where the driver reports them (AMD: all through hwmon; NVIDIA:
  through NVML, but consumer cards do not report voltage; Intel: fewer
  values). TOPS is not reported by any driver: a TuxOS table of published
  figures per model, "-" for unknown models.
- Battery (laptops): charge, health (wear), cycles, power draw.

## Additions (proposed, all approved by the owner)

Needed for an everyday desktop:
- File manager: own, already planned (Super + F); with archive support
  (zip, 7z, rar, tar) built in.
- App store and updates: one place for pacman, AUR and Flatpak apps plus
  system updates (and driver updates via tuxos-drivers). A distro needs
  this most of all.
- Welcome app: first start after install: language and keyboard check,
  wallpaper, default apps, gaming apps, privacy choices, a tour of the
  shortcuts.
- Text editor (notes and code, with syntax colours).
- Image viewer; video player (mpv underneath, TuxOS controls);
  document / PDF viewer.
- Screenshot and screen recording tool (the UI behind Super + Shift + S
  and Super + Shift + R, plus a small editor to crop and draw on shots).
- Disk utility: format USB sticks and SD cards, make a bootable USB
  from an ISO, partitions, SMART health (could live in the System
  manager).

Nice to have:
- Weather (also shown in the calendar / clock panel).
- Music player for local files (Super + V falls back to it when no
  streaming app is installed).
- Camera and sound recorder.
- Backups (scheduled copies of the home folder to another disk).
- Shortcut cheat sheet (Super + /).

Clock app note: an alarm only rings if the computer is awake. TuxOS can
wake a sleeping computer for an alarm (RTC wake-up, `rtcwake`); a computer
that is shut down cannot ring.

## Mockups v1 (2026-11-08)

`mockups/apps.html` (one app per URL hash), rendered to `mockups/apps/`:
01 Settings (Appearance), 02 Settings (Gaming), 03 System manager (CPU),
04 System manager (Overview), 05 System manager (Processes, right-click
menu), 06 Calculator (Basic + Convert), 07 Clock (Timers; the running
timer is a live activity in the bar), 08 Calendar, 09 Files, 10 Store and
updates, 11 Welcome (step 3 of 6), 12 Text editor, 13 Image viewer,
14 Video player, 15 Documents (PDF), 16 Screenshot tool (area mode),
17 Disks (bootable USB), 18 Weather, 19 Music, 20 Camera + Sound recorder,
21 Backups, 22 Shortcut cheat sheet (Super + /).
All apps share one frame: glass window, title bar with the app's smart
symbol, sidebar navigation, the same controls (toggles, segments,
sliders, cards) and the bar/dock as approved. Status: first designs,
waiting for the owner's comments.
