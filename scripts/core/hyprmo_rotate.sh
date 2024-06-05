#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. hyprmo_common.sh

hyprlandfocusedtransform() {
	hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .transform'
}

hyprlandfocusedname() {
	hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .name'
}

restart_hyprmo_hook_lisgd() {
	if [ ! -e "$XDG_CACHE_HOME"/hyprmo/hyprmo.nogesture ]; then
		superctl restart hyprmo_hook_lisgd
	fi
}

hyprlandisrotated() {
	rotation="$(
		hyprlandfocusedtransform | sed -e s/3/right/ -e s/1/left/ -e s/1/reverse/
	)"
	if [ "$rotation" = "normal" ]; then
		return 1;
	fi
	printf %s "$rotation"
	return 0;
}

hyprlandrotinvert() {
	hyprctl keyword monitor ,preferred,auto,1,transform,2
	restart_hyprmo_hook_lisgd
	hyprmo_hook_rotate.sh invert
	exit 0
}

hyprlandrotnormal() {
	hyprctl keyword monitor ,preferred,auto,1,transform,0
	restart_hyprmo_hook_lisgd
	hyprmo_hook_rotate.sh normal
	exit 0
}

hyprlandrotright() {
	hyprctl keyword monitor ,preferred,auto,1,transform,3
	restart_hyprmo_hook_lisgd
	hyprmo_hook_rotate.sh right
	exit 0
}

hyprlandrotleft() {
	hyprctl keyword monitor ,preferred,auto,1,transform,1
	restart_hyprmo_hook_lisgd
	hyprmo_hook_rotate.sh left
	exit 0
}

isrotated() {
	case "$HYPRMO_WM" in
		hyprland)
			"hyprlandisrotated"
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
		set -- rot"${HYPRMO_ROTATE_DIRECTION:-right}" "$@"
	fi
fi

case "$HYPRMO_WM" in
	hyprland)
		"hyprland$1" "$@"
		;;
esac
