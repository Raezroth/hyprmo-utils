#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# Note: this script should be run as root via doas

# shellcheck source=scripts/core/hyprmo_common.sh
. hyprmo_common.sh

on() {
	rfkill unblock wlan
}

off() {
	rfkill block wlan
}

case "$1" in
	on)
		on
		;;
	off)
		off
		;;
	*) #toggle
		if rfkill list wifi | grep -q "yes"; then
			on
		else
			off
		fi
esac
