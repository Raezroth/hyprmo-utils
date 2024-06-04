#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# This script have to be sourced from other session init scripts.
# The scripts have to implement envvars, defaults, with_dbus, and cleanup
# methods. See hyprmo_winit.sh as example.

start() {
	[ -f "$XDG_STATE_HOME"/hyprmo.log ] && mv "$XDG_STATE_HOME"/hyprmo.log "$XDG_STATE_HOME"/hyprmo.log.old

	if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
		dbus-run-session -- "$0" "with_dbus" &
	else
		# with_dbus calls exec because dbus-run-session starts it in a
		# new shell, but we need to keep this shell; start a subshell
		( with_dbus ) &
	fi
	wait
}

finish() {
	cleanup
	hyprmo_hook_stop.sh
	exit
}

init() {
	# shellcheck source=/dev/null
	. /etc/profile.d/hyprmo_init.sh

	_hpyrmo_load_environments
	_hyprmo_prepare_dirs
	envvars
	hyprmo_migrate.sh sync

	defaults

	# shellcheck disable=SC1090,SC1091
	. "$XDG_CONFIG_HOME/hyprmo/profile"

	cleanup

	trap 'finish' INT TERM EXIT
	start
}

if [ -z "$1" ]; then
	init
else
	"$1"
fi
