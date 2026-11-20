# Changelog

## Unreleased

### Added
- Mic and camera kill switches (`Super + Shift + M` / `C`): mutes every mic; turns the camera hard off by unloading and blocking its driver (`make privacy`, sudo, once)
- Notification center (`Super + Alt + N`, `ntf` in the bar): this session's notifications, act on them, clear one or all; do not disturb now keeps them there instead of dropping them
- Arch-logo cursor in the archminimal cyan (hyprcursor theme, `make cursor`)
- Decision records in `docs/adr/`: ten ADRs for the repo's existing decisions
- CI runs `make lint` (Hyprland `--verify-config`, qmllint, shellcheck, JSON) on every PR, in an Arch container
- `CLAUDE.md`: how to work on this repo with Claude Code

### Changed
- Renamed `hyprland` → `archminimal-hypr` (on GitHub: history kept, old URLs redirect); README clone path
  and file tree follow

### Fixed
- Lock screen password cursor: a thin cyan caret that blinks, and the placeholder hides while the field is focused, so the cursor no longer blinks through the middle of the word
- Privacy keys: the camera key said "not installed" after `sudo make privacy` until the shell restarted; both keys now send a full notification ("Microphone off", "Camera off") instead of a short popup
- Links and comments point to the login screen's new repo, `archminimal-greeter` (was `sddm-login`)
- The lock screen no longer has reboot / shutdown buttons: anyone at the keyboard could throw away the
  unsaved work in the apps behind it, without the password
- README: clone path and repo name, links to the login screen repo (the greeter link pointed at a folder
  that doesn't exist), and the clipboard note (password managers' copies are already skipped by cliphist)
- `make lint` never ran qmllint on Arch (it lives in `/usr/lib/qt6/bin`, not on PATH); now it does
- Launcher power menu: Lock says "lock screen", not "hyprlock" (that's only the fallback)
