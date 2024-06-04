#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors
# shellcheck disable=SC2086

if [ -z "$*" ]; then
	set -- $SHELL
fi

if [ -z "$TERMNAME" ]; then
	TERMNAME="$*"
fi

case "$HYPRMO_TERMINAL" in
	"st"*)
		set -- $HYPRMO_TERMINAL -T "$TERMNAME" -e "$@"
		;;
	"tilix"*)
		set -- $HYPRMO_TERMINAL -t "$TERMNAME" -e "$@"
		;;
	"foot"*)
		set -- $HYPRMO_TERMINAL -T "$TERMNAME" "$@"
		;;
	"vte-2.91"*)
		set -- ${HYPRMO_TERMINAL% --} --title "$TERMNAME" -- "$@"
		;;
	"alacritty"*)
		# Test if alacritty was called with shell or a program
		# Even with dynamic_title = true in config title will be static with -T switch
		if [ "$*" = "$SHELL" ]; then
			set -- $HYPRMO_TERMINAL
		else
			set -- $HYPRMO_TERMINAL -T "$TERMNAME" -e "$@"
		fi
		;;
	*)
		printf "%s: '%s'\n" "Not implemented for SXMO_TERMINAL" "$HYPRMO_TERMINAL" >&2
		set -- $HYPRMO_TERMINAL "$@"
esac

exec "$@"
