#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# small utility to prompt user for PIN and unlock mode

# shellcheck source=scripts/core/hyprmo_common.sh
. hyprmo_common.sh
# shellcheck source=configs/default_hooks/hyprmo_hook_icons.sh
. hyprmo_hook_icons.sh

set -e

while : ; do
	PICKED="$(
		cat <<EOF | hyprmo_dmenu.sh -l 3 -p "PIN:"
$icon_cls Cancel
0000
1234
EOF
	)"
	case "$PICKED" in
		"$icon_cls Cancel"|"")
			exit
			;;
		*)
			SIM="$(mmcli -m any | grep -oE 'SIM\/([0-9]+)' | cut -d'/' -f2 | head -n1)"
			MSG="$(mmcli -i "$SIM" --pin "$PICKED" 2>&1 || true)"
			[ -n "$MSG" ] && hyprmo_notify_user.sh "$MSG"
			if printf "%s\n" "$MSG" | grep -q "not SIM-PIN locked"; then
				exit
			fi
			if printf "%s\n" "$MSG" | grep -q "successfully sent PIN code to the SIM"; then
				exit
			fi
			;;
	esac
done

