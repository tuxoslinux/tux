# TuxOS desktop: agreed design (owner-approved)

Behaviour and looks the owner has approved, surface by surface. Mockups are
in `mockups/` (HTML sources and their PNG renders); the wallpaper used in
every mockup is `mockups/wallpaper.png`. See `PLAN.md` for the stack.

## Look

- White and blue, clean and minimal. Accent `#8fb8ff` (blue), text
  `#f4f7fb`, secondary text `#8b95a5`, glass `rgba(10,12,16,0.42-0.55)` with
  a 1 px light border and a strong background blur. No yellow accents in
  the shell (Tux himself keeps his yellow feet and beak).
- One glass everywhere (bar, droplet panels, login and lock card, hints):
  a strong blur of what is behind (about 34-40 px), a dark tint
  `rgba(10,12,16,0.62)` (0.42 on the login/lock card, whose background is
  already blurred and dimmed), a 1 px border `rgba(210,225,255,0.10)` and a
  faint top highlight. No per-panel variations (owner, 2026-11-08).
- UI font: Adwaita Sans (Inter-style); icons: Nerd Font symbols.

## Login screen (`login-v3`) - approved

Blurred wallpaper; one rounded glass card split in two: big clock (blue
colon) and date on the left; avatar in a blue ring, name and password field
on the right. Session choice bottom-left, sleep/restart/shut down
bottom-right.

## Lock screen (`lock-v4`) - approved

- Locks after 5 minutes without input.
- Same card as the login screen: smaller clock and date higher up; below
  them "now playing" (cover, title, artist, progress, previous / pause /
  next; hidden when nothing plays).
- Right half: a motivational note at the top, 340 x 220 px (as big as the
  news card of the rejected prototype; owner), lightning symbol top left,
  the message large and bold, "Welcome back, <name>" under it; a new
  message from a list each time it locks (e.g. "Lock in! You got this.",
  "Good day, <name>"). The password bar lower down, its bottom level with
  the now-playing card. No avatar or name.

## Password feedback (login and lock screen)

- Wrong password: the password bar shakes sideways (about 400 ms, damped),
  its outline turns red for a moment and "Try again" appears under it; the
  field is cleared and keeps focus.
- Right password (`lock-unlock-sequence`, `lock-unlock-closeup`): the bar
  shrinks into a glowing blue round lock; the shackle lifts, then swings
  open while two soft rings pulse out from it; the card and its contents
  fade and grow slightly (the lock stays bright) while the blur clears;
  then the desktop appears with the top bar sliding in. One smooth motion,
  about 800 ms in total.

## Top bar (`desktop-v1`) - approved

Floating glass bar 10 px from the top and 12 px from the sides, 46 px
high, corner radius 16 (as in the approved mockup): Tux (app launcher) and 5
virtual desktops on the left (current one a wide blue pill, used ones
white, empty ones dim); time and date in the middle; game mode, a status
group (Wi-Fi, volume, battery %) and power on the right.

Interaction:
- Hover over the virtual desktops: they highlight; the mouse wheel moves to
  the previous / next desktop (the blue pill slides, the screen slides
  with it).
- Hover over the clock: a larger square panel "drops out" of the bar like a
  droplet (connected to the bar by a liquid neck while it grows): live time
  with seconds, full date, and a one-month calendar; the mouse wheel over
  the calendar moves between months. It closes when the pointer leaves.
- Click (not hover) on the status group: a larger panel drops out the same
  way with battery, Wi-Fi (with nearby networks), Bluetooth, volume,
  brightness and power profile. Closes on a click outside or Esc.
- Both droplet panels use the shell's one glass (see Look).

## Dock (`desktop-v3-dock`) - approved

Floating glass dock at the bottom centre (14 px from the edge, same glass
as the bar): pinned and running apps as 58 px rounded squares, all one
style (light glass tile, white symbol), Trash after a thin divider. A white
dot under running apps, a short blue line under the focused one.

Icons are never the apps' own stock icons. The shell picks a symbol from
what kind of app it is, so every app matches:

1. A TuxOS table of known apps first (by desktop-file id / Wayland app id),
   e.g. Firefox, Chrome, Chromium, LibreWolf, Brave, Helium, Zen ->
   globe; Claude, ChatGPT, Codex and other AI apps -> robot; Steam, Lutris,
   Heroic, ProtonPlus -> gamepad; Discord, Telegram, Signal -> chat bubble;
   Spotify, Tidal, Deezer, YouTube Music, Strawberry, Rhythmbox, Elisa,
   Lollypop, Amberol, Audacious, Clementine, Cider, Nuclear -> music note.
2. Otherwise the desktop file's own data: `Categories` (WebBrowser,
   TerminalEmulator, FileManager, Game, Audio/Music, Video, TextEditor,
   Settings, Development, Graphics, Office, Chat ...), the `MimeType` it
   handles (`x-scheme-handler/http` = browser), and `Keywords` /
   `GenericName` (e.g. "AI", "assistant" -> robot; category Audio +
   Player, or "music player" -> music note; Video players such as mpv or
   VLC get a play button).
3. Nothing matches: the app name's first letter on the same tile.
4. The user can override any app's symbol in TuxOS Control.

The same symbols are used everywhere the shell shows an app (dock, app
launcher, window switcher, notifications).

## Window animations (`window-animations`) - approved idea

- Minimize: the window shrinks and flies into its own dock tile (narrowing
  as it goes), fading a little; the tile glows briefly when it lands.
  Restoring plays it backwards from the tile. About 300 ms.
  Hyprland has no real "minimize": TuxOS moves the window to a hidden
  special workspace (`special:minimized`) and the shell draws the flight.
- Maximize: the window grows smoothly from where it is to fill the screen
  under the bar (12 px gaps); the dock slides down out of the way while a
  window covers its area and comes back when the pointer touches the
  bottom edge. Un-maximize shrinks it back to its old place. About 250 ms.
- Both use the shell's one motion curve (fast start, soft end) and are off
  when animations are turned off.

## App launcher (Super) (`desktop-v4-lopen`, `desktop-v4-lsearch`) - draft

- Super opens it in the middle of the screen (same glass, desktop dimmed);
  Super or Esc closes it. Typing starts searching at once.
- Empty: the apps as a grid of the same one-colour tiles with names (the
  same smart symbols as the dock).
- Typing: a top result (Enter opens it), then more matches: app actions
  (e.g. "new private window"), TuxOS Control pages, files; "=" turns it
  into a calculator.
- Arrow keys move, Enter opens, Esc closes.

## Volume and brightness flyouts (`desktop-v5-osd-vol`, `desktop-v5-osd-bri`) - draft

A small droplet hangs from the status group for about 1.5 s whenever the
volume or brightness changes: the device's symbol, its name and what it is,
the level in %, and a bar. It updates while the change continues and slides
back into the bar afterwards. Muted: the bar greys out and shows "Muted".

What triggers it, so external devices work too:
- Volume: the shell watches PipeWire for any volume or mute change on the
  device sound plays through, whoever made it: keyboard volume keys,
  a headset's own wheel or buttons, a USB DAC, another app, or the status
  panel's slider. Headsets such as the Logitech G PRO X 2 LIGHTSPEED
  either send volume keys through their USB receiver or change the
  volume of their own sound device; both end up as a PipeWire change, so
  both show the flyout with that device's name. (To check on the owner's
  headset in the build phase.)
- Brightness: laptop screens through the kernel backlight (keys and
  ambient changes); external monitors through DDC/CI (`ddcutil`), so the
  brightness keys and the slider also work on desktop monitors. A monitor's
  own buttons do not tell the computer anything, so changes made there do
  not show a flyout.

## Live activities in the bar (`desktop-v6-*`) - draft

- While something plays (any MPRIS player: Spotify, browsers, mpv, ...),
  the clock and date move left and a chip appears next to them: a symbol
  (music note for audio, play triangle for video), the title, the artist
  or site, elapsed / total time, and a thin progress line along its
  bottom. Several players: the one playing last wins; the chip disappears
  when playback stops for a while.
- Hover on the chip: it expands into a droplet panel under it (same glass
  and liquid neck as the other panels).
  - Music: cover art, title, artist, the app it plays in, a seek slider
    that moves with the song (drag or click to jump), elapsed and
    remaining time, shuffle / previous / play-pause / next / repeat.
  - Video: a preview of the video, title, site and app, the same slider
    and times, previous / play-pause / next and volume. Clicking the
    preview pops the video out into picture-in-picture: a small floating,
    always-on-top window (bottom right by default, movable) with play /
    pause, the slider, volume, full screen, back to the page and close.
- Build notes: title, artist, times, cover art and seeking come from
  MPRIS. The video preview is the player's MPRIS thumbnail (YouTube
  provides one) or a live capture of the player's window
  (Hyprland screencopy). Picture-in-picture asks the player for its own
  PiP (Firefox and Chromium-based browsers have one; the shell sends their
  PiP shortcut); players without one (e.g. mpv) are turned into a small
  floating, pinned window by Hyprland instead.

## Keyboard shortcuts - approved (owner's list and all additions, 2026-11-08)

Super alone (pressed and released with no other key) opens the app
launcher; any Super + key combination never opens it.

Owner's list:

| Keys | Action |
| --- | --- |
| Super + Q | Close the current app |
| Super + W | Terminal (default kitty; choosable in Settings) |
| Super + M | Messaging app (Discord, Telegram, Viber, ...; choosable) |
| Super + R | Reload the shell |
| Super + B | Browser (default browser) |
| Super + S | Settings (TuxOS Control) |
| Super + V | Music app (Spotify, SoundCloud, ...; choosable) |
| Super + F | TuxOS file manager (to be designed) |
| Super + G | Steam Big Picture (offers to install Steam if missing) |
| Super + 1 ... 9 | Go to virtual desktop 1 ... 9 |
| Super + Shift + 1 ... 9 | Move the current window to desktop 1 ... 9 |
| Super + ` | Restart, after a 10 s countdown (see below) |
| Super + D | Do not disturb for the time set in Settings (default 3 h); again = off |
| Super + Shift + S | Screenshot: one click = the whole screen under the pointer, drag = an area; copied to the clipboard only |
| Super + C | Clipboard history (since the computer started) |

Super + ` (owner, 2026-11-08): a glass panel in the middle of the screen,
"Restarting in 10 s", with a bar that drains over the 10 seconds; Esc
cancels, Enter restarts at once (`desktop-v7-restart`).

Virtual desktops (owner, 2026-11-08): there are 9. The bar always shows
1-5; 6-9 appear in the bar only while they are in use: when the user goes
there with Super + 6 ... 9 (or moves a window there), or automatically:
once desktops 1-5 all have windows open, desktop 6 appears in the bar,
empty and ready (`desktop-v7-ws6`). An empty desktop above 5 leaves the
bar again when the user moves away from it.

Additions (proposed, all approved by the owner):

| Keys | Action |
| --- | --- |
| Super + L | Lock the screen |
| Super + Shift + Q | Force-kill an app that does not respond |
| Super + Up / Down | Maximize / restore; Down again minimizes |
| Super + Left / Right | Snap the window to the left / right half |
| Super + Enter | Full screen |
| Super + T | Float / tile the window |
| Super + Space or Super + Tab | Mission Control: every open window spread out, desktops along the top (owner, 2026-11-08) |
| Alt + Tab | Window switcher |
| Super + Ctrl + Left / Right | Previous / next desktop |
| Super + Shift + Left / Right | Move the window to the other monitor |
| Super + mouse drag / right-drag | Move / resize a window |
| Alt + Shift | Switch keyboard layout (e.g. English / Bulgarian); moved off Super + Space |
| Super + Shift + G | Game HUD on / off |
| Super + A | Quick settings (the status panel) |
| Super + N | Notification history |
| Super + . | Emoji picker |
| Super + P | Displays (mirror / extend / one screen) |
| Super + X or Ctrl + Alt + Del | Power menu (lock, log out, sleep, restart, shut down) |
| Ctrl + Shift + Esc | System monitor |
| Print | Screenshot of the whole screen to the clipboard |
| Super + Shift + R | Start / stop screen recording |
| Volume, mute, brightness, media keys | Work everywhere, with the flyouts |

While a fullscreen game runs, Super alone does not open the launcher (an
accidental press would minimize the game); Super + key shortcuts still work.

## Round 2 (owner: "add all of them", 2026-11-08) - drafts, mockups in `mockups/shell2/`

Gaps that are now designed:
- 01 Notification pop-ups: glass cards top right under the bar, app,
  time, close; reply field for chat apps, action buttons (Play,
  Library ...). Silenced by Do not disturb and focus modes.
- 02 Notification centre (Super + N): right-hand glass panel; focus modes
  at the top (Do not disturb, Work, Gaming, Sleep: each sets DND, power
  profile and night light together, by hand or on a schedule);
  notifications grouped by app; phone link card at the bottom.
- 03 Alt + Tab: live window thumbnails in a glass strip.
- 04 Mission Control (Super + Space / Super + Tab): blurred desktop,
  desktops 1-5 (+ new) along the top, all windows of the current
  desktop spread out; click to open, drag onto a desktop to move.
- 05 Power menu (Super + X): Lock, Log out, Sleep, Restart, Shut down
  (one-letter keys), Restart into the boot menu, Switch user.
- 06 Administrator password (polkit) in the shell's style: who asks and
  for what, password field, Esc cancels. Same look for the keyring.
- 07 Wi-Fi password: a droplet from the status group.
- 08 Clipboard history (Super + C): search, filters (text, images, links,
  pinned), Enter pastes; kept in RAM only, since the computer started.
- 09 Emoji picker (Super + .): search, categories, recent.
- 10 Privacy indicators: an orange pill in the bar while the microphone,
  camera or screen sharing is in use; its droplet says which app and has
  Stop.
- 11 Several live activities: the newest one shows in the bar with "+N";
  hover lists them all (screen recording, downloads, file copies,
  timers) with progress.
- 12 Multiple monitors: a bar on each screen; desktops 1-5 on the main
  screen, 6-9 on the second; refresh rate, VRR and scale per screen.

Extras that are now designed:
- 13 Game HUD (Super + Shift + G): glass overlay in the game's corner:
  FPS, 1 % / 0.1 % lows, frame-time graph, CPU / GPU load and
  temperature, VRAM, RAM, power, latency, game-mode state.
- 14 Session summary when a game closes: time played, average FPS, lows,
  hottest CPU / GPU, stutters, FPS graph; history kept in System manager.
- 15 Snap layouts: hovering a window's maximize button drops out six
  layouts; the chosen zone is previewed on the screen.
- 16 Window previews on the dock: hovering a tile raises a droplet with
  live thumbnails of that app's windows.

Agreed without a mockup:
- Session restore: apps reopen on the same desktops and positions after
  restart / login.
- Phone link: KDE Connect underneath (notifications, files, clipboard,
  ring phone), shown in the notification centre.
- Touchpad gestures: 3 fingers left / right = desktops, 3 fingers up =
  Mission Control, pinch = launcher.
- Safety net: the shell restarts itself within about a second if it
  crashes; apps keep running. A plain fallback session exists at login.
- Accessibility: reduce motion, high contrast, larger text, screen zoom,
  screen-reader labels on every control (Qt accessibility).
- UI sounds: optional, off by default (unlock, notification, screenshot).

## Round 3 (owner, 2026-11-08) - agreed, to design / build

### Everything looks like one system

- Other apps match the shell: a dark GTK 3/4 theme with the blue accent
  (adw-gtk3 base, our colours, libadwaita accent), Qt apps through a
  TuxOS Qt style (same colours, rounding, font), a kitty colour scheme,
  a Helium theme (colours + new-tab page), Steam left as is (it draws
  itself). The accent picked in Settings flows to all of them.
- Window frames: rounded corners (same radius as the shell), a soft
  shadow, a thin border that turns blue on the focused window; for apps
  that draw no title bar, a TuxOS title bar with the same minimize /
  maximize (snap layouts on hover) / close buttons (Hyprland plugin).
  Windows open by growing out of the tile or launcher entry they came
  from and close by shrinking.
- TuxOS file chooser ("Open" / "Save" dialog) and screen-share picker
  (choose a screen, a window or an area, with live previews), as our own
  xdg-desktop-portal backends, so every app uses them.
- Cursor theme (white with a dark outline, blue busy ring) and fonts
  (UI: Adwaita Sans / Inter style; mono: JetBrains Mono) shipped.
- Right-click menus, all in the shell's glass: dock (pin / unpin, new
  window, the app's own actions, move to desktop, close / close all),
  launcher (pin to dock, open in a new window, app info, uninstall),
  desktop (change wallpaper, display settings, Settings; no desktop
  icons), bar items (their settings), notifications (mute this app).

### States

- Warnings, one calm style (glass card with a coloured symbol, one clear
  action): battery 15 % and 5 % (enable power saver / hibernate), disk
  over 90 % (open Disks, empty Trash, clear caches), overheating (which
  part, how hot), update failed (what failed, retry, details), no
  internet (in the status panel, not a pop-up).
- Missing hardware hides its UI: no battery = no battery icon or panel,
  no Bluetooth = no Bluetooth tile, no Wi-Fi = Ethernet only, no
  brightness control = no brightness slider.
- Shutting down / restarting: the shell fades the desktop to black with
  "Shutting down..." / "Restarting..." and a small Tux; apps get a
  moment to close; anything that refuses is listed with "Close anyway".

### Gaming

- Games in the launcher: Steam, Heroic and Lutris libraries are read
  locally; games appear in search and in a "Games" row with their cover
  art; Enter starts the game (through its launcher).
- Controller support: the launcher, Mission Control, power menu,
  notifications and the Game HUD work with a gamepad (D-pad / stick to
  move, A open, B back); the controller's home / Steam button opens
  Steam Big Picture.
- HDR: switch per monitor in Displays (Hyprland's HDR is experimental:
  marked "beta", tested on real HDR screens before it is on by default).

### Laptops

- Battery charge limit (e.g. stop at 80 %), where the laptop supports it.
- Lid closed: lock and sleep (or nothing, when an external screen is
  attached and the laptop is plugged in).
- Keyboard backlight in the brightness flyout and quick settings.
- Fingerprint unlock on the lock screen and for admin passwords (fprintd),
  password always works too.
- Touchscreens: tap, long press = right click, the gestures above.

### Behind the scenes

- Languages: English and Bulgarian from the first version; every text
  in the shell and the apps is translatable (Qt translations); date, time
  and number formats follow the region.
- Shell updates: shell and apps ship as TuxOS packages in the TuxOS repo;
  settings are versioned and migrated on update; a broken update can be
  rolled back to the previous shell package from the safe session.
- Per-app rules in Settings: open on desktop N, always on top, start
  floating / maximized / full screen, on which monitor, opacity.

### Polish (applies everywhere)

- One motion system: spring-based, interruptible, 120-250 ms, same
  curve for every surface; "Reduce motion" swaps movement for fades.
- Adaptive glass: over a bright wallpaper or window the tint gets denser
  so text stays readable; no blur on weak / software-rendered GPUs
  ("lite" mode), solid panels instead.
- Instant feedback: every click shows a visual response within one frame;
  hover, pressed and keyboard-focus states for every control; a visible
  focus ring when using the keyboard.
- Tooltips carry the shortcut ("Files · Super + F").
- Undo instead of "Are you sure?" where possible: dismissed
  notifications, files moved to Trash, closed tabs in apps.
- Type to search everywhere: launcher, Settings, System manager,
  clipboard, emoji, file chooser.
- Sensible defaults for every surface's empty state (no notifications,
  nothing playing, empty desktop), with a small line-art Tux, never a
  blank box.
- Crisp at any scale: vector symbols, fractional scaling without blur,
  a 4 px spacing grid.
- Battery-aware: animations drop from the screen's full refresh rate to
  60 Hz on battery; nothing animates while hidden.
- Charging: plugging in shows a short glow along the battery icon and the
  time to full.
- Lock keys and mic-mute key show a small flyout (caps lock, num lock,
  mic muted).
- Screen sharing hides notification contents automatically.
- Clipboard history skips items copied from password managers and
  forgets everything at shutdown.
- Night light fades in over 30 minutes at sunset instead of switching.
- Optional rounded screen corners (for screens with square corners).

## Round 4 (owner, 2026-11-08: "add all", AI = Ollama) - agreed, to design / build

Gaming:
1. Instant replay: the last 30-60 s (setting) are kept in RAM by the GPU's
   video encoder (gpu-screen-recorder: NVENC / VAAPI, a few % at most);
   Super + Alt + R saves the clip to ~/Videos/Replays with a toast
   (open / copy / delete). On only while a game runs, by default.
2. Per-game profiles: TuxOS Control > Gaming > a game: scheduler, frame
   limit, refresh rate, VRR, HUD on / off, mic mute, Do not disturb,
   power profile; applied by game mode when that game starts.
3. FPS limiter in the Game HUD: a slider (off, 30 ... 240, or "screen
   refresh") through MangoHud's fps_limit; saved into the game's
   profile.
4. Shader pre-caching (Steam's Vulkan shader processing, DXVK / VKD3D
   caches) shown as a live activity with progress and "ready to play".
5. Boot-time card: after login a small toast "Booted in 2.7 s" (power
   on -> desktop, measured as in `bench/`), with the time of the last
   few boots on hover; can be switched off.

Everyday:
6. Command palette in the launcher: actions as results ("wifi off",
   "bluetooth on", "restart audio", "kill steam", "empty trash", "dark
   wallpaper", "game mode on", "update"), each with its own symbol.
7. Drop-down terminal: F12 slides kitty out of the bar as a droplet
   (same neck), F12 again hides it; it keeps running in between.
8. Quick notes (Super + Shift + N): a droplet with a plain note pad,
   saved automatically to ~/Notes; the text editor opens them.
9. Colour picker (Super + Shift + C): magnifier under the pointer, click
   copies the colour (HEX; RGB / HSL in the toast).
10. Text from screenshots (OCR): in the screenshot tool, "Copy text";
    tesseract with English and Bulgarian.
11. Nearby share: send files / links to phones and PCs on the same
    network (LocalSend protocol), from the file manager, the screenshot
    toast and drag onto the bar.
12. Window tabs: drag a window onto another (or Super + G ... in the
    window menu) to group them as tabs (Hyprland groups) with TuxOS tabs.

Looks:
13. Depth-effect lock screen: the clock sits behind the wallpaper's
    subject; the subject mask is made once per wallpaper on the PC (a
    small segmentation model) and can be touched up in Settings; off for
    wallpapers without a clear subject.
14. Live wallpapers (video or shader) that pause in games, in full
    screen, on battery and when the screen locks.
15. Per-desktop wallpapers and names ("Gaming", "Work" ...), shown in
    Mission Control and the bar's desktop tooltip.
16. Accent from wallpaper: optional; picks a readable accent from the
    wallpaper and passes it to the shell and all themed apps.

Smart and safe:
17. Undo update: TuxOS keeps the previous versions of updated packages;
    Settings > Updates lists each update with "Undo" (downgrade from
    the pacman cache; kernel and drivers included). ext4 has no
    snapshots, so this is per-package, not a whole-system snapshot.
18. Screen time: time per app and per game, per day / week, stored only
    on the PC (System manager > Screen time); can be switched off.
19. AI in the launcher, local only: an "Ask" mode backed by Ollama
    (installed on demand from Settings, runs as a dinit service, GPU
    accelerated when CUDA / ROCm is available, model chosen by RAM);
    off and not installed by default; nothing leaves the PC.
20. Easter eggs: line-art Tux in empty states; Konami code in the
    launcher (a small surprise, e.g. Tux waddles across the bar).

## Round 5 (owner, 2026-11-08) - agreed, to design / build

Picked from the ideas list (6, 7, 9, 10, 11, 14, 15, 16, 18 were not
chosen):

1. Headset battery in the bar: wireless headsets that HeadsetControl
   supports (e.g. the owner's Logitech G PRO X 2 LIGHTSPEED): level and
   charging state in the status group and status panel; a warning toast
   at 10 %. To check on the owner's headset in the build phase.
2. Controller battery: Xbox, DualSense / DualShock, 8BitDo and other
   controllers that report it (kernel power_supply / Bluetooth battery),
   shown while connected.
3. RGB follows the accent: keyboard, mouse, headset and case lighting
   (OpenRGB, its server started on demand) take the accent colour; off
   while the PC sleeps or the screen is locked (setting).
4. Mouse settings in Settings > Devices: DPI steps, polling rate, button
   mapping and onboard profiles for gaming mice (libratbag / ratbagd:
   Logitech, SteelSeries, Roccat ...).
5. Downloads pause while gaming: system updates, the Store's downloads
   and Steam's downloads (Steam's own setting) pause or are limited while
   a game runs; resume when it closes (setting).
8. Pin any window as picture-in-picture: window menu or Super + Alt + P
   (Super + P stays Displays): a small,
   always-on-top, resizable live copy of that window in a corner.
12. Search inside files: the launcher also finds text inside documents
    and notes in the home folder (a light index, built when the PC is
    idle and never while a game runs); can be limited to folders.
13. Tidy Downloads: optional; files in ~/Downloads older than 30 days
    (setting) move to Trash once a day, with a notification and Undo.
17. Music visualizer: a subtle bar / wave visualizer in the now-playing
    droplet and on the lock screen's now-playing card (cava, from the
    audio actually playing); stops when nothing plays.
19. Glass terminal: kitty with the shell's glass (background opacity +
    Hyprland blur behind it), the TuxOS colours and font.
20. Share your setup: export theme, accent, wallpaper, bar / dock layout
    and per-desktop names as one `.tuxtheme` file; import someone else's
    from Settings > Appearance (preview before applying).

## Round 6 (owner, 2026-11-08) - agreed, to design / build

Picked from the third ideas list (4 upscaling per game, 10 Bluetooth
codec choice, 12 slow-boot explainer, 19 Android apps were not chosen):

Gaming:
1. Refresh-rate check: when a monitor runs below its highest refresh
   rate (from its EDID modes), a card offers "Fix" (switches mode, keeps
   VRR) or "Keep"; checked after login and when a monitor is plugged in.
2. "Will it run?" badge for Steam games in the launcher and Store:
   ProtonDB rating (its public summary per app id) and anti-cheat status
   (the AreWeAntiCheatYet list); cached, refreshed daily, "unknown" when
   offline.
3. Game save backups: Ludusavi backs up saves of Steam, Heroic, Lutris
   and emulator games before each game update and once a day, into the
   backups (if set up) or ~/Games/Saves; restore per game.
5. Steam achievements as TuxOS toasts (with the achievement's icon).
   Build note: Steam only shows them in its own overlay; TuxOS would
   watch Steam's local stats files for newly unlocked ones. To verify
   before promising.
6. Driver news: when an NVIDIA driver or Mesa update arrives, a card with
   the release's game-relevant notes (fixed games, performance notes as
   written by the upstream project; TuxOS never invents numbers) and
   "Undo update" next to it.

Audio:
7. Mic noise suppression: one switch (status panel and Settings > Sound)
   adds an RNNoise filter in PipeWire for the default microphone; all
   apps get the clean mic.
8. Headphone EQ: presets from AutoEq for known headphones / headsets
   (picked automatically when the device's name matches), a manual
   10-band EQ, and per-device memory (PipeWire filter chain).
9. Per-app volume mixer in the status panel: every app playing sound with
   its own slider, mute and output device.

System care:
11. One-click cleanup in System manager: old package versions (keeping
    the ones "Undo update" needs), orphaned packages, old shader caches
    of uninstalled games, logs, Trash, thumbnails; shows the space each
    frees before cleaning.
13. Smart power: power saver below 20 % battery (setting), balanced on
    battery, performance on AC for desktops / gaming laptops (setting);
    game mode still wins while a game runs.
14. Fan curves: Quiet / Balanced / Max (and custom) for desktop boards
    whose sensor chips allow fan control (lm_sensors / fancontrol) and
    for supported laptops (nbfc-linux); hidden where unsupported.

Network:
15. Share Wi-Fi as a QR code from the status panel's network list.
16. VPN switch in quick settings (WireGuard and OpenVPN profiles through
    NetworkManager; import a .conf / .ovpn file in Settings).
17. Private DNS with ad blocking: one switch for encrypted DNS
    (DNS-over-TLS) with a blocking list; choice of provider in Settings.

Other apps:
18. Windows apps: opening an .exe offers to run it with Wine / Proton
    (umu-launcher), with a small manager for these apps (prefix per app,
    Proton version, shortcut in the launcher).
20. Distrobox: run apps from other distributions (Ubuntu, Fedora ...)
    with their launcher entries and smart symbols in TuxOS.

Setups and looks:
21. Saved setups: save the current windows (apps, desktops, monitors,
    positions) as a named setup ("Streaming", "Work") and open it again
    in one click from the launcher.
22. Quick look: Space on a file in Files (and in the file chooser) shows
    a preview (images, video, audio, PDF, text, archives' contents).
23. Seasonal Tux: Santa hat in December, pumpkin around Halloween, in the
    empty states and the login avatar; can be switched off.
24. Developer mode: one switch installs development tools (base-devel,
    git, a code editor, podman / Docker, language toolchains on demand),
    sets up an SSH key and git name / email.

## Round 7 (owner, 2026-11-08) - agreed, to design / build

Picked from the fourth ideas list (8 keep awake, 9 sleep / shut down
after, 10 webcam extras, 11 all batteries panel, 12 dock badges,
13 "what's new", 15 hardware check were not chosen):

Gaming:
1. Game streaming host: one switch in Settings > Gaming starts Sunshine
   (as a dinit user service) so Moonlight clients (phone, TV, laptop)
   can play the PC's games; pairing by PIN in the shell's style.
   Package source on Artix to check (AUR / LizardByte builds).
2. GPU tuning with LACT (AMD, NVIDIA, Intel): power limit, undervolt /
   clock offset, fan curve, with safe presets ("Quiet", "Stock",
   "Performance") and per-game profiles; changes revert if the PC does
   not boot cleanly after them.
3. Drive advisor: when a game lives on a slow drive (HDD / SATA) and a
   faster one has room, a card offers to move it (Steam's own library
   move).
4. Play-time reminders: optional, off by default; a gentle toast after
   a chosen time ("2 h played - stretch?"), never during a match
   (waits for the game to lose focus or pause).

Everyday:
5. Shortcut editor in Settings > Keyboard & shortcuts: every shortcut of
   the shell and Hyprland, rebindable, with clash warnings and "reset to
   default".
6. Screen zoom: Super + scroll zooms around the pointer (Hyprland's
   cursor zoom), Super + Esc resets.
7. Text snippets: user-defined abbreviations (";mail" -> address) that
   expand in any app; managed in Settings > Keyboard.

Trust and safety:
14. Report a problem: collects the relevant logs (shell, Hyprland,
    dinit services, kernel errors, hardware summary), shows them all for
    review, removes user names / paths where possible, and opens a
    GitHub issue on tuxoslinux/tux only after the user says so.
16. Secure Boot: a signed boot path (shim + TuxOS key; the user enrolls
    the key once in the firmware's MOK screen) so Secure Boot can stay
    on, which dual-boot users need for Windows games whose anti-cheat
    requires it. Installer flow and kernel / driver module signing to
    design and test on real UEFI firmware.
17. Disk encryption option in the installer (LUKS2), with optional TPM
    unlock (clevis in the initramfs, as TuxOS has no systemd-cryptenroll)
    so there is no extra password at boot; a recovery key is shown once.
18. Fastest mirrors automatically: Artix, Arch and CachyOS mirror lists
    are ranked by speed after install and monthly (rate-mirrors), and
    pacman downloads in parallel.

Looks:
19. Accent from album art: optional; while music plays the accent eases
    to a readable colour from the cover, back to the user's accent after.
20. Screen saver: before the screen locks, the wallpaper slowly drifts
    and darkens (no CPU / GPU use beyond a few frames per second).
21. Bar auto-hide: in full screen always, and optionally on small
    screens; it slides back when the pointer touches the top edge or on
    Super.

## Round 8 (owner, 2026-11-08) - agreed, to design / build

Picked from the final ideas list (6 smart launcher, 10 on-screen
keyboard, 14 emoji font were not chosen):

1. "While you were away" digest: when a game, Do not disturb or a focus
   mode ends, one card sums up what came in (messages per sender,
   finished downloads, updates) with "Show all"; the single
   notifications stay in the centre.
2. Long command finished: when a command in kitty runs longer than 30 s
   (setting) and kitty is not focused, a toast "Build finished ·
   4 min 12 s" with ✓ or ✗ (exit code); click focuses that kitty window
   (kitty's shell integration reports command start / end).
3. Scroll on the bar: scroll over the volume icon = volume, over the
   battery / brightness = brightness, over the clock = desktops;
   middle-click on volume = mute. Each shows its flyout.
4. Removable drives: plugging one in shows a toast "<name> <size>
   connected · Open · Eject"; Eject unmounts, waits for writes, then
   "Safe to remove ✓" (as a live activity while data is still being
   written).
5. Next event in the bar: 10 minutes before a calendar event (setting)
   it becomes a live activity ("Meeting in 10 min", then "now"), with
   the event's details on hover.
7. Low memory warning: when free memory falls under a threshold, before
   earlyoom has to act, a card names the biggest app ("Chrome is using
   9.8 GB") with Close and "Close anyway"; not during a full-screen game
   unless memory is critical.
8. Energy use per app (laptops) in System manager: estimated share of
   battery use per app over the last hours (CPU / GPU time weighted by
   the battery's power draw).
9. Magnetic window edges: while dragging, windows snap to screen edges
   and to other windows' edges (a small threshold, off with Shift held).
11. Pasting an image into Files creates a PNG in that folder, named with
    date and time.
12. No sleep during big downloads: Steam, the Store and system updates
    hold off automatic sleep while downloading; normal sleep afterwards.
13. Wallpaper per monitor (and still per desktop, as agreed earlier).

## Round 9 (owner, 2026-11-08) - agreed, to design / build

Picked from the last ideas list (7 window screenshots with shadow / GIF,
10 middle-click paste switch, 11 per-app notification settings,
13 colour profiles, 14 Tux companion were not chosen):

1. Light mode: the same shell in white frosted glass with the same
   accent; by hand, or switching at sunset / sunrise; all themed apps
   follow.
2. Launcher answers: currency and unit conversion ("100 usd to bgn"),
   time zones ("time in Tokyo"), percentages and maths, and "Search the
   web for ..." (default browser and search engine) when nothing local
   matches.
3. Events from plain text: "lunch with Alex tomorrow 13:00" in the
   launcher offers "Add to calendar" (English and Bulgarian phrases).
4. Clock droplet extras: world clocks (from the Clock app) and today's
   weather under the calendar.
5. Game launch card: while a game starts, its cover art and status
   ("Starting...", "Shaders ready") show in a glass card until the
   game's window appears.
6. VRR and tearing state in the Game HUD: whether VRR is active right
   now (and its range) and whether frames tear, so settings can be
   checked in game.
8. Drag onto the dock and the bar: drop a file on an app's tile to open
   it with that app; drop a window on a desktop number in the bar to
   move it there.
9. Find the cursor: shaking the mouse briefly enlarges the cursor; the
   cursor hides while typing and over playing video.
12. Mic test: a live input level meter in the status panel (and Settings
    > Sound) with the active microphone's name.

Tear-free games (owner's request) - Settings > Gaming, on by default:
- Hyprland never lets a game's frames tear (no immediate presentation /
  `allow_tearing` stays off for every window).
- With a VRR monitor: VRR stays on for full-screen games and game mode
  caps the frame rate a few frames under the monitor's maximum (e.g. 162
  on 165 Hz, through MangoHud's limiter) so the game stays inside the VRR
  range, where nothing tears and no extra V-Sync delay is added.
- Without VRR: frames are presented in sync with the refresh (V-Sync);
  costs a little input latency, never tears.
- Per-game override in the game's profile ("Allow tearing" for
  competitive shooters, where lowest latency matters more).
- The Game HUD shows "Tearing: off" when the setting works as intended.
