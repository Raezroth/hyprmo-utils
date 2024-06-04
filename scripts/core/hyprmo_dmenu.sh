#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# We still use dmenu in dwm|worgs cause pointer/touch events
# are not implemented yet in the X11 library of bemenu

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

#prevent infinite recursion:
unalias bemenu
unalias dmenu
unalias wofi

case "$1" in
	isopen)
		case "$HYPRMO_WM" in
			hyprland)
				rofi -show drun
				;;
		esac
		;;
	close)
		case "$HYPRMO_WM" in
			hyprland)
				if | pgrep wofi >/dev/null; then
					exit
				fi
		esac
		;;
esac

if [ -n "$WAYLAND_DISPLAY" ]; then
	if hyprmo_state.sh get | grep -q unlock; then
		#swaymsg mode menu -q # disable default button inputs
		cleanmode() {
			#swaymsg mode default -q
		}
		trap 'cleanmode' TERM INT
	fi

	returned=$?

	cleanmode
	exit "$returned"
fi

#export BEMENU_BACKEND=curses
exec rofi -show drun
