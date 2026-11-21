-- TuxOS desktop: Hyprland configuration (Hyprland 0.57+, Lua).
-- Dev copy, used in the shell dev VM; becomes the TuxOS desktop's default.

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.env("XCURSOR_THEME", "TuxOS")                -- white, dark outline, blue busy ring
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")         -- TuxOS palette (tuxos-theme)

------------------------------------------------------------------ look
hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 12,
        border_size = 1,
        col = {
            active_border = "rgba(8fb8ffcc)",     -- the accent on the focused window
            inactive_border = "rgba(d2e1ff1a)",
        },
        resize_on_border = true,
        -- magnetic edges: floating windows snap to screen edges and to each
        -- other while dragged (hold Shift to place freely, see below)
        snap = { enabled = true, window_gap = 14, monitor_gap = 14, respect_gaps = true },
        allow_tearing = false,                     -- SPEC: tear-free games by default
        layout = "dwindle",
    },
    decoration = {
        rounding = 18,
        rounding_power = 2,
        shadow = { enabled = true, range = 24, render_power = 3, color = 0x66000000 },
        blur = {
            enabled = true,
            size = 10,
            passes = 3,
            noise = 0.01,
            brightness = 0.5,         -- adaptive glass: bright backgrounds get darkened most
            contrast = 0.9,
            vibrancy = 0.0,
            new_optimizations = true,
            xray = false,
        },
    },
    animations = { enabled = true },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        vrr = 2,                                   -- VRR for full-screen apps (games)
        focus_on_activate = true,                  -- apps (and the shell) may bring a window forward
        disable_xdg_env_checks = true,             -- TuxOS sets XDG_CURRENT_DESKTOP=TuxOS:Hyprland on purpose
    },
    ecosystem = { no_update_news = true, no_donation_nag = true },
    input = {
        kb_layout = "us,bg",
        kb_variant = ",phonetic",
        kb_options = "grp:alt_shift_toggle",       -- SPEC: Alt + Shift switches layout
        follow_mouse = 1,
        touchpad = { natural_scroll = false },
    },
    dwindle = { preserve_split = true },
    -- window tabs (Super + Alt + T): a tab group with a glass tab strip;
    -- drag another window onto the strip to add it as a tab
    group = {
        drag_into_group = 2,                       -- only when dropped on the tab strip
        merge_groups_on_drag = true,
        auto_group = true,
        col = { border_active = "rgba(8fb8ffcc)", border_inactive = "rgba(d2e1ff1a)" },
        groupbar = {
            enabled = true,
            font_family = "Adwaita Sans",
            font_size = 12,
            height = 24,
            indicator_height = 0,
            gradients = true,
            rounding = 9,
            gradient_rounding = 9,
            gaps_in = 4,
            gaps_out = 4,
            keep_upper_gap = false,
            render_titles = true,
            text_color = "rgba(0c0e13ff)",
            text_color_inactive = "rgba(e8eefaff)",
            col = { active = "rgba(8fb8ffee)", inactive = "rgba(1a1e27dd)" },
        },
    },
})

-- one motion curve, shared with the shell (fast start, soft end)
hl.curve("tux", { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })
hl.curve("tuxSpring", { type = "spring", mass = 1, stiffness = 260, damping = 26 })
hl.animation({ leaf = "global", enabled = true, speed = 6, bezier = "tux" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.5, spring = "tuxSpring" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, spring = "tuxSpring", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.5, bezier = "tux", style = "popin 85%" })
-- one motion (SPEC): everything that moves uses the spring, fades and the
-- border use the "tux" curve (the shell's Theme.bezier is the same curve)
hl.animation({ leaf = "layers", enabled = true, speed = 4, spring = "tuxSpring" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "tux" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, spring = "tuxSpring", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "tux" })

------------------------------------------------------------------ shell surfaces
-- the compositor blurs behind every TuxOS shell surface (the one glass)
hl.layer_rule({
    name = "tuxos-glass",
    match = { namespace = "^tuxos-.*" },
    blur = true,
    ignore_alpha = 0.05,
})
-- full-screen overlays (launcher, power menu, ...): their dimmed backdrop
-- stays sharp, only the glass cards on it are blurred
hl.layer_rule({
    name = "tuxos-overlay-glass",
    match = { namespace = "^tuxov-.*" },
    blur = true,
    ignore_alpha = 0.45,
})

------------------------------------------------------------------ windows
-- drop-down terminal (F12): kitty in a hidden special desktop under the bar
hl.window_rule({
    name = "tuxos-dropterm",
    match = { class = "^tuxos-dropterm$" },
    float = true,
    size = "monitor_w*0.7 monitor_h*0.45",
    move = "monitor_w*0.15 66",
    workspace = "special:dropterm silent",
})
-- TuxOS' own apps open as centred, floating glass windows
hl.window_rule({
    name = "tuxos-apps",
    match = { class = "^tuxos-(control|calculator|clock|monitor|calendar|files|editor|images|documents|welcome|weather|music|recorder|camera|backups|disks|store|sharepicker)$" },
    float = true,
    size = "monitor_w*0.8 monitor_h*0.82",
    center = true,
})
hl.window_rule({
    name = "tuxos-calculator-size",
    match = { class = "^tuxos-calculator$" },
    size = "420 640",
})
-- the installer (live ISO): maximized under the bar, so the bar's
-- Wi-Fi panel stays usable during this online install
hl.window_rule({
    name = "tuxos-installer",
    match = { class = "^(calamares|io.calamares.calamares)$" },
    maximize = true,
})
-- games may present immediately (tearing, lowest latency) - but only while
-- general.allow_tearing is on, which the shell sets just for a game whose
-- profile says "Allow tearing" (SPEC tear-free games: off by default)
hl.window_rule({
    name = "tuxos-games-tearing",
    match = { class = "^(steam_app_.*|gamescope|.*\\.exe)$" },
    immediate = true,
})
-- pinned picture-in-picture windows (browsers' own PiP, Super + Alt + P)
hl.window_rule({
    name = "tuxos-pip",
    match = { title = "^(Picture-in-Picture|Picture in picture)$" },
    float = true,
    pin = true,
    size = "480 270",
    move = "monitor_w-492 monitor_h-282",
})

------------------------------------------------------------------ several monitors
-- desktops 1-5 on the main screen (the one at 0,0), 6-9 on the second
local placed = {}
local function place_workspaces()
    local mons = hl.get_monitors() or {}
    if #mons < 2 then return end
    local main, second
    for _, m in ipairs(mons) do if m.x == 0 and m.y == 0 then main = m end end
    main = main or mons[1]
    for _, m in ipairs(mons) do if m ~= main and m.name ~= main.name then second = second or m end end
    if not second then return end
    local key = main.name .. "/" .. second.name
    if placed[key] then return end
    placed[key] = true
    for i = 1, 9 do
        local mon = (i <= 5) and main.name or second.name
        hl.workspace_rule({ workspace = tostring(i), monitor = mon, default = (i == 1 or i == 6) })
    end
end
hl.on("hyprland.start", place_workspaces)
hl.on("monitor.added", place_workspaces)

-- screens that do not report their size (virtual machines: VirtualBox's
-- 1280x800 got scale 2, too small for the installer; some projectors):
-- scale 1, unless Settings > Displays saved a rule for that screen.
-- A rule set from an event is lost when the config reloads (the shell
-- reloads it at its first start, writing theme.lua), so it is set again
-- whenever the config runs (monitors are known then on a reload), even for
-- a screen already at 1.
local function unsized_scale()
    local fh = io.open((os.getenv("HOME") or "") .. "/.config/hypr/monitors.lua", "r")
    local own = fh and fh:read("a") or ""
    if fh then fh:close() end
    for _, m in ipairs(hl.get_monitors() or {}) do
        if (m.physical_width or 0) == 0 and not own:find(m.name, 1, true) then
            hl.monitor({ output = m.name, mode = "preferred", position = "auto", scale = 1 })
        end
    end
end
unsized_scale()
hl.on("config.reloaded", unsized_scale)
hl.on("monitor.added", unsized_scale)

------------------------------------------------------------------ autostart
hl.on("hyprland.start", function()
    -- the wallpaper is drawn by the TuxOS shell (per desktop / monitor, live)
    hl.exec_cmd("hyprctl setcursor TuxOS 24")
    -- the screen locks before the PC sleeps (also on lid close)
    hl.exec_cmd("hypridle -c /usr/share/tuxos/hypridle.conf")
    hl.exec_cmd("tuxos-shell")
    -- the noise filter and the equalizer, if they were on last time
    hl.exec_cmd("tuxos-audio restore")
    -- the game streaming host, if it was on (Settings > Gaming)
    hl.exec_cmd("tuxos-stream restore")
    -- the phone link (KDE Connect), when it is installed
    hl.exec_cmd("sh -c '[ -x /usr/lib/kdeconnectd ] && exec /usr/lib/kdeconnectd'")
    -- clipboard history in RAM only, since the computer started (Super + C)
    hl.exec_cmd("wl-paste --watch cliphist -db-path $XDG_RUNTIME_DIR/tuxos-clipboard.db -max-items 500 store")
    -- the live ISO: the installer opens by itself
    if os.getenv("TUXOS_LIVE") == "1" then hl.exec_cmd("/usr/lib/tuxos/run-installer") end
end)

------------------------------------------------------------------ shortcuts (SPEC)
local super = "SUPER"
local function shell(name) return hl.dsp.global("tuxos:" .. name) end

-- Super alone (pressed and released, no other key) opens the launcher
hl.bind("SUPER + Super_L", shell("launcher-tap"), { release = true })
-- pressing Super shows an auto-hidden bar for a moment
hl.bind("SUPER + Super_L", shell("peek"), { non_consuming = true })
hl.bind("SUPER + Super_R", shell("launcher-tap"), { release = true })

-- owner's list
hl.bind(super .. " + Q", hl.dsp.window.close())
hl.bind(super .. " + W", shell("terminal"))
hl.bind(super .. " + M", shell("messaging"))
hl.bind(super .. " + R", hl.dsp.exec_cmd("qs -c tuxos ipc call shell reload"))
hl.bind(super .. " + B", shell("browser"))
hl.bind(super .. " + S", shell("settings"))
hl.bind(super .. " + V", shell("music"))
hl.bind(super .. " + F", shell("files"))
hl.bind(super .. " + G", shell("steam"))
for i = 1, 9 do
    hl.bind(super .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(super .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(super .. " + grave", shell("restart"))
hl.bind(super .. " + D", shell("dnd"))
hl.bind(super .. " + SHIFT + S", shell("screenshot"))
hl.bind(super .. " + C", shell("clipboard"))

-- additions
hl.bind(super .. " + L", shell("lock"))
hl.bind(super .. " + SHIFT + Q", hl.dsp.window.kill())
-- maximize (SPEC: grows to fill under the bar with the 12 px gaps; the dock
-- slides away because the window covers it). Hyprland's own maximize ignores
-- gaps_out, so a maximized window floats over the work area minus the gaps
-- and remembers where it was. Apps asking to be maximized (their own title
-- bar button, double-click) go the same way; asking again restores.
-- float a window: Hyprland's float "set" toggles one that already floats,
-- so the shell calls this instead (sel: "address:0x..." or nil = active)
function tux_float(sel)
    local w = sel and hl.get_window(sel) or hl.get_active_window()
    if w and not w.floating then hl.dispatch(hl.dsp.window.float({ action = "set", window = "address:" .. tostring(w.address) })) end
end
local maxed = {}            -- address -> { floating, x, y, w, h }
local gap = 12
local function wk(w) return w and tostring(w.address) or "" end
function tux_is_maxed(w) return maxed[wk(w)] ~= nil end
local function max_rect(m)
    local r, s = m.reserved, (m.scale or 1)
    local W, H = m.width / s, m.height / s
    return math.floor(m.x + r.left + gap), math.floor(m.y + r.top + gap),
           math.floor(W - r.left - r.right - 2 * gap), math.floor(H - r.top - r.bottom - 2 * gap)
end
-- after a config reload the table is empty: a floating window sitting
-- exactly on the maximized rectangle still counts as maximized
local function looks_maxed(w)
    local m = hl.get_active_monitor()
    if not w or not m or not w.floating then return false end
    local x, y, ww, hh = max_rect(m)
    return math.abs(w.at.x - x) <= 2 and math.abs(w.at.y - y) <= 2 and math.abs(w.size.x - ww) <= 2 and math.abs(w.size.y - hh) <= 2
end
function tux_maximize(w)
    w = w or hl.get_active_window()
    local m = hl.get_active_monitor()
    if not w or not m or maxed[wk(w)] or looks_maxed(w) then return end
    local r, s = m.reserved, (m.scale or 1)
    local W, H = m.width / s, m.height / s
    maxed[wk(w)] = { floating = w.floating, x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y }
    local sel = "address:" .. wk(w)
    if not w.floating then hl.dispatch(hl.dsp.window.float({ action = "set", window = sel })) end
    hl.dispatch(hl.dsp.window.resize({ x = math.floor(W - r.left - r.right - 2 * gap), y = math.floor(H - r.top - r.bottom - 2 * gap), exact = true, window = sel }))
    hl.dispatch(hl.dsp.window.move({ x = math.floor(m.x + r.left + gap), y = math.floor(m.y + r.top + gap), exact = true, window = sel }))
    hl.dispatch(hl.dsp.global("tuxos:geometry"))
end
function tux_restore(w)
    w = w or hl.get_active_window()
    local o = w and maxed[wk(w)]
    if not o and looks_maxed(w) then
        -- maximized before a reload: back to a centred window two thirds the size
        local x, y, ww, hh = max_rect(hl.get_active_monitor())
        o = { floating = true, w = math.floor(ww * 2 / 3), h = math.floor(hh * 2 / 3) }
        o.x, o.y = math.floor(x + (ww - o.w) / 2), math.floor(y + (hh - o.h) / 2)
    end
    if not o then return false end
    maxed[wk(w)] = nil
    local sel = "address:" .. wk(w)
    if o.floating then
        hl.dispatch(hl.dsp.window.resize({ x = o.w, y = o.h, exact = true, window = sel }))
        hl.dispatch(hl.dsp.window.move({ x = o.x, y = o.y, exact = true, window = sel }))
    else
        hl.dispatch(hl.dsp.window.float({ action = "unset", window = sel }))
    end
    hl.dispatch(hl.dsp.global("tuxos:geometry"))
    return true
end
function tux_toggle_max(w)
    w = w or hl.get_active_window()
    if not w then return end
    if not tux_restore(w) then tux_maximize(w) end
end
-- an app (or the shell's own title bars) asked for Hyprland's maximize:
-- turn it into the gapped one
hl.on("window.fullscreen", function(w)
    if not w or w.fullscreen ~= 1 then return end
    hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "unset", window = "address:" .. wk(w) }))
    tux_toggle_max(w)
end)
hl.on("window.close", function(w) if w then maxed[wk(w)] = nil end end)
-- maximize (a named function: Settings > Keyboard can bind it to other keys)
function tux_key_up()
    local w = hl.get_active_window()
    if w and w.fullscreen == 0 then tux_maximize(w) end
end
hl.bind(super .. " + up", tux_key_up)
-- restore, or minimize (a named function: Settings > Keyboard can bind it to other keys)
function tux_key_down()
    local w = hl.get_active_window()
    if not w then return end
    if w.fullscreen ~= 0 then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "unset" }))
    elseif tux_restore(w) then
        return
    else
        -- minimize: the shell flies the window into its dock tile and keeps
        -- it on the hidden special desktop "minimized"
        hl.dispatch(hl.dsp.global("tuxos:minimize"))
    end
end
hl.bind(super .. " + down", tux_key_down)
-- snap / tile to the left (a named function: Settings > Keyboard can bind it to other keys)
function tux_key_left()
    local w = hl.get_active_window()
    if w and w.floating then hl.dispatch(hl.dsp.window.float({ action = "unset" })) end
    hl.dispatch(hl.dsp.window.move({ direction = "left" }))
end
hl.bind(super .. " + left", tux_key_left)
-- snap / tile to the right (a named function: Settings > Keyboard can bind it to other keys)
function tux_key_right()
    local w = hl.get_active_window()
    if w and w.floating then hl.dispatch(hl.dsp.window.float({ action = "unset" })) end
    hl.dispatch(hl.dsp.window.move({ direction = "right" }))
end
hl.bind(super .. " + right", tux_key_right)
hl.bind(super .. " + Return", hl.dsp.window.fullscreen())
-- float / tile (a named function: Settings > Keyboard can bind it to other
-- keys). Hyprland gives a window it floats its last floating size, which can
-- be the maximized one or reach off the screen: such a window becomes two
-- thirds of the work area, centred.
function tux_key_float()
    local w = hl.get_active_window()
    if not w then return end
    local sel = "address:" .. wk(w)
    if w.floating then
        maxed[wk(w)] = nil
        hl.dispatch(hl.dsp.window.float({ action = "unset", window = sel }))
        return
    end
    hl.dispatch(hl.dsp.window.float({ action = "set", window = sel }))
    local m = hl.get_active_monitor()
    w = hl.get_window(sel)
    if not m or not w then return end
    local x, y, ww, hh = max_rect(m)
    if w.at.x < x or w.at.y < y or w.at.x + w.size.x > x + ww or w.at.y + w.size.y > y + hh
       or (math.abs(w.size.x - ww) <= 2 and math.abs(w.size.y - hh) <= 2) then
        local nw, nh = math.floor(ww * 2 / 3), math.floor(hh * 2 / 3)
        hl.dispatch(hl.dsp.window.resize({ x = nw, y = nh, exact = true, window = sel }))
        hl.dispatch(hl.dsp.window.move({ x = math.floor(x + (ww - nw) / 2), y = math.floor(y + (hh - nh) / 2), exact = true, window = sel }))
    end
end
hl.bind(super .. " + T", tux_key_float)
hl.bind(super .. " + Z", shell("snap"))                -- snap layouts
hl.bind(super .. " + space", shell("mission"))
hl.bind(super .. " + Tab", shell("mission"))
hl.bind("ALT + Tab", shell("switcher"))
hl.bind("ALT + SHIFT + Tab", shell("switcher-back"))
hl.bind(super .. " + CTRL + left", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(super .. " + CTRL + right", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(super .. " + SHIFT + left", hl.dsp.window.move({ monitor = "-1" }))
hl.bind(super .. " + SHIFT + right", hl.dsp.window.move({ monitor = "+1" }))
hl.bind(super .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
-- the drag ended: the shell checks whether it was let go on a desktop number
hl.bind(super .. " + mouse:272", hl.dsp.global("tuxos:dropped"), { drag = true, non_consuming = true })
hl.bind(super .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
-- the dock hides only behind windows that reach its area, but Hyprland sends
-- no event when a floating window was moved or resized (Super + drag, its
-- title bar or edges): a button released on a floating window asks the
-- shell to look again
function tux_floating_released()
    local w = hl.get_active_window()
    if w and w.floating then hl.dispatch(hl.dsp.global("tuxos:geometry")) end
end
hl.bind("mouse:272", tux_floating_released, { release = true, non_consuming = true, ignore_mods = true })
hl.bind("mouse:273", tux_floating_released, { release = true, non_consuming = true, ignore_mods = true })
hl.bind(super .. " + SHIFT + G", shell("hud"))
hl.bind(super .. " + A", shell("quick"))
hl.bind(super .. " + N", shell("centre"))
hl.bind(super .. " + period", shell("emoji"))
hl.bind(super .. " + P", shell("displays"))
hl.bind(super .. " + X", shell("power"))
hl.bind("CTRL + ALT + Delete", shell("power"))
-- the PC's power key: the power menu (elogind leaves it to the desktop)
hl.bind("XF86PowerOff", shell("power"))
hl.bind("CTRL + SHIFT + Escape", shell("monitor"))
hl.bind("Print", shell("screenshot-full"))
hl.bind(super .. " + SHIFT + R", shell("record"))
hl.bind(super .. " + ALT + R", shell("replay"))
local pip_before = {}       -- address -> how the window was before it was pinned
-- pin as picture in picture (a named function: Settings > Keyboard can bind it to other keys)
function tux_key_pip()
    -- pin the window as picture in picture: small, floating, on top, bottom right
    local w = hl.get_active_window()
    if not w then return end
    if w.pinned then
        hl.dispatch(hl.dsp.window.pin())
        -- back to how it was before (floating where it was, or tiled)
        local o = pip_before[wk(w)]
        pip_before[wk(w)] = nil
        if o and o.floating then
            hl.dispatch(hl.dsp.window.resize({ x = o.w, y = o.h, exact = true }))
            hl.dispatch(hl.dsp.window.move({ x = o.x, y = o.y, exact = true }))
        else
            hl.dispatch(hl.dsp.window.float({ action = "unset" }))
        end
    else
        pip_before[wk(w)] = { floating = w.floating, x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y }
        -- (float "set" toggles a window that already floats)
        if not w.floating then hl.dispatch(hl.dsp.window.float({ action = "set" })) end
        hl.dispatch(hl.dsp.window.resize({ x = 480, y = 270, exact = true }))
        local m = hl.get_active_monitor()
        if m then
            local s = m.scale or 1
            hl.dispatch(hl.dsp.window.move({ x = math.floor(m.x + m.width / s - 492), y = math.floor(m.y + m.height / s - 282), exact = true }))
        end
        hl.dispatch(hl.dsp.window.pin())
    end
end
hl.bind(super .. " + ALT + P", tux_key_pip)
-- window tabs
hl.bind(super .. " + ALT + T", hl.dsp.group.toggle())
hl.bind(super .. " + ALT + right", hl.dsp.group.next())
hl.bind(super .. " + ALT + left", hl.dsp.group.prev())
-- Shift held while dragging a window turns the magnetic edges off
hl.bind("Shift_L", function() hl.config({ general = { snap = { enabled = false } } }) end, { non_consuming = true, ignore_mods = true })
hl.bind("Shift_L", function() hl.config({ general = { snap = { enabled = true } } }) end, { non_consuming = true, ignore_mods = true, release = true })
hl.bind(super .. " + SHIFT + N", shell("notes"))
hl.bind(super .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a -f hex"))
-- drop-down terminal (a named function: Settings > Keyboard can bind it to other keys)
function tux_key_dropterm()
    if #hl.get_windows({ class = "^tuxos-dropterm$" }) == 0 then
        hl.exec_cmd("kitty --class tuxos-dropterm")
    end
    hl.dispatch(hl.dsp.workspace.toggle_special("dropterm"))
end
hl.bind("F12", tux_key_dropterm)
hl.bind(super .. " + slash", shell("sheet"))
-- screen zoom
local function zoom(f)
    return function()
        local z = hl.get_config("cursor.zoom_factor") or 1
        z = (f == 0) and 1 or math.max(1, math.min(8, z * f))
        hl.config({ cursor = { zoom_factor = z } })
    end
end
tux_zoom_in, tux_zoom_out, tux_zoom_reset = zoom(1.25), zoom(0.8), zoom(0)
-- (mouse_up = the wheel turned away from you: bigger, as in browsers)
hl.bind(super .. " + mouse_up", tux_zoom_in)
hl.bind(super .. " + mouse_down", tux_zoom_out)
hl.bind(super .. " + Escape", tux_zoom_reset)

-- hardware keys work everywhere (also on the lock screen), with flyouts
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("tuxos-brightness up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("tuxos-brightness down"), { locked = true, repeating = true })
-- Caps Lock / Num Lock flyouts (the key itself still works)
hl.bind("Caps_Lock", shell("locks"), { non_consuming = true, ignore_mods = true })
hl.bind("Num_Lock", shell("locks"), { non_consuming = true, ignore_mods = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

------------------------------------------------------------------ touchpad gestures
-- 3 fingers left / right: previous / next desktop; 3 fingers up: Mission
-- Control; pinch in (3 or 4 fingers): the app launcher
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "up", action = function() hl.dispatch(hl.dsp.global("tuxos:mission")) end })
hl.gesture({ fingers = 3, direction = "pinchin", action = function() hl.dispatch(hl.dsp.global("tuxos:launcher")) end })
hl.gesture({ fingers = 4, direction = "pinchin", action = function() hl.dispatch(hl.dsp.global("tuxos:launcher")) end })

------------------------------------------------------------------ the cursor
-- hidden while typing (it comes back on the next move); shake the mouse to
-- find it: it grows for a moment. Settings > Mouse & touchpad turns both
-- off (mouse.lua sets tux_shake / cursor.hide_on_key_press).
hl.config({ cursor = { hide_on_key_press = true } })
tux_shake = true
tux_cursor_size = 24
do
    local last, dir, flips, tick, big_until, idle = nil, 0, {}, 0, 0, 0
    local fast = true
    local t
    local function step()
        tick = tick + 1
        if not tux_shake then return end
        local p = hl.get_cursor_pos()
        if not p then return end
        if last then
            local dx = p.x - last.x
            if math.abs(dx) > 30 then                     -- fast (600+ px/s at 20 checks a second)
                local d = dx > 0 and 1 or -1
                if dir ~= 0 and d ~= dir then flips[#flips + 1] = tick end
                dir = d
            end
            if p.x == last.x and p.y == last.y then idle = idle + 1 else idle = 0 end
        end
        last = p
        while #flips > 0 and tick - flips[1] > 12 do table.remove(flips, 1) end   -- the last 0.6 s
        if #flips >= 4 then
            flips = {}
            if big_until == 0 then hl.exec_cmd("hyprctl setcursor TuxOS " .. (tux_cursor_size * 3)) end
            big_until = tick + 24                        -- about a second and a bit
        elseif big_until ~= 0 and tick > big_until then
            big_until = 0
            hl.exec_cmd("hyprctl setcursor TuxOS " .. tux_cursor_size)
        end
        -- 20 checks a second while the mouse moves, one a second when it rests
        if fast and idle > 40 and big_until == 0 then fast = false; t:set_timeout(1000)
        elseif not fast and idle == 0 then fast = true; t:set_timeout(50) end
    end
    t = hl.timer(step, { timeout = 50, type = "repeat" })
end

------------------------------------------------------------------ the user's settings
-- TuxOS Control writes these (Displays, Keyboard, Mouse & touchpad, Window
-- rules, keys.lua = shortcuts moved to other keys) and the shell writes
-- theme.lua; they
-- override the defaults above
-- (not in safe mode: the login screen's way out of a broken setting)
for _, f in ipairs(os.getenv("TUXOS_SAFE") == "1" and {} or { "monitors", "keyboard", "mouse", "theme", "rules", "keys" }) do
    local path = (os.getenv("HOME") or "") .. "/.config/hypr/" .. f .. ".lua"
    local fh = io.open(path, "r")
    if fh then fh:close(); pcall(dofile, path) end
end
