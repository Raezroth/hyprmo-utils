#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# include common definitions
# shellcheck source=configs/default_hooks/hyprmo_hook_icons.sh
. hyprmo_hook_icons.sh
# shellcheck source=scripts/core/hyprmo_common.sh
. hyprmo_common.sh

notificationmenu() {
	CHOICES="$icon_cls Close Menu\n$icon_del Clear Notifications"
	# shellcheck disable=SC2045
	for NOTIFFILE in $(ls -tr "$HYPRMO_NOTIFDIR"); do
		NOTIFMSG="$(tail -n+3 "$HYPRMO_NOTIFDIR/$NOTIFFILE" | tr "\n^" " ")"
		NOTIFHRANDMIN="$(stat --printf %y "$HYPRMO_NOTIFDIR/$NOTIFFILE" | grep -oE '[0-9]{2}:[0-9]{2}')"
		CHOICES="
			$CHOICES
			$NOTIFHRANDMIN $NOTIFMSG ^ $HYPRMO_NOTIFDIR/$NOTIFFILE
		"
	done

	PICKEDCONTENT="$(
		printf "%b" "$CHOICES" |
		xargs -0 echo |
		sed '/^[[:space:]]*$/d' |
		awk '{$1=$1};1' |
		cut -d^ -f1 |
		dmenu -i -p "Notifs"
	)"

	[ -z "$PICKEDCONTENT" ] && exit 1
	echo "$PICKEDCONTENT" | grep -q "Close Menu" && exit 1
	if echo "$PICKEDCONTENT" | grep -q "Clear Notifications"; then
		# merely removing the notifs won't remove
		# the inotifywait notifwatchfile. so to handle that
		# we need to open each notifwatchfile
		find "$HYPRMO_NOTIFDIR" -type f | \
			while read -r line; do
				NOTIFWATCHFILE="$(awk NR==2 "$line")"
				if [ -e "$NOTIFWATCHFILE" ]; then
					cat "$NOTIFWATCHFILE" >/dev/null
				fi
			done
		rm "$HYPRMO_NOTIFDIR"/*
		exit 1
	fi

	PICKEDNOTIFFILE="$(echo "$CHOICES" | tr -s ' ' | grep -F "$PICKEDCONTENT" | head -1 | cut -d^ -f2 | tr -d ' ')"
	NOTIFACTION="$(head -n1 "$PICKEDNOTIFFILE")"
	rm -f "$PICKEDNOTIFFILE"
	eval "$NOTIFACTION"
}

notificationmenu
