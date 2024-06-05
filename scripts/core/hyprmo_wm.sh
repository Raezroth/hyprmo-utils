#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. hyprmo_common.sh

hyprlanddpms() {
	STATE=off
	if ! hyprctl monitors \
		| jq ".[] | .dpms" \
		| grep -q "true"; then
		STATE=on
	fi

	if [ -z "$1" ]; then
		printf %s "$STATE"
	elif [ "$1" = on ] && [ "$STATE" != on ]; then
		hyprctl keyword monitor DSI-1,disable
	elif [ "$1" = off ] && [ "$STATE" != off ] ; then
		hyprctl keyword monitor DSI-1,preferred,auto,1,transform,3
	fi

}

hyprlandinputevent() {
	if [ "$1" = "touchscreen" ]; then
		TOUCH_POINTER_ID="touch"
	elif [ "$1" = "stylus" ]; then
		TOUCH_POINTER_ID="tablet_tool"
	fi

	# If we dont have any matching input
	if ! hyprctl monitors \
		| jq -r ".[] | select(.type == \"$TOUCH_POINTER_ID\" )" \
		| grep -q .; then

		if [ -z "$2" ]; then
			printf "not found"
			exit 0
		else
			exit 0
		fi
	fi

	STATE=on
	if hyprctl devices \
		| jq -r ".[] | select(.type == \"$TOUCH_POINTER_ID\" ) | .libinput.send_events" \
		| grep -q "disabled"; then
		STATE=off
	fi

	if [ -z "$2" ]; then
		printf %s "$STATE"
	elif [ "$2" = on ] && [ "$STATE" != on ]; then
		hyprctl keyword "device[$TOUCH_POINTER_ID]:enabled" true
		#swaymsg -- input type:"$TOUCH_POINTER_ID" events enabled
	elif [ "$2" = off ] && [ "$STATE" != off ] ; then
		#swaymsg -- input type:"$TOUCH_POINTER_ID" events disabled
		hyprctl keyword "device[$TOUCH_POINTER_ID]:disabled" true
	fi
}

hyprlandfocusedwindow() {
	hyprctl activewindow | jq -r '
		recurse(.nodes[]) |
		select(.focused == true) |
		{
			app_id: (if .app_id != null then
					.app_id
				else
					.window_properties.class
				end),
			name: .name,
		} |
		select(.app_id != null and .name != null) |
		"app: " + .app_id, "title: " + .name
	'
}

hyprlandpaste() {
	wl-paste
}

hyprlandexec() {
	hyprctl dispatch exec -- "$@"
}

hyprlandexecwait() {
	PIDFILE="$(mktemp)"
	printf '"%s" & printf %%s "$!" > "%s"' "$*" "$PIDFILE" \
		| xargs -I{} swaymsg exec -- '{}'
	while : ; do
		sleep 0.5
		kill -0 "$(cat "$PIDFILE")" 2> /dev/null || break
	done
	rm "$PIDFILE"
}

hyprlandtogglelayout() {
#	swaymsg layout toggle splith splitv tabbed
}

hyprlandswitchfocus() {
	hyprmo_wmmenu.sh hyprlandwindowswitcher
}
_hyprlandgetcurrentworkspace() {
	hyprctl workspaces  | \
		jq -r 'workspace ID'
}

_hyprlandgetnextworkspace() {
	value="$(($(_hyprlandgetcurrentworkspace)+1))"
	if [ "$value" -eq "$((${HYPRMO_WORKSPACE_WRAPPING:-4}+1))" ]; then
		printf 1
	else
		printf %s "$value"
	fi
}

_hyprlandgetpreviousworkspace() {
	value="$(($(_hyprlandgetcurrentworkspace)-1))"
	if [ "$value" -lt 1 ]; then
		if [ "${HYPRMO_WORKSPACE_WRAPPING:-4}" -ne 0 ]; then
			printf %s "${HYPRMO_WORKSPACE_WRAPPING:-4}"
		else
			return 1 # cant have previous workspace
		fi
	else
		printf %s "$value"
	fi
}

hyprlandnextworkspace() {
	hyprctl dispatch "workspace $(_hyprlandgetnextworkspace)"
}

hyprlandpreviousworkspace() {
	_hyprlandgetpreviousworkspace | xargs -r hyprctl dispatch workspace
}

hyprlandmovenextworkspace() {
	hyprctl dispatch "movetoworkspace $(_hyprlandgetnextworkspace)"
}

hyprlandmovepreviousworkspace() {
	_hyprlandgetpreviousworkspace | xargs -r hyprctl dispatch movetoworkspace
}

hyprlandworkspace() {
	hyprctl "workspace $1"
}

hyprlandmoveworkspace() {
	hyprctl dispatch"movetoworkspace $1"
}

action="$1"
shift
case "$HYPRMO_WM" in
	*) "$HYPRMO_WM$action" "$@";;
esac
