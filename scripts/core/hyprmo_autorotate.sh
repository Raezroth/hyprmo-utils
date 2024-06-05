#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# shellcheck source=scripts/core/hyprmo_common.sh
. hyprmo_common.sh

ROTATION_GRAVITY="${HYPRMO_ROTATION_GRAVITY:-"16374"}"
ROTATION_THRESHOLD="${HYPRMO_ROTATION_THRESHOLD:-"400"}"
POLL_TIME="${HYPRMO_ROTATION_POLL_TIME:-1}"
RIGHT_SIDE_UP="$(echo "$ROTATION_GRAVITY - $ROTATION_THRESHOLD" | bc)"
UPSIDE_DOWN="$(echo "-$ROTATION_GRAVITY + $ROTATION_THRESHOLD" | bc)"
FILE_Y="$(find /sys/bus/iio/devices/iio:device*/ -iname in_accel_y_raw)"
FILE_X="$(find /sys/bus/iio/devices/iio:device*/ -iname in_accel_x_raw)"

while true; do
	y_raw="$(cat "$FILE_Y")"
	x_raw="$(cat "$FILE_X")"
	if  [ "$x_raw" -ge "$RIGHT_SIDE_UP" ] && hyprmo_rotate.sh isrotated ; then
		hyprmo_rotate.sh rotnormal
	elif [ "$x_raw" -le "$UPSIDE_DOWN" ] && [ "$(hyprmo_rotate.sh isrotated)" != "invert" ]; then
		hyprmo_rotate.sh rotinvert
	elif [ "$y_raw" -le "$UPSIDE_DOWN" ] && [ "$(hyprmo_rotate.sh isrotated)" != "right" ]; then
		hyprmo_rotate.sh rotright
	elif [ "$y_raw" -ge "$RIGHT_SIDE_UP" ] && [ "$(hyprmo_rotate.sh isrotated)" != "left" ]; then
		hyprmo_rotate.sh rotleft
	fi
	sleep "$POLL_TIME"
done
