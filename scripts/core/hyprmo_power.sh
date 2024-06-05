#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# shellcheck source=scripts/core/hyprmo_common.sh
. hyprmo_common.sh

usage() {
	printf "usage: %s [reboot|poweroff|logout|togglewm]\n" "$(basename "$0")"
}

case "$1" in
	reboot)
		hyprmo_hook_power.sh reboot
		hyprmo_jobs.sh stop all
		doas reboot
		;;
	poweroff)
		hyprmo_hook_power.sh poweroff
		hyprmo_jobs.sh stop all
		doas poweroff
		;;
	logout)
		hyprmo_hook_logout.sh
		case "$HYPRMO_WM" in
			"hyprland") hyprctl dispatch exit ;;
		esac
		;;
	*)
		usage
		exit 1
		;;
esac
