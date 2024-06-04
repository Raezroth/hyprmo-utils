#! /bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# shellcheck source=configs/default_hooks/hyprmo_hook_icons.sh
. hyprmo_hook_icons.sh
. hyprmo_common.sh

set -e

# Find the hook by name in the current directory.
filename() {
	find "$HYPRMO_DEVICE_NAME/" . -maxdepth 1 -name "hyprmo_hook_$1.sh" | head -n1
}

copy() {
	mkdir -p "$XDG_CONFIG_HOME/hyprmo/hooks"

	cd "$XDG_CONFIG_HOME/hyprmo/hooks" || return
	file="$(filename "$1")"
	if [ ! -e "$file" ]; then
		cd "$(xdg_data_path hyprmo/default_hooks)" || return
		file="$(find "$HYPRMO_DEVICE_NAME/" . -maxdepth 1 -name "hyprmo_hook_$1.sh" | head -n1)"
		[ -e "$file" ] && cp "$file" "$XDG_CONFIG_HOME/hyprmo/hooks/$file"
	fi
}

edit() {
	copy "$1"
	cd "$XDG_CONFIG_HOME/hyprmo/hooks" || return
	file="$(filename "$1")"
	# shellcheck disable=SC2086
	hyprmo_terminal.sh $EDITOR "$XDG_CONFIG_HOME/hyprmo/hooks/$file" || true # shallow
}

reset() {
	cd "$XDG_CONFIG_HOME/hyprmo/hooks/" || return
	filename "$1" | xargs -r rm
}

removemenu() {
	while : ; do
		opt="$(grep . <<EOF | hyprmo_dmenu.sh -p "Revert to System Default"
$icon_ret Return
$(list_hooks | grep -v "^S ")
EOF
		)" || return

		case "$opt" in
			"$icon_ret Return") return;;
			*) reset "${opt#* }";;
		esac
	done
}

list_hooks() {
	user=$(mktemp)
	system=$(mktemp)

	if [ -d "$XDG_CONFIG_HOME/hyprmo/hooks" ]; then
		cd "$XDG_CONFIG_HOME/hyprmo/hooks" || return
		find . "$HYPRMO_DEVICE_NAME/" -maxdepth 1 \( -type f -o -type l \) -name 'hyprmo_hook*.sh' -exec basename {} \; |\
			sed 's/^hyprmo_hook_//g' | sed 's/\.sh$//g' |\
			sort > "$user"
	fi

	if cd "$(xdg_data_path hyprmo/default_hooks)"; then
		find . "$HYPRMO_DEVICE_NAME/" -maxdepth 1 \( -type f -o -type l \) -name 'hyprmo_hook*.sh' -exec basename {} \; |\
			sed 's/^hyprmo_hook_//g' | sed 's/\.sh$//g' |\
			sort > "$system"
	fi

	# TODO: someone please find some good icons for this
	# Present in the user directory only (not in default hooks)
	comm -23 "$user" "$system" | sed 's/^/X /g'
	# In both directories (overrideing a system hook)
	comm -12 "$user" "$system" | sed 's/^/U /g'
	# System hook only (not in the user directory)
	comm -13 "$user" "$system" | sed 's/^/S /g'

	rm "$user" "$system"
}

menu() {
	while : ; do
		hook="$(grep . <<EOF | hyprmo_dmenu.sh -p "Edit Hook"
$icon_cls Close Menu
$icon_trh Revert a Hook
$(list_hooks)
EOF
		)" || return;

		case "$hook" in
			"$icon_cls Close Menu")
				return
				;;
			"$icon_trh Revert a Hook")
				removemenu
				;;
			*)
				edit "${hook#* }"
				;;
		esac
	done
}

if [ -z "$1" ]; then
	set -- menu
fi

"$@"