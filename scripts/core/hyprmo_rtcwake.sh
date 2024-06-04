#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# shellcheck source=configs/profile.d/hyprmo_init.sh
. /etc/profile.d/hyprmo_init.sh

. hyprmo_common.sh

# We can have multiple cronjobs at the same time
hyprmo_wakelock.sh lock hyprmo_executing_cronjob_$$ infinite
hyprmo_wakelock.sh unlock hyprmo_waiting_cronjob

finish() {
	hyprmo_wakelock.sh unlock hyprmo_executing_cronjob_$$
	exit 0
}

trap 'finish' TERM INT EXIT

hyprmo_log "Running $*"
"$@"
