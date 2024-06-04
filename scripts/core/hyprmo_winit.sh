#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

envvars() {
	export HYPRMO_WM=hyprland
	export MOZ_ENABLE_WAYLAND=1
	export SDL_VIDEODRIVER=wayland
	export XDG_CURRENT_DESKTOP=Hyprland
	# shellcheck disable=SC2086
	command -v $HYPRMO_TERMINAL "" >/dev/null || export HYPRMO_TERMINAL="kitty"
	command -v "$KEYBOARD" >/dev/null || export KEYBOARD=wvkbd-mobintl
	[ -z "$MOZ_USE_XINPUT2" ] && export MOZ_USE_XINPUT2=1
}

defaults() {
	[ -e "$HOME"/.Xresources ] && xrdb -merge "$HOME"/.Xresources
}

with_dbus() {
	echo "$DBUS_SESSION_BUS_ADDRESS" > "$XDG_RUNTIME_DIR"/dbus.bus
	exec Hyprland
}

cleanup() {
	hyprmo_jobs.sh stop all
	pkill bemenu
	pkill wvkbd
	pkill superd
}

# shellcheck source=scripts/core/hyprmo_init.sh
. hyprmo_init.sh
