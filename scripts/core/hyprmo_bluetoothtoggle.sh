#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# Must be run as root

# shellcheck source=scripts/core/hyprmo_common.sh
. hyprmo_common.sh

on() {
	rfkill unblock bluetooth
	case "$HYPRMO_OS" in
		alpine|postmarketos)
			rc-service bluetooth start
			rc-update add bluetooth
			;;
		arch|archarm|nixos|debian)
			systemctl start bluetooth
			systemctl enable bluetooth
			;;
	esac
}

off() {
	case "$HYPRMO_OS" in
		alpine|postmarketos)
			rc-service bluetooth stop
			rc-update del bluetooth
			;;
		arch|archarm|nixos|debian)
			systemctl stop bluetooth
			systemctl disable bluetooth
			;;
	esac
	rfkill block bluetooth
}

case "$1" in
	on)
		on
		;;
	off)
		off
		;;
	*) #toggle
		if rfkill list bluetooth | grep -q "yes"; then
			on
		else
			off
		fi
esac
