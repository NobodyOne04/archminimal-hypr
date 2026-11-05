-- ┌──────────────────────────────────────────────────────────────┐
-- │ archminimal-hypr · Hyprland (Lua config, Hyprland 0.57+)      │
-- │ Minimal, light, one cyan accent. Pairs with the archminimal   │
-- │ login screen. Per-machine settings go in local.lua.           │
-- └──────────────────────────────────────────────────────────────┘

local terminal = "kitty"
local files    = "kitty -e yazi"
local qs       = "qs -c archminimal ipc call"
local mod      = "SUPER"

---------------------
---- ENVIRONMENT ----
---------------------

hl.env("QS_ICON_THEME", "Papirus-Dark")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
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
        rounding         = 0,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        blur   = { enabled = false },   -- light: no blur passes
        shadow = { enabled = false },
    },

    animations = { enabled = true },

    dwindle = { preserve_split = true },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        background_color         = "rgb(28292d)",
        focus_on_activate        = true,
    },

    cursor = { inactive_timeout = 5 },

    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },
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

local function bind(keys, dsp, opts) hl.bind(keys, dsp, opts) end
local function run(cmd) return hl.dsp.exec_cmd(cmd) end

-- apps & shell
bind(mod .. " + Return",      run(terminal))
bind(mod .. " + Space",       run(qs .. " launcher toggle"))
bind(mod .. " + D",           run(qs .. " launcher toggle"))
bind(mod .. " + SHIFT + E",   run(qs .. " launcher power"))
bind(mod .. " + B",           run(qs .. " bar toggle"))
bind(mod .. " + E",           run(files))
bind(mod .. " + Escape",      run("loginctl lock-session"))

-- windows
bind(mod .. " + Q", hl.dsp.window.close())
bind(mod .. " + F", hl.dsp.window.fullscreen())
bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
bind(mod .. " + P", hl.dsp.window.pseudo())
bind(mod .. " + T", hl.dsp.layout("togglesplit"))

-- focus / move / resize: vim keys (and arrows for focus)
local dirs = { H = "left", J = "down", K = "up", L = "right" }
for key, dir in pairs(dirs) do
    bind(mod .. " + " .. key,           hl.dsp.focus({ direction = dir }))
    bind(mod .. " + SHIFT + " .. key,   hl.dsp.window.move({ direction = dir }))
end
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    bind(mod .. " + " .. dir, hl.dsp.focus({ direction = dir }))
end
local step = 40
bind(mod .. " + CTRL + H", hl.dsp.window.resize({ x = -step, y = 0, relative = true }), { repeating = true })
bind(mod .. " + CTRL + L", hl.dsp.window.resize({ x = step,  y = 0, relative = true }), { repeating = true })
bind(mod .. " + CTRL + K", hl.dsp.window.resize({ x = 0, y = -step, relative = true }), { repeating = true })
bind(mod .. " + CTRL + J", hl.dsp.window.resize({ x = 0, y = step,  relative = true }), { repeating = true })

-- mouse: SUPER + left drag moves, SUPER + right drag resizes
bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- workspaces 1..9 (SHIFT moves the window)
for i = 1, 9 do
    bind(mod .. " + " .. i,           hl.dsp.focus({ workspace = i }))
    bind(mod .. " + SHIFT + " .. i,   hl.dsp.window.move({ workspace = i }))
end
bind(mod .. " + Tab",        hl.dsp.focus({ workspace = "previous" }))
bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- screenshots (grim + slurp)
local shots = "mkdir -p ~/Pictures/Screenshots && grim "
local stamp = "~/Pictures/Screenshots/$(date +%F_%H-%M-%S).png"
bind("Print",               run('grim -g "$(slurp -d)" - | wl-copy'))
bind("SHIFT + Print",       run(shots .. stamp))
bind(mod .. " + Print",     run(shots .. '-g "$(slurp -d)" ' .. stamp))

-- laptop keys (work while locked too)
local held = { locked = true, repeating = true }
bind("XF86AudioRaiseVolume",  run("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), held)
bind("XF86AudioLowerVolume",  run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      held)
bind("XF86AudioMute",         run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
bind("XF86AudioMicMute",      run("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
bind("XF86MonBrightnessUp",   run("brightnessctl -e4 -n2 set 5%+"),                  held)
bind("XF86MonBrightnessDown", run("brightnessctl -e4 -n2 set 5%-"),                  held)
bind("XF86AudioPlay",         run("playerctl play-pause"), { locked = true })
bind("XF86AudioPause",        run("playerctl play-pause"), { locked = true })
bind("XF86AudioNext",         run("playerctl next"),       { locked = true })
bind("XF86AudioPrev",         run("playerctl previous"),   { locked = true })

-------------------------------
---- PER-MACHINE OVERRIDES ----
-------------------------------
-- ~/.config/hypr/local.lua (created by `make install`, not in git):
-- monitors, scale, extra keyboard layouts... Anything there wins.

local ok, err = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/local.lua")
if not ok and not tostring(err):find("No such file") then
    error("local.lua: " .. tostring(err))
end
