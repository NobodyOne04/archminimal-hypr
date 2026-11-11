-- ┌──────────────────────────────────────────────────────────────┐
-- │ archminimal-hypr · Hyprland (Lua config, Hyprland 0.57+)      │
-- │ Minimal, light, one cyan accent. Pairs with the archminimal   │
-- │ login screen. Per-machine settings go in local.lua.           │
-- └──────────────────────────────────────────────────────────────┘

local terminal = "kitty"
local files    = "kitty -e yazi"
local browser  = "firefox"
local qs       = "qs -c archminimal ipc call"
local mod      = "SUPER"

---------------------
---- ENVIRONMENT ----
---------------------

hl.env("QS_ICON_THEME", "Papirus-Dark")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "archminimal")  -- Arch-logo pointer, built by `make cursor`
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

------------------
---- MONITORS ----
------------------
-- Override per machine in local.lua.

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c archminimal")                       -- bar, launcher, wallpaper
    hl.exec_cmd("hypridle")                                -- dim, lock, suspend
    hl.exec_cmd("systemctl --user start hyprpolkitagent")  -- password prompts for apps
    hl.exec_cmd("hyprsunset")                              -- night light (hyprsunset.conf)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")   -- clipboard history
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout    = "us",
        repeat_delay = 250,
        repeat_rate  = 40,
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,
            disable_while_typing = true,
        },
    },
})

-- three-finger swipe between workspaces
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

--------------
---- LOOK ----
--------------

hl.config({
    general = {
        gaps_in          = 5,
        gaps_out         = 10,
        border_size      = 1,
        col = {
            active_border   = "rgb(00e5ff)",
            inactive_border = "rgb(3a3c44)",
        },
        layout           = "dwindle",
        resize_on_border = true,
    },

    decoration = {
        rounding         = 6,
        rounding_power   = 2,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        blur   = { enabled = false },   -- still no blur: the costly one
        shadow = {                      -- soft, low and dark; turn off in local.lua on weak GPUs
            enabled      = true,
            range        = 14,
            render_power = 3,
            offset       = { 0, 4 },
            color          = "rgba(00000066)",
            color_inactive = "rgba(00000033)",
        },
    },

    animations = { enabled = true },

    dwindle = { preserve_split = true },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        background_color         = "rgb(28292d)",
        focus_on_activate        = true,
        -- if the lock screen (quickshell) dies, a restarted one may take the
        -- lock over again; without this Hyprland rejects it and kills it
        allow_session_lock_restore = true,
    },

    cursor = { inactive_timeout = 5 },

    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },
})

----------------------
---- WINDOW RULES ----
----------------------

-- Apps may not maximize themselves. Hyprland tells every window it is
-- "maximized" (so apps skip drawing their own title bars); kitty and Firefox
-- remember that on close and ask to open maximized next time, which hid every
-- other window on the workspace. Layout changes come only from your keys.
hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- satty (screenshot editor) opens as a centred floating window
hl.window_rule({
    name  = "float-satty",
    match = { class = "^(com\\.gabm\\.satty)$" },
    float = true,
    size  = "monitor_w*0.7 monitor_h*0.7",
    center = true,
})

-- short, snappy animations; no border animation
hl.curve("snap", { type = "bezier", points = { {0.2, 0.9}, {0.1, 1.0} } })
hl.animation({ leaf = "global",     enabled = true,  speed = 2,   bezier = "snap" })
hl.animation({ leaf = "windows",    enabled = true,  speed = 2,   bezier = "snap", style = "popin 92%" })
hl.animation({ leaf = "fade",       enabled = true,  speed = 2,   bezier = "snap" })
hl.animation({ leaf = "layers",     enabled = true,  speed = 1.5, bezier = "snap", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true,  speed = 2.5, bezier = "snap", style = "slide" })
hl.animation({ leaf = "border",     enabled = false })

---------------------
---- KEYBINDINGS ----
---------------------
-- Every bind carries a "group: what it does" description; Super + / shows
-- them all (quickshell/Cheatsheet.qml reads `hyprctl binds -j`). Binds that
-- share a description are merged there, e.g. Super + 1…9.

local function bind(keys, desc, dsp, opts)
    local o = {}
    for k, v in pairs(opts or {}) do o[k] = v end
    o.description = desc
    hl.bind(keys, dsp, o)
end
local function run(cmd) return hl.dsp.exec_cmd(cmd) end

-- apps & shell
bind(mod .. " + Return",      "apps: terminal",            run(terminal))
bind(mod .. " + T",           "apps: terminal",            run(terminal))
bind(mod .. " + B",           "apps: firefox",             run(browser))
bind(mod .. " + E",           "apps: files (yazi)",        run(files))
bind(mod .. " + F",           "apps: launcher",            run(qs .. " launcher toggle"))
bind(mod .. " + Space",       "apps: launcher",            run(qs .. " launcher toggle"))
bind(mod .. " + D",           "apps: launcher",            run(qs .. " launcher toggle"))
bind(mod .. " + V",           "apps: clipboard history",   run(qs .. " launcher clip"))
bind(mod .. " + slash",       "apps: this key list",       run(qs .. " keys toggle"))

-- session & shell
bind(mod .. " + Escape",      "session: lock",             run("loginctl lock-session"))
bind(mod .. " + L",           "session: lock",             run("loginctl lock-session"))
bind(mod .. " + SHIFT + E",   "session: power menu",       run(qs .. " launcher power"))
bind(mod .. " + SHIFT + B",   "session: hide / show bar",  run(qs .. " bar toggle"))
bind(mod .. " + N",           "session: dismiss notifications", run(qs .. " notifications clear"))
bind(mod .. " + SHIFT + N",   "session: do not disturb",   run(qs .. " notifications dnd"))
bind(mod .. " + SHIFT + W",   "session: night light",      run(qs .. " night toggle"))

-- windows
bind(mod .. " + Q",           "windows: close",            hl.dsp.window.close())
bind(mod .. " + SHIFT + F",   "windows: fullscreen",       hl.dsp.window.fullscreen())
bind(mod .. " + SHIFT + V",   "windows: float / tile",     hl.dsp.window.float({ action = "toggle" }))
bind(mod .. " + P",           "windows: pseudo-tile",      hl.dsp.window.pseudo())
bind(mod .. " + SHIFT + T",   "windows: toggle split",     hl.dsp.layout("togglesplit"))

-- focus / move / resize: vim keys (and arrows for focus).
-- Super+L is lock, so focus-right is arrow-only; Shift/Ctrl+L still work.
local dirs = { H = "left", J = "down", K = "up", L = "right" }
for _, key in ipairs({ "H", "J", "K", "L" }) do
    local dir = dirs[key]
    if key ~= "L" then
        bind(mod .. " + " .. key,     "focus: move focus",     hl.dsp.focus({ direction = dir }))
    end
    bind(mod .. " + SHIFT + " .. key, "windows: move",         hl.dsp.window.move({ direction = dir }))
end
for _, dir in ipairs({ "left", "down", "up", "right" }) do
    bind(mod .. " + " .. dir,         "focus: move focus",     hl.dsp.focus({ direction = dir }))
end
local step = 40
local rep = { repeating = true }
bind(mod .. " + CTRL + H", "windows: resize (hold)", hl.dsp.window.resize({ x = -step, y = 0, relative = true }), rep)
bind(mod .. " + CTRL + J", "windows: resize (hold)", hl.dsp.window.resize({ x = 0, y = step,  relative = true }), rep)
bind(mod .. " + CTRL + K", "windows: resize (hold)", hl.dsp.window.resize({ x = 0, y = -step, relative = true }), rep)
bind(mod .. " + CTRL + L", "windows: resize (hold)", hl.dsp.window.resize({ x = step,  y = 0, relative = true }), rep)

-- mouse: SUPER + left drag moves, SUPER + right drag resizes
bind(mod .. " + mouse:272", "windows: drag to move",   hl.dsp.window.drag(),   { mouse = true })
bind(mod .. " + mouse:273", "windows: drag to resize", hl.dsp.window.resize(), { mouse = true })

-- workspaces 1..9 (SHIFT moves the window)
for i = 1, 9 do
    bind(mod .. " + " .. i,           "workspaces: go to",          hl.dsp.focus({ workspace = i }))
    bind(mod .. " + SHIFT + " .. i,   "workspaces: send window to", hl.dsp.window.move({ workspace = i }))
end
bind(mod .. " + Tab",        "workspaces: previous",      hl.dsp.focus({ workspace = "previous" }))
bind(mod .. " + mouse_down", "workspaces: next / previous", hl.dsp.focus({ workspace = "e+1" }))
bind(mod .. " + mouse_up",   "workspaces: next / previous", hl.dsp.focus({ workspace = "e-1" }))

-- screenshots (grim + slurp; satty to draw on them)
local dir   = "~/Pictures/Screenshots"
local shots = "mkdir -p " .. dir .. " && grim "
local stamp = dir .. "/$(date +%F_%H-%M-%S).png"
bind("Print",               "screenshots: region → clipboard",  run('grim -g "$(slurp -d)" - | wl-copy'))
bind("SHIFT + Print",       "screenshots: screen → file",       run(shots .. stamp))
bind(mod .. " + Print",     "screenshots: region → file",       run(shots .. '-g "$(slurp -d)" ' .. stamp))
bind(mod .. " + SHIFT + S", "screenshots: region → annotate",
     run('mkdir -p ' .. dir .. ' && grim -g "$(slurp -d)" - | satty --filename - '
         .. '--output-filename ' .. dir .. '/%Y-%m-%d_%H-%M-%S-edit.png '
         .. '--copy-command wl-copy --early-exit'))

-- laptop keys (work while locked too)
local held   = { locked = true, repeating = true }
local locked = { locked = true }
bind("XF86AudioRaiseVolume",  "media: volume up",        run("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), held)
bind("XF86AudioLowerVolume",  "media: volume down",      run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      held)
bind("XF86AudioMute",         "media: mute",             run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     locked)
bind("XF86AudioMicMute",      "media: mute mic",         run("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   locked)
bind("XF86MonBrightnessUp",   "media: brightness up",    run("brightnessctl -e4 -n2 set 5%+"),                  held)
bind("XF86MonBrightnessDown", "media: brightness down",  run("brightnessctl -e4 -n2 set 5%-"),                  held)
bind("XF86AudioPlay",         "media: play / pause",     run("playerctl play-pause"), locked)
bind("XF86AudioPause",        "media: play / pause",     run("playerctl play-pause"), locked)
bind("XF86AudioNext",         "media: next track",       run("playerctl next"),       locked)
bind("XF86AudioPrev",         "media: previous track",   run("playerctl previous"),   locked)

-------------------------------
---- PER-MACHINE OVERRIDES ----
-------------------------------
-- ~/.config/hypr/local.lua (created by `make install`, not in git):
-- monitors, scale, extra keyboard layouts... Anything there wins.

local ok, err = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/local.lua")
if not ok and not tostring(err):find("No such file") then
    error("local.lua: " .. tostring(err))
end
