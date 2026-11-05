#!/bin/sh
# Link the repo's configs into ~/.config (install), undo it (uninstall), or
# show the state (status). Existing files are moved aside, never deleted, and
# restored on uninstall.
set -eu

REPO=$(cd "$(dirname "$0")/.." && pwd)
CONF=${XDG_CONFIG_HOME:-$HOME/.config}
DATA=${XDG_DATA_HOME:-$HOME/.local/share}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/archminimal
LEDGER=$STATE/backups.txt
STAMP=$(date +%Y%m%d-%H%M%S)

# source (in repo) -> target
LINKS="
hypr/hyprland.lua       $CONF/hypr/hyprland.lua
hypr/hyprlock.conf      $CONF/hypr/hyprlock.conf
hypr/hypridle.conf      $CONF/hypr/hypridle.conf
quickshell              $CONF/quickshell/archminimal
ghostty/config          $CONF/ghostty/config
fastfetch/config.jsonc  $CONF/fastfetch/config.jsonc
assets/wallpaper.png    $DATA/archminimal/wallpaper.png
"

install_links() {
    mkdir -p "$STATE"
    echo "$LINKS" | while read -r src dst; do
        [ -n "$src" ] || continue
        mkdir -p "$(dirname "$dst")"
        if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$REPO/$src" ]; then
            echo "  ok      $dst"
            continue
        fi
        if [ -e "$dst" ] || [ -L "$dst" ]; then
            mv "$dst" "$dst.bak-$STAMP"
            echo "$dst $dst.bak-$STAMP" >> "$LEDGER"
            echo "  backup  $dst -> $dst.bak-$STAMP"
        fi
        ln -s "$REPO/$src" "$dst"
        echo "  link    $dst"
    done
    if [ ! -e "$CONF/hypr/local.lua" ]; then
        cp "$REPO/hypr/local.lua.example" "$CONF/hypr/local.lua"
        echo "  create  $CONF/hypr/local.lua (per-machine settings)"
    fi
}

uninstall_links() {
    echo "$LINKS" | while read -r src dst; do
        [ -n "$src" ] || continue
        if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$REPO/$src" ]; then
            rm "$dst"
            echo "  unlink  $dst"
            # restore the most recent backup of this path, if any
            if [ -f "$LEDGER" ]; then
                bak=$(awk -v d="$dst" '$1 == d { b = $2 } END { print b }' "$LEDGER")
                if [ -n "$bak" ] && { [ -e "$bak" ] || [ -L "$bak" ]; }; then
                    mv "$bak" "$dst"
                    echo "  restore $dst"
                fi
            fi
        fi
    done
    echo "  kept    $CONF/hypr/local.lua"
}

status_links() {
    echo "$LINKS" | while read -r src dst; do
        [ -n "$src" ] || continue
        if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$REPO/$src" ]; then
            echo "  linked   $dst"
        elif [ -e "$dst" ]; then
            echo "  other    $dst (not from this repo)"
        else
            echo "  missing  $dst"
        fi
    done
}

case "${1:-}" in
    install) install_links ;;
    uninstall) uninstall_links ;;
    status) status_links ;;
    *) echo "usage: $0 install|uninstall|status" >&2; exit 2 ;;
esac
