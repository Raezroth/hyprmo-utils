#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# shellcheck source=configs/default_hooks/hyprmo_hook_icons.sh
. hyprmo_hook_icons.sh
# shellcheck source=scripts/core/hyprmo_common.sh
. hyprmo_common.sh

set -e

number="$(printf "%s" "$1" | sed -e "s/^tel://")"

number="$(hyprmo_validnumber.sh "$number")"

result="$(printf "%s Call %s\n%s Text %s\n%s Save %s\n%s Close Menu\n" \
	"$icon_phn" "$number" "$icon_msg" "$number" "$icon_sav" "$number" \
	"$icon_cls" \
	| hyprmo_dmenu.sh -p "Action")"

case "$result" in
	*Call*)
		hyprmo_modemdial.sh "$number"
		;;
	*Text*)
		hyprmo_modemtext.sh sendtextmenu "$number"
		;;
	*Save*)
		hyprmo_contactmenu.sh newcontact "$number"
		;;
esac
