# archminimal-hypr

A minimal, lightweight Hyprland desktop for Arch Linux in the same style as the
[archminimal login screen](https://github.com/NobodyOne04/archminimal-greeter): dark, monospace, one cyan accent, corner marks and a `sys::` voice.

- **Bar**: workspaces, window title, clock, then CPU, memory, GPU, temperature, network, Bluetooth, keyboard
  layout, volume, battery with power profile, and a power button. Hover any value for details; click to act.
- **Launcher**: fuzzy search over your apps with real icons (Papirus-Dark), most-used first, and a power menu.
- **kitty**: matching palette, quiet tab bar, works on modest (VM) graphics.
- **Lock & idle**: the login screen's look (Quickshell; hyprlock as the fallback), without its reboot /
  shutdown buttons since your apps are still open; hypridle dims, locks, turns the screen off and suspends.
- **Notifications**: popups in the same style, drawn by the shell itself (no mako/dunst). Do not disturb on a
  key. No history panel, by design.
- **Clipboard history** (`Super + V`), **screenshot annotation** with satty, **night light** with hyprsunset,
  and a **key cheat sheet** (`Super + /`) read live from Hyprland.

Open [`preview/index.html`](preview/index.html) (`make preview`) for an interactive mock-up of the whole
desktop.

> Requires **Hyprland 0.57+**, which uses the Lua config format (`hyprland.lua`). Everything here was checked
> against Arch's current packages: Hyprland 0.57.1 `--verify-config`, Quickshell 0.3.2 type definitions plus
> `qmllint`, kitty's own config parser, and the stats collector on real Arch `gawk`. It runs daily in an Arch
> VM; not yet tested on real hardware (GPU, battery and brightness paths). CI runs `make lint` on every PR.

## Why it is light

| Piece | What runs |
|---|---|
| Bar + launcher + wallpaper + notifications | one Quickshell process (QML); launcher, key list and popups exist only while shown |
| System stats | one long-lived `awk` reading `/proc` and `/sys` every 2 s; no per-tick process spawning |
| GPU stats | auto-detected; NVIDIA is queried only while the dGPU is awake, so it is never woken up just to be measured |
| Compositor | no blur, one soft shadow, short animations |
| Terminal | kitty: GPU-rendered but only needs OpenGL 3.3, so it also runs in VMs |

`make memory` shows what it actually uses on your machine.

## Install

As part of the whole setup, [`archminimal-setup`](https://github.com/NobodyOne04/archminimal-setup)'s `make all`
does this. On its own:

```bash
git clone git@github.com:NobodyOne04/archminimal-hypr.git ~/projects/archminimal-hypr && cd ~/projects/archminimal-hypr
make deps       # pacman packages (all official repos) + enables bluetooth and power-profiles-daemon
make check      # verifies tools, fonts, icon theme and services
make install    # symlinks configs into ~/.config; anything already there is backed up
```

Then log in to Hyprland (from the [archminimal greeter](https://github.com/NobodyOne04/archminimal-greeter) or any login manager), or run
`make reload` if you are already in it.

`make install` links (not copies) the files, so editing this repo changes your desktop directly. It touches:

| Link | From |
|---|---|
| `~/.config/hypr/hyprland.lua`, `hyprlock.conf`, `hypridle.conf`, `hyprsunset.conf` | `hypr/` |
| `~/.config/quickshell/archminimal` | `quickshell/` |
| `~/.config/kitty/kitty.conf` | `kitty/kitty.conf` |
| `~/.config/fastfetch/config.jsonc` | `fastfetch/config.jsonc` |
| `~/.local/share/archminimal/wallpaper.png` | `assets/wallpaper.png` |

It also creates `~/.config/hypr/local.lua` for per-machine settings (not tracked, never overwritten), and builds the
Arch-logo cursor from `cursor/archminimal/` into `~/.local/share/icons/archminimal` (a copy: run `make cursor` after
editing it).
`make uninstall` removes the links and puts your previous files back.

## Keys

| Keys | Action |
|---|---|
| `Super + T` / `Super + Return` | kitty |
| `Super + B` | Firefox |
| `Super + F` / `Super + Space` / `Super + D` | launcher (pick an app) |
| `Super + /` | this key list, on screen |
| `Super + V` | clipboard history |
| `Super + Shift + E` | power menu (lock, suspend, log out, reboot, shut down) |
| `Super + Escape` / `Super + L` | lock (apps stay open) |
| `Super + E` | files (yazi in kitty) |
| `Super + Shift + B` | hide/show the bar |
| `Super + N` / `Super + Shift + N` | dismiss notifications / do not disturb |
| `Super + Shift + W` | night light on/off |
| `Super + Q` | close window |
| `Super + Shift + F` | fullscreen |
| `Super + Shift + V` / `P` / `Shift + T` | float / pseudo-tile / toggle split |
| `Super + H J K` or arrows | focus (`L` is lock; use `→`) |
| `Super + Shift + H J K L` | move window |
| `Super + Ctrl + H J K L` | resize (hold) |
| `Super + 1…9` / `Super + Shift + 1…9` | go to / move window to workspace |
| `Super + Tab` | previous workspace |
| `Super + drag` (left / right button) | move / resize with the mouse |
| `Print` / `Shift + Print` / `Super + Print` | region → clipboard / full screen → file / region → file |
| `Super + Shift + S` | region → satty (draw, arrows, blur; save or copy) |
| media, volume, brightness keys | work everywhere, also while locked |
| three-finger swipe | switch workspace |

## Bar

| Module | Shows | Hover | Click |
|---|---|---|---|
| Arch logo | | | launcher |
| `01 02 …` | workspaces (cyan = active, light = has windows) | | go to it; scroll to move between them |
| title | active window | | |
| clock | `HH:mm  DDD DD MMM` | | |
| `cpu` | usage + meter | temperature, load, per-core bars | btop |
| `mem` | used GiB + meter | used/total, cache, swap | btop |
| `gpu` | busy % (auto-detected) | device, temperature, VRAM, power, dGPU state | btop |
| `tmp` | CPU temperature | | |
| `net` | download rate | interface, Wi-Fi name and signal, up/down | nmtui (or impala) |
| `bt` | off / on / connected device | devices and their battery | bluetui · right-click: power on/off |
| `kb` | layout (only with 2+ layouts) | | next layout |
| `nl` | night light: `off` or the warmth (`4000k`) | schedule | on / off |
| `dnd` | only while do not disturb is on | | turn it off |
| `vol` | volume / `mute` | output, mic | mute · scroll: ±5 % · right-click: mixer |
| `bat` | charge (`↑` when charging) | status, time left, power draw, profile | next power profile |
| `⏻` | | | power menu |

Values turn red past the thresholds in `Theme.qml` (CPU 85 %, memory 85 %, 85 °C, battery 15 %).

## Launcher

Type to fuzzy-search names, descriptions and keywords; matched letters are highlighted by position, apps you
launch often rise to the top. `↑ ↓` (or `Ctrl + J/K`) select, `Enter` runs, `Tab` completes, `Esc` or a click
outside closes. If nothing matches, `Enter` runs what you typed as a command in kitty. Terminal apps
(`Terminal=true`) open in kitty automatically. Power actions are searchable too (`reb` → Reboot).

## Customize

- **Colors, font, thresholds, click commands, workspace count, GPU choice**: `quickshell/Theme.qml`, then
  `make restart-shell`.
- **Monitors, scaling, extra keyboard layouts**: `~/.config/hypr/local.lua`, for example:
  ```lua
  hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1.25 })
  hl.config({ input = { kb_layout = "us,ru", kb_options = "grp:alt_shift_toggle" } })
  ```
  A syntax error there is reported by Hyprland with the file and line; it is never silently ignored.
- **Wallpaper**: replace `assets/wallpaper.png` (used by the desktop and the lock screen).
- **Idle timings**: `hypr/hypridle.conf` (dim 4 min, lock 5 min, screen off 5.5 min, suspend 15 min).
- **Night light schedule**: `hypr/hyprsunset.conf` (4000 K from 21:00, neutral from 07:00).
- **Notifications**: `notifyTimeout` and `notifyMax` in `Theme.qml`.
- **Key list**: it shows every bind with a `"group: what"` description in `hyprland.lua`; give a new bind one
  and it appears under that group.
- **Shadows / rounding**: on a weak GPU or a VM, turn them off in `local.lua`:
  `hl.config({ decoration = { rounding = 0, shadow = { enabled = false } } })`.

## Makefile

| Target | What |
|---|---|
| `make deps` / `services` | install packages / enable bluetooth and power profiles |
| `make check` | verify tools, fonts, icons, services |
| `make preview` | open the HTML mock-up |
| `make install` / `uninstall` | link configs / remove links and restore backups |
| `make cursor` | build and apply the Arch-logo cursor (hyprcursor theme) |
| `make status` | what is linked, whether the shell runs |
| `make reload` / `restart-shell` | reload Hyprland and the shell / only the shell |
| `make lint` | shellcheck, JSON, `Hyprland --verify-config`, qmllint (when installed); CI runs it on every PR |
| `make logs` / `memory` | shell log / memory used by each piece |

## Troubleshooting

- **No bar**: `make logs` shows QML errors; `make restart-shell` starts it again.
- **No icons in the launcher**: `pacman -S papirus-icon-theme qt6-svg`, then `make restart-shell`.
- **Odd glyphs in the bar**: install `ttf-jetbrains-mono-nerd` (`make check` tells you).
- **GPU module missing or wrong**: set `gpu` in `Theme.qml` to `amd`, `intel`, `nvidia` or `none`.
- **Wi-Fi name not shown**: install `iw`.
- **No notifications**: only one daemon can own them; quit mako/dunst/swaync if one is running, then
  `make restart-shell`. Test with `notify-send hello world`.
- **Clipboard history empty**: needs `cliphist`; it records from the next login (or start the two
  `wl-paste --watch cliphist store` lines from `hyprland.lua` by hand). Everything you copy is kept on disk,
  except what the source marks as sensitive (KeePassXC and other password managers do; cliphist skips
  those). A password copied from anywhere else is kept: `cliphist wipe` clears it all.
- **Night light does nothing / `nl` missing**: needs `hyprsunset` running, and a GPU driver with gamma
  control (some VMs have none).

## Files

```text
archminimal-hypr/
├── hypr/
│   ├── hyprland.lua          Hyprland (Lua, 0.57+)
│   ├── local.lua.example     per-machine template → ~/.config/hypr/local.lua
│   ├── hyprlock.conf         lock screen
│   ├── hypridle.conf         idle: dim, lock, screen off, suspend
│   └── hyprsunset.conf       night light schedule
├── quickshell/               bar, launcher, wallpaper (qs -c archminimal)
│   ├── shell.qml             entry point + IPC
│   ├── Theme.qml             all settings
│   ├── Bar.qml  Module.qml  Kv.qml  Workspaces.qml
│   ├── Launcher.qml  LauncherState.qml   apps, power menu, clipboard history
│   ├── Notifications.qml  NotifyState.qml   notification popups, do not disturb
│   ├── Cheatsheet.qml        Super + / key list
│   ├── NightLight.qml        hyprsunset toggle
│   ├── Stats.qml  Keyboard.qml  Wallpaper.qml
│   └── scripts/stats.sh, stats.awk   system stats collector
├── kitty/kitty.conf
├── fastfetch/config.jsonc
├── assets/wallpaper.png
├── preview/index.html        interactive design mock-up
├── bin/links.sh              install / uninstall / status of the symlinks
└── Makefile
```
