#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Hyprmo Contributors

# 1.9.0 introduced a new naming scheme for hooks.
# This script moves them from their 1.8.x location.

cd "$XDG_CONFIG_HOME/hyprmo/hooks/" 2>/dev/null || exit
mkdir -p "$XDG_CONFIG_HOME/hyprmo/hooks/$HYPRMO_DEVICE_NAME"

[ -e inputhandler ] && mv inputhandler "$HYPRMO_DEVICE_NAME/hyprmo_hook_inputhandler.sh"
[ -e lock ] && mv lock "$HYPRMO_DEVICE_NAME/hyprmo_hook_lock.sh"
[ -e off ] && mv off "$HYPRMO_DEVICE_NAME/hyprmo_hook_screenoff.sh"
[ -e unlock ] && mv unlock "$HYPRMO_DEVICE_NAME/hyprmo_hook_unlock.sh"

find . -maxdepth 1 -type f -exec basename {} \; \
	| grep -v 'needs-migration$' \
	| grep -v '^hyprmo_hook_.*' \
	| xargs -I{} mv {} hyprmo_hook_{}
