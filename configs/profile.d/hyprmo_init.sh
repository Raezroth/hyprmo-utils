#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# This script is meant to be sourced on login shells
# shellcheck source=scripts/core/hyprmo_common.sh
. hyprmo_common.sh

_hyprmo_is_running() {
	unset HYPRMO_WM

	_XDG_RUNTIME_DIR="$(_hyprmo_find_runtime_dir)"

	if [ -f "${_XDG_RUNTIME_DIR}"/hypr ]; then
		if SWAYSOCK="$(cat "${_XDG_RUNTIME_DIR}"/hypr/*/.socket.sock)" hyprctl 2>/dev/null
		then
			printf "Detected the Hyprland environment\n" >&2
			export HYPRMO_WM=hyprland
			unset _XDG_RUNTIME_DIR
			return 0
		fi
	fi
	unset _XDG_RUNTIME_DIR

	printf "Hyprmo is not running\n" >&2
	return 1
}

_hyprmo_find_runtime_dir() {
	# Take what we gave to you
	if [ -n "$XDG_RUNTIME_DIR" ]; then
		printf %s "$XDG_RUNTIME_DIR"
		return
	fi

	# Try something existing
	for root in /run /var/run; do
		path="$root/user/$(id -u)"
		if [ -d "$path" ] && [ -w "$path" ]; then
			printf %s "$path"
			return
		fi
	done

	if command -v mkrundir > /dev/null 2>&1; then
		mkrundir
		return
	fi

	# Fallback to a shared memory location
	printf "/dev/shm/user/%s" "$(id -u)"
}

_hyprmo_load_environments() {
	# Determine current operating system see os-release(5)
	# https://www.linux.org/docs/man5/os-release.html
	if [ -e /etc/os-release ]; then
		# shellcheck source=/dev/null
		. /etc/os-release
	elif [ -e /usr/lib/os-release ]; then
		# shellcheck source=/dev/null
		. /usr/lib/os-release
	fi
	export HYPRMO_OS="${ID:-unknown}"

	export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
	export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
	export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
	XDG_RUNTIME_DIR="$(_hyprmo_find_runtime_dir)"
	export XDG_RUNTIME_DIR
	export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
	export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

	export HYPRMO_CACHEDIR="${SXMO_CACHEDIR:-$XDG_CACHE_HOME/hyprmo}"

	export HYPRMO_BLOCKDIR="${SXMO_BLOCKDIR:-$XDG_DATA_HOME/hyprmo/block}"
	export HYPRMO_BLOCKFILE="${SXMO_BLOCKFILE:-$XDG_CONFIG_HOME/hyprmo/block.tsv}"
	export HYPRMO_CONTACTFILE="${SXMO_CONTACTFILE:-$XDG_CONFIG_HOME/hyprmo/contacts.tsv}"
	export HYPRMO_STATE="${SXMO_STATE:-$XDG_RUNTIME_DIR/hyprmo.state}"
	export HYPRMO_LOGDIR="${SXMO_LOGDIR:-$XDG_DATA_HOME/hyprmo/modem}"
	export HYPRMO_NOTIFDIR="${SXMO_NOTIFDIR:-$XDG_DATA_HOME/hyprmo/notifications}"

	export BEMENU_OPTS="${BEMENU_OPTS:---ab "#222222" --af "#bbbbbb" --bdr "#005577" --border 3 --cb "#222222" --center --cf "#bbbbbb" --fb "#222222" --fbb "#eeeeee" --fbf "#222222" --ff "#bbbbbb" --fixed-height --fn 'Sxmo 14' --hb "#005577" --hf "#eeeeee" --line-height 20 --list 16 --margin 40 --nb "#222222" --nf "#bbbbbb" --no-overlap --no-spacing --sb "#323232" --scb "#005577" --scf "#eeeeee" --scrollbar autohide --tb "#005577" --tf "#eeeeee" --wrap}"

	export EDITOR="${EDITOR:-vim}"
	export BROWSER="${BROWSER:-firefox}"
	export SHELL="${SHELL:-/bin/sh}"

	# The user can already force a $HYPRMO_DEVICE_NAME value in ~/.profile
	if [ -z "$HYPRMO_DEVICE_NAME" ]; then
		if [ -e /proc/device-tree/compatible ]; then
			HYPRMO_DEVICE_NAME="$(tr -c '\0[:alnum:].,-' '_' < /proc/device-tree/compatible |
				tr '\0' '\n' | head -n1)"
		else
			HYPRMO_DEVICE_NAME=desktop
		fi
	fi
	export HYPRMO_DEVICE_NAME

	deviceprofile="$(command -v "sxmo_deviceprofile_$HYPRMO_DEVICE_NAME.sh")"
	# shellcheck disable=SC1090
	if [ -f "$deviceprofile" ]; then
		. "$deviceprofile"
		printf "deviceprofile file %s loaded.\n" "$deviceprofile"
	else
		printf "WARNING: deviceprofile file not found for %s. Most device functions will not work. Devicesprofiies are pulled from sxmo or manually written. Please read: https://sxmo.org/deviceprofile \n" "$HYPRMO_DEVICE_NAME"

		# on a new device, power button won't work
		# so make sure we don't go into screenoff
		# or suspend
		touch "$XDG_CACHE_HOME"/hyprmo/hyprmo.nosuspend
		touch "$XDG_CACHE_HOME"/hyprmo/hyprmo.noidle
	fi
	unset deviceprofile

	PATH="\
$XDG_CONFIG_HOME/hyprmo/hooks/$HYPRMO_DEVICE_NAME:\
$XDG_CONFIG_HOME/hyprmo/hooks:\
$(xdg_data_path "hyprmo/default_hooks" 0 ':'):\
$PATH"
	export PATH
}

_hyprmo_grab_session() {
	if ! _hyprmo_is_running; then
		return
	fi

	XDG_RUNTIME_DIR="$(_hyprmo_find_runtime_dir)"
	export XDG_RUNTIME_DIR

	_hyprmo_load_environments

	if [ -f "$XDG_RUNTIME_DIR"/dbus.bus ]; then
		DBUS_SESSION_BUS_ADDRESS="$(cat "$XDG_RUNTIME_DIR"/dbus.bus)"
		export DBUS_SESSION_BUS_ADDRESS
		if ! dbus-send --dest=org.freedesktop.DBus \
			/org/freedesktop/DBus org.freedesktop.DBus.ListNames \
			2> /dev/null; then
				printf "WARNING: The dbus-send test failed with DBUS_SESSION_BUS_ADDRESS=%s. Unsetting...\n" "$DBUS_SESSION_BUS_ADDRESS" >&2
				unset DBUS_SESSION_BUS_ADDRESS
		fi
	else
		printf "WARNING: No dbus cache file found at %s/dbus.bus.\n" "$XDG_RUNTIME_DIR" >&2
	fi

	# We dont export DISPLAY and WAYLAND_DISPLAY on purpose
	case "$HYPRMO_WM" in
		hyprland)
			if [ -f "$XDG_RUNTIME_DIR"/hypr/*/.socket.sock ]; then
				HYPRSOCK="$(cat "$XDG_RUNTIME_DIR"/hypr/*/.socket.sock)"
				export HYPRSOCK
			fi
			;;
	esac
}

_hyprmo_prepare_dirs() {
	uid=$(id -u)
	gid=$(id -g)
	mkdir -p "$XDG_RUNTIME_DIR"
	chmod 700 "$XDG_RUNTIME_DIR"
	chown "$uid:$gid" "$XDG_RUNTIME_DIR"

	mkdir -p "$XDG_CACHE_HOME/hyprmo/"
	chmod 700 "$XDG_CACHE_HOME"
	chown "$uid:$gid" "$XDG_CACHE_HOME"

	mkdir -p "$XDG_STATE_HOME"
	chmod 700 "$XDG_STATE_HOME"
	chown "$uid:$gid" "$XDG_STATE_HOME"
}

_hyprmo_grab_session
