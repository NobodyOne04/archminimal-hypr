# Changelog

## Unreleased

### Added
- CI runs `make lint` (Hyprland `--verify-config`, qmllint, shellcheck, JSON) on every PR, in an Arch container
- `CLAUDE.md`: how to work on this repo with Claude Code

### Fixed
- The lock screen no longer has reboot / shutdown buttons: anyone at the keyboard could throw away the
  unsaved work in the apps behind it, without the password
- README: clone path and repo name, links to the login screen repo (the greeter link pointed at a folder
  that doesn't exist), and the clipboard note (password managers' copies are already skipped by cliphist)
- Launcher power menu: Lock says "lock screen", not "hyprlock" (that's only the fallback)
