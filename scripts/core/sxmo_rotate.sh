#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

applyptrmatrix() {
	[ -n "$SXMO_TOUCHSCREEN_ID" ] && xinput set-prop "$SXMO_TOUCHSCREEN_ID" --type=float --type=float "Coordinate Transformation Matrix" "$@"
	[ -n "$SXMO_STYLUS_ID" ] && xinput set-prop "$SXMO_STYLUS_ID" --type=float --type=float "Coordinate Transformation Matrix" "$@"
}

hyprlandfocusedtransform() {
	hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .transform'
}

hyprlandfocusedname() {
	hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .name'
}

restart_sxmo_hook_lisgd() {
	if [ ! -e "$XDG_CACHE_HOME"/sxmo/sxmo.nogesture ]; then
		superctl restart sxmo_hook_lisgd
	fi
}

xorgisrotated() {
	rotation="$(
		xrandr | grep primary | cut -d' ' -f 5 | sed s/\(//
	)"
	if [ "$rotation" = "normal" ]; then
		return 1;
	fi
	printf %s "$rotation"
	return 0;
}

swayisrotated() {
	rotation="$(
		hyprlandfocusedtransform | sed -e s/3/right/ -e s/1/left/ -e s/1/reverse/
	)"
	if [ "$rotation" = "normal" ]; then
		return 1;
	fi
	printf %s "$rotation"
	return 0;
}

xorgrotinvert() {
	sxmo_keyboard.sh close
	xrandr -o inverted
	applyptrmatrix -1 0 1 0 -1 1 0 0 1
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh invert
	exit 0
}

swayrotinvert() {
	hyprctl keyword monitor ,preferred,auto,1,transform,2
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh invert
	exit 0
}

xorgrotnormal() {
	sxmo_keyboard.sh close
	xrandr -o normal
	applyptrmatrix 0 0 0 0 0 0 0 0 0
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh normal
	exit 0
}

swayrotnormal() {
	hyprctl keyword monitor ,preferred,auto,1,transform,0
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh normal
	exit 0
}

xorgrotright() {
	sxmo_keyboard.sh close
	xrandr -o right
	applyptrmatrix 0 1 0 -1 0 1 0 0 1
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh right
	exit 0
}

swayrotright() {
	hyprctl keyword monitor ,preferred,auto,1,transform,3
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh right
	exit 0
}

xorgrotleft() {
	sxmo_keyboard.sh close
	xrandr -o left
	applyptrmatrix 0 -1 1 1 0 0 0 0 1
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh left
	exit 0
}

swayrotleft() {
	hyprctl keyword monitor ,preferred,auto,1,transform,1
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh left
	exit 0
}

isrotated() {
	case "$SXMO_WM" in
		hyprland)
			"swayisrotated"
			;;
		dwm)
			"xorgisrotated"
			;;
	esac
}

if [ -z "$1" ] || [ "rotate" = "$1" ]; then
	if [ $# -ne 0 ]; then
		shift
	fi
	if isrotated; then
		set -- rotnormal "$@"
	else
		set -- rot"${SXMO_ROTATE_DIRECTION:-right}" "$@"
	fi
fi

case "$SXMO_WM" in
	hyprland)
		"hyprland$1" "$@"
		;;
	dwm)
		"xorg$1" "$@"
		;;
esac
