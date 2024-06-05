#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# shellcheck source=scripts/core/hyprmo_common.sh
. hyprmo_common.sh

keyboard_opened() {
	if hyprmo_rotate.sh isrotated ; then
		hyprmo_rotate.sh rotnormal
	fi
}

keyboard_closed() {
	if [ "$(hyprmo_rotate.sh isrotated)" != "left" ]; then
		hyprmo_rotate.sh rotleft
	fi
}

evtest "$HYPRMO_KEYBOARD_SLIDER_EVENT_DEVICE" | while read -r line; do
	# shellcheck disable=SC2254
	case $line in
		($HYPRMO_KEYBOARD_SLIDER_CLOSE_EVENT) keyboard_closed ;;
		($HYPRMO_KEYBOARD_SLIDER_OPEN_EVENT)  keyboard_opened ;;
	esac
done
