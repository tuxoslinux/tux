# TuxOS desktop: plan

Working name: "TuxOS desktop" (the real name is still to be chosen). Status:
planning and design; nothing is built yet. The shell's source will live in
this folder.

## Goal

A desktop of TuxOS' own, polished down to the last detail, that:

- looks and feels like TuxOS from the login screen to the desktop (black,
  yellow `#f5b800`, the Terminal-style Tux heritage), not like a theme on
  someone else's desktop;
- uses less RAM and fewer background programs than Plasma, and gets out
  of the way completely while a game runs;
- builds TuxOS' gaming features into the desktop (game mode, performance
  profile, MangoHud, drivers, updates), which no other desktop has.

What it cannot do: raise FPS. Fullscreen games bypass the desktop (direct
scanout); FPS comes from the GPU, its driver and Proton. The margins over
CachyOS come from the system layer (boot 5x faster, RAM, disk), which stays.
CachyOS already ships a Quickshell desktop (Noctalia on MangoWM), so ours has
to win on design, polish and gaming integration, not on the technology.

## Stack (decided 2026-11-07)

| Part | Choice | Why |
| --- | --- | --- |
| Compositor (draws windows, gaming behaviour) | Hyprland 0.57 (Artix `world`) | already on TuxOS, no systemd deps, Quickshell has a native Hyprland module, tearing and VRR for games, smooth animations; can run as a normal floating desktop |
| Shell (panels, launcher, popups, lock screen) | Quickshell 0.3 (Artix `galaxy`) | QML/Qt 6 toolkit made for writing shells; GPU-drawn; services for PipeWire, MPRIS, notifications, tray, UPower, PAM, greetd, Hyprland IPC |
| Login screen | greetd + `greetd-dinit` (Artix `world`) with a Quickshell greeter | one design from login to desktop; replaces SDDM for this desktop, so no Xorg left running after login (~60 MB) and no SDDM greeter hangs |
| Helpers | xdg-desktop-portal-hyprland, hyprpolkitagent, wl-clipboard, cliphist | screen sharing, password prompts, clipboard (all Artix packages) |

Layout (top bar + dock, one panel, floating bar, ...) is decided later, with
mockups.

## Rules the design follows

Design:
- One visual language for every surface: same colours, type, spacing,
  corner radius, motion and icons. Every surface designed in all its
  states (empty, loading, error, many items, long names, small and 4K
  screens, light text on photos).
- Keyboard first: everything reachable without the mouse, with one set of
  shortcuts documented in the shell itself.
- Motion explains, never decorates: short (120-250 ms), interruptible,
  and off when the user turns animations off.

Performance:
- Event-driven only: the shell reacts to Hyprland IPC, D-Bus and PipeWire
  events; no polling loops (the clock wakes once a minute).
- Nothing runs while hidden: popups and their animations are unloaded when
  closed.
- While a fullscreen game runs: no animations, notifications queue silently
  (except critical ones), VRR on; no tearing by default ("Tear-free
  games" setting, SPEC round 9), tearing only if the user allows it.

Budgets (bench VM from `bench/`, measured, not guessed):

| Metric | Target | For reference (2026-11-07) |
| --- | --- | --- |
| Idle RAM, whole session | at most TuxOS XFCE | TuxOS XFCE 604 MiB, Plasma 741 MiB, CachyOS Plasma 836 MiB |
| Shell process (quickshell) | under 150 MiB | to be measured in the prototype |
| Idle CPU wake-ups from the shell | about 1 per minute | `powertop` in the VM |
| Login (Enter) -> desktop | under 1 s | |
| Frame timer under load | not worse than Plasma | `bench-guest.sh` |

## Parts of the desktop

First version:

| Part | What it does |
| --- | --- |
| Bar / panel | workspaces, open apps, clock, tray, status (network, sound, battery), game-mode indicator |
| App launcher | apps, search, calculator, recent files, power actions |
| Notifications | pop-ups and a history panel, do-not-disturb (automatic in games) |
| Quick settings | Wi-Fi, Bluetooth, volume and output device, brightness, power profile, game mode, night light |
| On-screen displays | volume, brightness, caps lock, keyboard layout |
| Media controls | now playing (MPRIS) in the bar and quick settings |
| Lock screen | Quickshell session lock with PAM |
| Login screen | Quickshell greeter on greetd |
| Power menu | lock, log out, suspend, restart, shut down, restart into the boot menu (`tuxos-tune bootmenu`) |
| Window switcher | Alt+Tab with previews |
| Workspace overview | all workspaces and windows at once |
| Wallpaper | TuxOS wallpapers, user images |
| TuxOS Control (settings) | display, sound, network, appearance, keyboard, users, and TuxOS' own: game mode, scheduler, CPU packages, drivers, updates, mitigations, boot menu (on top of `tuxos-tune`) |

Later: gaming hub (library shortcut, per-game performance toggles, MangoHud
on/off, temperatures), screenshot and recording UI, clipboard history,
first-start welcome and tour, accessibility (large text, high contrast,
screen reader support where Qt provides it), a "Game Mode" login session
(Steam Big Picture in gamescope).

Apps are not part of the shell: terminal, file manager, editor and so on
are picked separately (to decide; ideally light and themeable to match).

## Steps (the owner checks each one before the next)

1. Design language: 2-3 visual directions as high-fidelity mockups (bar,
   launcher, quick settings, notification on one screen); the owner picks
   one or mixes them.
2. Layout: 2-3 layouts in the chosen style; the owner picks.
3. Full design: every part above in mockups, with its states, motion and
   shortcuts written down; design tokens (colours, type, spacing, radii,
   timings) fixed in one file the code uses.
4. Prototype in QEMU: Hyprland + Quickshell bar and launcher; measure RAM,
   wake-ups and frame timing against the budgets before building the rest.
5. Build the rest; QEMU desktop test; bench against TuxOS Plasma/XFCE and
   CachyOS.
6. Login and lock screen (greetd); add the desktop to the installer's
   Desktop page.
7. Real hardware: NVIDIA, AMD, Intel, laptop, multi-monitor, HiDPI, VRR;
   polish what shows up.

## Risks

- Hyprland changes its config format often: TuxOS pins a tested version
  and checks every update before it reaches users.
- Quickshell is 0.x: its API can change between releases; same rule.
- NVIDIA on Wayland: needs testing on real cards (explicit sync, VRR).
- Polish takes time: the plan has no dates; each step ends when it looks
  right, not when a date comes.

## Open decisions

- Name of the desktop.
- Layout (step 2).
- Fonts and icon set.
- Default window behaviour: floating (like Windows) with tiling on a key, or
  tiling first.
- Default apps (terminal, file manager, ...).
- Whether it becomes the default desktop and the live ISO's desktop later.

## Runs on any x86_64 PC (owner, 2026-11-08)

A hard requirement for the shell and every app, not only the owner's PC.

- CPU: any x86-64. CPUs with x86-64-v3 / v4 / Zen 4 get CachyOS'
  optimized packages; older CPUs (e.g. 2nd-gen Core i3, x86-64-v2) keep
  the generic ones (`tuxos-tune` already does this: level "generic").
- Firmware: BIOS and UEFI.
- GPU: NVIDIA new (nvidia-open, explicit sync on Wayland) and old
  (legacy driver / nouveau), AMD, Intel down to Sandy Bridge (HD 3000,
  Mesa crocus: OpenGL 3.3 / GLES 3.0), VMs with and without 3D. Hyprland's
  minimum GL needs are to be checked on the oldest GPU; if Hyprland
  cannot run on a GPU, the installer warns and offers XFCE.
- Lite mode, chosen automatically (and in Settings): on software
  rendering, very old GPUs or 4 GB RAM and less: no blur (solid glass of
  the same colours), shorter / fewer animations, no live wallpapers,
  file indexer off, local AI hidden. Same layout and features otherwise.
- RAM: comfortable on 4 GB: the whole session at idle stays near TuxOS
  XFCE's 604 MiB (budget above), heavy extras load only when used.
- Screens: from 1366 x 768 laptop panels to 4K, any refresh rate.
  Every panel scales to fit (the launcher, droplets, Mission Control and
  app windows are designed at 1080p and shrink / reflow for 768 px
  height). No VRR (e.g. 60 Hz TVs and old monitors): tear-free uses
  V-Sync; the refresh-rate check stays silent when the screen already
  runs at its highest rate.
- Input: mouse, touchpad (gestures), keyboard only, touchscreen,
  controller.

Test machines:
| Machine | What it covers |
| --- | --- |
| QEMU with virtio 3D GPU | daily development, UEFI and BIOS |
| QEMU with plain VGA (software rendering) | lite mode, no GPU |
| Owner's desktop: RTX 4080, Samsung T-series 1080p 60 Hz (2013) | new NVIDIA on Wayland, no VRR, 1080p |
| Owner's Sony Vaio: Core i3 2nd gen, Intel HD 3000, 4 GB DDR3 | minimum spec: old Intel GPU, x86-64-v2, 4 GB, laptop screen, touchpad, battery |
| AMD GPU, HiDPI / 144 Hz+ VRR screen | still needed (community testers or borrowed hardware) |
