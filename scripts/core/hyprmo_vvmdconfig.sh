#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# shellcheck source=configs/default_hooks/hyprmo_hook_icons.sh
. hyprmo_hook_icons.sh
# shellcheck source=scripts/core/hyprmo_common.sh
. hyprmo_common.sh

set -e

alias superctl='systemctl --user'


VVM_BASE_DIR="${HYPRMO_VVM_BASE_DIR:-"$HOME"/.vvm/modemmanager}"
VVMCONFIG="$VVM_BASE_DIR/vvm"

defaultconfig() {
	cat <<EOF
[Modem Manager]
VVMEnabled=false
VVMType=type_invalid
VVMDestinationNumber=number_invalid
EOF
}

confirm() {
	printf "No\nYes\n" | dmenu -p "Are you sure ?" | grep -q "^Yes$"
}

valuemenu() {
	printf %s "$2" | dmenu -p "$1"
}

editfile() {
	FILE="$1"

	while : ; do
		CHOICE="$(grep "=" < "$FILE" |
			xargs -0 printf "$icon_ret Close Menu\n$icon_rol Default Config\n%b" |
			dmenu -p "VVM Config"
		)"

		case "$CHOICE" in
			"$icon_ret Close Menu")
				return
				;;
			"$icon_rol Default Config")
				confirm && defaultconfig > "$FILE"
				continue
				;;
		esac

		KEY="$(printf %s "$CHOICE" | cut -d= -f1)"
		VALUE="$(printf %s "$CHOICE" | cut -d= -f2-)"
		NEWVALUE="$(valuemenu "$KEY" "$VALUE")"

		sed -i "$FILE" -e "s|^$CHOICE$|$KEY=$NEWVALUE|"
	done
}

newfile() {
	tmp="$(mktemp)"
	defaultconfig > "$tmp"
	editfile "$tmp"
	mv "$tmp" "$VVMCONFIG"
}

mkdir -p "$VVM_BASE_DIR"

superctl stop vvmd

finish() {
	superctl start vvmd
}
trap 'finish' EXIT

if [ -f "$VVMCONFIG" ]; then
	editfile "$VVMCONFIG"
else
	newfile
fi
