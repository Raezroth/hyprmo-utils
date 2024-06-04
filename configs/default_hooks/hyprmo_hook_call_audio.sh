#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# This script is executed when phone successfully enables/disables callaudio
# mode.

# $1 = "enable" or "disable"

# shellcheck source=scripts/core/hyprmo_common.sh
. hyprmo_common.sh

# Phonecall started
if [ "$1" = "enable" ]; then
	hyprmo_log "Attempting hack to get things just right."
	# fixes bug where sometimes we start with speaker on and mic off
	hyprmo_modemaudio.sh enable_speaker
	hyprmo_modemaudio.sh disable_speaker
	hyprmo_modemaudio.sh mute_mic
	hyprmo_modemaudio.sh unmute_mic

	# Add other things here, e.g., volume boosters

	hyprmo_modemaudio.sh is_disabled_speaker && hyprmo_modemaudio.sh is_unmuted_mic
# Phonecall ended
elif [ "$1" = "disable" ]; then
	hyprmo_log "Attempting hack to get things just right."
	# fixes bug where sometimes we leave call with speaker off
	hyprmo_modemaudio.sh disable_speaker
	hyprmo_modemaudio.sh enable_speaker

	# Add other things here, e.g., volume boosters

	hyprmo_modemaudio.sh is_enabled_speaker
fi
