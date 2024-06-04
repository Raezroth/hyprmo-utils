#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# shellcheck source=scripts/core/hyprmo_common.sh
. hyprmo_common.sh

anglevel_x_raw_bus="$(find /sys/ -name 'in_anglvel_x_raw')"
anglx() {
	cat "$anglevel_x_raw_bus"
}

waitmovement() {
	initialpos="$(anglx)"
	while true; do
		pos="$(anglx)"
		movement="$(echo "$initialpos" - "$pos" | bc)"
		[ 0 -gt "$movement" ] && movement="$(echo "$movement * -1" | bc)"
		[ 10 -lt "$movement" ] && return
		sleep 0.5
	done
}

"$@"