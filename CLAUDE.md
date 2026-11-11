# archminimal-hypr

Formerly `hyprland` (renamed on GitHub; old URLs redirect).

My Arch desktop: Hyprland (Lua config, 0.57+), a Quickshell shell (bar, launcher, lock screen,
notifications, key list), kitty and fastfetch, in the archminimal look. Runs daily in an Arch VM; not yet on
real hardware. Features, keys and modules: `README.md`. The login greeter is a separate repo
(`NobodyOne04/archminimal-greeter`); the lock screen copies its look.

## Commands
- `make lint`: shellcheck, fastfetch JSON, `Hyprland --verify-config` (must say `config ok`), qmllint. CI runs
  it in an Arch container (as a non-root user: Hyprland refuses root) on every PR. It doesn't run on macOS
  (no Hyprland there): push and read CI, or run it on the VM.
- qmllint is informational, never fails: ~200 warnings, nearly all false ("Member … not found on type Theme":
  it doesn't know Quickshell's `pragma Singleton` types; unqualified access; `PanelWindow` "not creatable").
  Look for *new* kinds of warning in the files you touched, not the count.
- `make check`: tools, fonts, icons, services present (on the Arch machine).
- On the Arch machine: `make reload` (Hyprland + shell), `make restart-shell`, `make logs`, `make status`.

## Layout
- `hypr/hyprland.lua`: env, autostart, input, look, rules, keys. Every bind has a `"group: what"` description;
  `Super + /` (`quickshell/Cheatsheet.qml`) lists them from `hyprctl binds -j`.
- `hypr/{hypridle,hyprlock,hyprsunset}.conf`; `hypr/local.lua.example` → untracked `~/.config/hypr/local.lua`.
- `quickshell/`: `shell.qml` entry + IPC, `Theme.qml` every setting and colour, one file per piece;
  `scripts/stats.sh` + `stats.awk` the one long-running stats collector.
- `cursor/archminimal/`: hyprcursor theme source (SVG + `meta.hl`); `make cursor` builds it into
  `~/.local/share/icons` (a copy, not a link). Only the arrow shapes are drawn; the rest fall back.
- `bin/links.sh`: install / uninstall / status of the symlinks into `~/.config` (backups in a ledger).
- `preview/index.html`: static mock-up of the desktop; not loaded by anything.
- `docs/adr/`: decision records (`NNNN-*.adr`, index `README.md`); read the one for a decision before changing it.

## Conventions
- Hyprland is configured in **Lua** (`hl.config`, `hl.bind`, `hl.dsp.*`), not hyprlang. Dispatch from
  shell/conf files with `hyprctl dispatch 'hl.dsp.…'`.
- Commands from QML: `Quickshell.execDetached([...])` with an argument array; user text goes in as `"$1"`
  (`sh -c '…"$1"…' sh value`), never spliced into a shell string.
- Light by design: no blur, no per-tick process spawning in the bar (stats come from the one awk loop),
  popups exist only while shown. Keep it that way.
- The lock screen (`Lock.qml`, `LockScreen.qml`, PAM stack `hyprlock`) mirrors the greeter's look, but has
  no reboot/shutdown: apps are open behind it. Don't add actions that work without the password.
- Restarting quickshell while locked drops the lock screen: `make restart-shell` refuses; keep that check.
- Look: one cyan accent `#00e5ff`, palette in `Theme.qml`, monospace, corner marks, `sys::` voice.
- Changes go through `github-flow` (squash only). Anything visual or input-related also needs a try on the
  VM before merging: CI only proves the config parses.
