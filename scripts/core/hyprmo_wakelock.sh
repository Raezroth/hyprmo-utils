#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# shellcheck source=scripts/core/sxmo_common.sh
. hyprmo_common.sh

usage() {
		cat >&2 <<EOF
Usage: $(basename "$0") ACTION
	isenabled
	lock <lock-name> <duration|nanosec|infinite>
	unlock <lock-name>
duration: <value><unit>
value: integer
unit: ms|s|mn|h (milisec, sec, minute, hour)
EOF
}

_validint() {
	if ! echo "$1" | grep -q '^[[:digit:]]\+$'; then
		echo "$1 isn't an integer" >&2
		exit 1
	fi
}

lock() {
	if [ "$#" -ne 2 ]; then
		hyprmo_log "warning: hyprmo_wakelock.sh $*"
		usage
		exit 1
	fi

	if ! isenabled; then
		exit # we swallow when the system doesn't support it
	fi

	case "$2" in
		infinite)
			hyprmo_debug "lock $1 infinite"
			echo "$1" | doas tee -a /sys/power/wake_lock > /dev/null
			exit
			;;
		*ms)
			_validint "${2%ms}"
			set "$1" "${2%ms}000000"
			;;
		*s)
			_validint "${2%s}"
			set "$1" "${2%s}000000000"
			;;
		*mn)
			_validint "${2%mn}"
			set "$1" "$(printf "%s * 60000000000\n" "${2%mn}" | bc)"
			;;
		*h)
			_validint "${2%h}"
			set "$1" "$(printf "%s * 3600000000000\n" "${2%h}" | bc)"
			;;
	esac

	hyprmo_debug "lock $1 $2"
	echo "$1 $2" | doas tee -a /sys/power/wake_lock > /dev/null
}

unlock() {
	if [ "$#" -ne 1 ]; then
		usage
		hyprmo_log "warning: hyprmo_wakelock.sh $*"
		exit 1
	fi

	if [ ! -f /sys/power/wake_unlock ]; then
		exit # we swallow when the system doesn't support it
	fi

	hyprmo_debug "unlock $1"
	echo "$1" | doas tee -a /sys/power/wake_unlock > /dev/null 2>&1
}

isenabled() {
	[ -f /sys/power/wake_lock ]
}

cmd="$1"
shift
case "$cmd" in
	isenabled) isenabled "$@";;
	lock) lock "$@";;
	unlock) unlock "$@";;
	*)
		hyprmo_log "warning: hyprmo_wakelock.sh $*"
		usage; exit 1;;
esac
