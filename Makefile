# archminimal-hypr — run `make help`.
#
#   make deps      install packages (all from the official repos)
#   make install   link configs into ~/.config (existing files are backed up)
#   make reload    apply changes to the running session
#   make uninstall remove the links and restore your previous files

SHELL := /bin/bash
.DEFAULT_GOAL := help

QS          := qs -c archminimal
OPEN        := $(shell command -v xdg-open 2>/dev/null || command -v open 2>/dev/null)

PACKAGES := hyprland hypridle hyprlock hyprpolkitagent xdg-desktop-portal-hyprland \
            ghostty quickshell qt6-svg \
            papirus-icon-theme ttf-jetbrains-mono ttf-jetbrains-mono-nerd \
            pipewire pipewire-pulse wireplumber playerctl brightnessctl \
            upower power-profiles-daemon bluez bluez-utils bluetui iw \
            grim slurp wl-clipboard btop fastfetch yazi pulsemixer

.PHONY: help deps services check preview install uninstall status reload restart-shell lint logs memory

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

deps: ## Install all packages (asks for sudo; everything is in the official repos)
	sudo pacman -S --needed $(PACKAGES)
	@$(MAKE) --no-print-directory services

services: ## Enable bluetooth and power profiles (asks for sudo)
	sudo systemctl enable --now bluetooth.service power-profiles-daemon.service

check: ## Verify that the tools, fonts and icon theme are present
	@ok=1; \
	for c in Hyprland hyprctl hypridle hyprlock qs ghostty grim slurp wl-copy wpctl brightnessctl playerctl btop; do \
		if command -v $$c >/dev/null 2>&1; then printf "  ok       %s\n" $$c; else printf "  MISSING  %s\n" $$c; ok=0; fi; \
	done; \
	for f in "JetBrains Mono" "JetBrainsMono Nerd Font"; do \
		if fc-list 2>/dev/null | grep -q "$$f"; then echo "  ok       font: $$f"; else echo "  MISSING  font: $$f"; ok=0; fi; \
	done; \
	if [ -d /usr/share/icons/Papirus-Dark ]; then echo "  ok       icons: Papirus-Dark"; else echo "  MISSING  icons: Papirus-Dark"; ok=0; fi; \
	for s in bluetooth power-profiles-daemon; do \
		printf "  %-8s %s\n" "$$(systemctl is-active $$s 2>/dev/null || echo off)" "service: $$s"; \
	done; \
	[ $$ok -eq 1 ] || { echo "run 'make deps' to install what is missing"; exit 1; }

preview: ## Open the HTML design preview in a browser
	$(OPEN) preview/index.html

install: ## Link configs into ~/.config (backs up anything already there)
	@bin/links.sh install
	@mkdir -p $${XDG_STATE_HOME:-$$HOME/.local/state}/archminimal
	@echo
	@echo "Done. In Hyprland run 'make reload', or log in to a Hyprland session."

uninstall: ## Remove the links and restore the backed-up files
	@bin/links.sh uninstall

status: ## Show which configs are linked and whether the shell is running
	@bin/links.sh status
	@if pgrep -f "$(QS)" >/dev/null; then echo "  running  quickshell (archminimal)"; else echo "  stopped  quickshell (archminimal)"; fi

reload: ## Reload Hyprland and restart the bar/launcher
	hyprctl reload
	@$(MAKE) --no-print-directory restart-shell

restart-shell: ## Restart only the quickshell bar/launcher
	-@pkill -f "$(QS)" && sleep 0.3
	hyprctl dispatch 'hl.dsp.exec_cmd("$(QS)")'

lint: ## Static checks: shell scripts, JSON, Hyprland config, QML (when tools exist)
	@bash -n bin/links.sh && sh -n quickshell/scripts/stats.sh && echo "  ok   shell syntax"
	@if command -v shellcheck >/dev/null; then shellcheck bin/links.sh quickshell/scripts/stats.sh && echo "  ok   shellcheck"; \
	else echo "  skip shellcheck (not installed)"; fi
	@python3 -c 'import json,re; json.loads(re.sub(r"(?m)^\s*//.*$$", "", open("fastfetch/config.jsonc").read()))' && echo "  ok   fastfetch json"
	@if command -v Hyprland >/dev/null; then Hyprland --verify-config --config hypr/hyprland.lua && echo "  ok   hyprland.lua"; \
	else echo "  skip hyprland --verify-config (not installed)"; fi
	@if command -v qmllint6 >/dev/null || command -v qmllint >/dev/null; then \
		$$(command -v qmllint6 || command -v qmllint) quickshell/*.qml || true; \
	else echo "  skip qmllint (not installed)"; fi

logs: ## Show the bar/launcher log
	$(QS) log

memory: ## Show memory used by the desktop pieces
	@ps -C quickshell,qs,Hyprland,hypridle,ghostty -o rss=,comm= 2>/dev/null | \
		awk '{ printf "  %-12s %6.1f MB\n", $$2, $$1/1024; t += $$1 } END { printf "  %-12s %6.1f MB\n", "total", t/1024 }'
