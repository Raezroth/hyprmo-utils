#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# shellcheck source=scripts/core/sxmo_common.sh
. hyprmo_common.sh

notify-send "$@"

while [ "$#" -gt 0 ]; do
	case "$1" in
		--urgency=*)
			shift
			;;
		*)
			hyprmo_log "$1"
			shift
			;;
	esac
done
