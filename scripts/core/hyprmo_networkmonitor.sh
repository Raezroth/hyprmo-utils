#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# include common definitions
# shellcheck source=scripts/core/hyprmo_common.sh
. hyprmo_common.sh

gracefulexit() {
	hyprmo_log "gracefully exiting (on signal or after error)"
	hyprmo_jobs.sh stop network_monitor_device
	trap - INT TERM EXIT
}

trap "gracefulexit" INT TERM EXIT

getdevtype() {
	nmcli -g GENERAL.TYPE device show "$1" 2>/dev/null
}

# Send the initial states to the statusbar
nmcli -g GENERAL.TYPE,GENERAL.DEVICE d show | grep . | while read -r type; do
	read -r name || break
	hyprmo_log "$name initializing network tracking"
done

# shellcheck disable=2016
hyprmo_jobs.sh start network_monitor_device \
	nmcli device monitor | stdbuf -o0 awk '
	{ newstate=$2 }
	/device removed$/ {newstate="disconnected"}
	newstate == "unavailable" {newstate="disconnected"}

	{
		sub(":$", "", $1) # remove trailing colon from device name
		printf "%s\n%s\n", $1, newstate
	}' | while read -r devicename; do
		read -r newstate || break

		devicetype="$(getdevtype "$devicename")"
		case "$newstate" in
			"connected")
				hyprmo_log "$devicename up"
				hyprmo_hook_network_up.sh "$devicename" "$devicetype"
				;;
			"disconnected")
				hyprmo_log "$devicename down"
				hyprmo_hook_network_down.sh "$devicename" "$devicetype"
				;;
			"deactivating")
				hyprmo_hook_network_pre_down.sh "$devicename" "$devicetype"
				;;
			"connecting")
				hyprmo_hook_network_pre_up.sh "$devicename" "$devicetype"
				;;
			*)
				hyprmo_log "$devicename unknown state: $newstate"
				;;
		esac
	done
