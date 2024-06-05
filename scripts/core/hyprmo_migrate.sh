#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# include common definitions
# shellcheck source=scripts/core/hyprmo_common.sh
. hyprmo_common.sh

if [ -z "$HYPRMO_DEVICE_NAME" ]; then
	. /etc/profile.d/hyprmo_init.sh
	# not grabbed
	if [ -z "$HYPRMO_DEVICE_NAME" ]; then
		_hyprmo_load_environments
	fi
fi

smartdiff() {
	if command -v colordiff > /dev/null; then
		colordiff "$@"
	else
		diff "$@"
	fi
}

fetchversion() {
	head -n5 "$1" | grep -m1 "configversion: " | sed 's|.*configversion: \(.*\)|\1|'
}

resolvedifference() {
	userfile="$1"
	defaultfile="$2"

	(
		printf "\e[31mThe file \e[32m%s\e[31m differs\e[0m\n" "$userfile"
		smartdiff -ud "$defaultfile" "$userfile"
	) | more

	printf "\e[31mMigration options for \e[32m%s\e[31m:\e[0m\n" "$userfile"

	printf "1 - Use [d]efault. Apply the Hyprmo default, discarding all your own changes.\n"
	printf "2 - Open [e]ditor and merge the changes yourself; take care to set the same configversion.\n"
	printf "3 - Use your [u]ser version as-is; you verified it's compatible. (Auto-updates configversion only).\n"
	printf "4 - [i]gnore, do not resolve and don't change anything, ask again next time. (default)\n"

	printf "\e[33mHow do you want to resolve this? Choose one of the options above [1234deui]\e[0m "

	read -r reply < /dev/tty
	abort=0
	case "$reply" in
		[1dD]*)
			#use default
			case "$userfile" in
				*hooks*)
					#just remove the user hook, will use default automatically
					rm "$userfile"
					abort=1 #no need for any further cleanup
					;;
				*)
					cp "$defaultfile" "$userfile" || abort=1
					;;
			esac
			;;
		[2eE]*)
			#open editor with both files and the diff
			export DIFFTOOL="${DIFFTOOL:-vimdiff}"
			if [ -n "$DIFFTOOL" ] && command -v "$DIFFTOOL" >/dev/null; then # ex vimdiff
				set -- "$DIFFTOOL" "$defaultfile" "$userfile"
			else
				diff -u "$defaultfile" "$userfile" > "${XDG_RUNTIME_DIR}/migrate.diff"
				# shellcheck disable=SC2086
				set -- $EDITOR "$userfile" "$defaultfile" "${XDG_RUNTIME_DIR}/migrate.diff"
			fi

			if ! "$@"; then
				#user may bail editor, in which case we ignore everything
				abort=1
			fi

			if [ -z "$DIFFTOOL" ]; then
				rm "${XDG_RUNTIME_DIR}/migrate.diff"
			fi
			;;
		[3uU]*)
			#update configversion automatically
			refversion="$(fetchversion "$defaultfile")"
			userversion="$(fetchversion "$userfile")"
			if [ -n "$userversion" ]; then
				sed -i "s/configversion: $userversion/configversion: $refversion/" "$userfile" || abort=1
			elif [ -n "$refversion" ]; then
				refline="$(head -n5 "$defaultfile" | grep -m1 "configversion: ")"
				# fall back in case the userfile doesn't contain a configversion at all yet
				sed -i "2i$refline" "$userfile" || abort=1
			fi
			;;
		*)
			abort=1
			;;
	esac

	if [ "$abort" -eq 0 ]; then
		#finish the migration, removing .needs-migration and moving to right place
		case "$userfile" in
			*needs-migration)
				mv -f "$userfile" "${userfile%.needs-migration}"
				;;
		esac
	fi
	printf "\n"
}

checkconfigversion() {
	userfile="$1"
	reffile="$2"
	if [ ! -e "$userfile" ] || [ ! -e "$reffile" ]; then
		#if the userfile doesn't exist then we revert to default anyway so it's considered up to date
		return 0
	fi

	refversion="$(fetchversion "$reffile")"
	if [ -z "$refversion" ]; then
		#no ref version found, check file diff instead
		if diff "$reffile" "$userfile" > /dev/null; then
			return 0
		else
			return 1
		fi
	fi

	userversion="$(fetchversion "$userfile")"
	if [ -z "$userversion" ]; then
		#no user version found, check file contents instead
		tmpreffile="${XDG_RUNTIME_DIR}/versioncheck"
		grep -v "configversion: " "$reffile" > "$tmpreffile"
		if diff "$tmpreffile" "$userfile" > /dev/null; then
			rm "$tmpreffile"
			return 0
		else
			rm "$tmpreffile"
			return 1
		fi
	fi

	[ "$refversion" = "$userversion" ]
}

defaultconfig() {
	defaultfile="$1"
	userfile="$2"
	filemode="$3"
	if [ -e "$userfile.needs-migration" ] && { [ "$MODE" = "interactive" ] || [ "$MODE" = "all" ]; }; then
		resolvedifference "$userfile.needs-migration" "$defaultfile"
		chmod "$filemode" "$userfile" 2> /dev/null
	elif [ ! -r "$userfile" ]; then
		mkdir -p "$(dirname "$userfile")"
		hyprmo_log "Installing default configuration $userfile..."
		cp "$defaultfile" "$userfile"
		chmod "$filemode" "$userfile"
	elif [ "$MODE" = "reset" ]; then
		if [ ! -e "$userfile.needs-migration" ]; then
			mv "$userfile" "$userfile.needs-migration"
		else
			hyprmo_log "$userfile was already flagged for needing migration; not overwriting the older one"
		fi
		cp "$defaultfile" "$userfile"
		chmod "$filemode" "$userfile"
	elif ! checkconfigversion "$userfile" "$defaultfile" || [ "$MODE" = "all" ]; then
		case "$MODE" in
			"interactive"|"all")
				resolvedifference "$userfile" "$defaultfile"
				;;
			"sync")
				hyprmo_log "$userfile is out of date, disabling and marked as needing migration..."
				[ ! -e "$userfile.needs-migration" ] && cp "$userfile" "$userfile.needs-migration" #never overwrite older .needs-migration files, they take precendence
				chmod "$filemode" "$userfile.needs-migration"
				cp "$defaultfile" "$userfile"
				chmod "$filemode" "$userfile"
				;;
		esac
	fi
}

checkhooks() {
	if ! [ -e "$XDG_CONFIG_HOME/hyprmo/hooks/" ]; then
		return
	fi
	for hook in \
		"$XDG_CONFIG_HOME/hyprmo/hooks/"* \
		${HYPRMO_DEVICE_NAME:+"$XDG_CONFIG_HOME/hyprmo/hooks/$HYPRMO_DEVICE_NAME/"*}; do
		{ [ -e "$hook" ] && [ -f "$hook" ];} || continue #sanity check because shell enters loop even when there are no files in dir (null glob)

		[ -h "$hook" ] && continue # shallow symlink

		if printf %s "$hook" | grep -q "/$HYPRMO_DEVICE_NAME/"; then
			# We also compare the device user hook to the system
			# default version
			DEFAULT_PATH="$(xdg_data_path hyprmo/default_hooks/"$HYPRMO_DEVICE_NAME"/):$(xdg_data_path hyprmo/default_hooks/)"
		else
			# We dont want to compare a default user hook to the device
			# system version
			DEFAULT_PATH="$(xdg_data_path hyprmo/default_hooks/)"
		fi

		if [ "$MODE" = "reset" ]; then
			if [ ! -e "$hook.needs-migration" ]; then
				mv "$hook" "$hook.needs-migration" #move the hook away
			else
				hyprmo_log "$hook was already flagged for needing migration; not overwriting the older one"
				rm "$hook"
			fi
			continue
		fi
		case "$hook" in
			*.needs-migration)
				defaulthook="$(PATH="$DEFAULT_PATH" command -v "$(basename "$hook" ".needs-migration")")"
				[ "$MODE" = sync ] && continue # ignore this already synced hook
				;;
			*.backup)
				#skip
				continue
				;;
			*)
				#if there is already one marked as needing migration, use that one instead and skip this one
				[ -e "$hook.needs-migration" ] && continue
				defaulthook="$(PATH="$DEFAULT_PATH" command -v "$(basename "$hook")")"
				;;
		esac
		if [ -f "$defaulthook" ]; then
			if diff "$hook" "$defaulthook" > /dev/null && [ "$MODE" != "sync" ]; then
				printf "\e[33mHook %s is identical to the default, so you don't need a custom hook, remove it? [y/N]\e[0m" "$hook"
				read -r reply < /dev/tty
				if [ "y" = "$reply" ]; then
					rm "$hook"
				fi
			elif ! checkconfigversion "$hook" "$defaulthook" || [ "$MODE" = "all" ]; then
				case "$MODE" in
					"interactive"|"all")
						resolvedifference "$hook" "$defaulthook"
						;;
					"sync")
						sxmo_log "$hook is out of date, disabling and marked as needing migration..."
						#never overwrite older .needs-migration files, they take precendence
						if [ ! -e "$hook.needs-migration" ]; then
							mv "$hook" "$hook.needs-migration"
						else
							rm "$hook"
						fi
						;;
				esac
			fi
		elif [ "$MODE" != "sync" ]; then
			(
				smartdiff -ud "/dev/null" "$hook"
				printf "\e[31mThe hook \e[32m%s\e[31m does not exist (anymore), remove it? [y/N] \e[0m\n" "$hook"
			) | more
			read -r reply < /dev/tty
			if [ "y" = "$reply" ]; then
				rm "$hook"
			fi
			printf "\n"
		fi
	done
}

common() {
	defaultconfig "$(xdg_data_path hyprmo/appcfg/profile_template)" "$XDG_CONFIG_HOME/hyprmo/profile" 644
	defaultconfig "$(xdg_data_path hyprmo/appcfg/fontconfig.conf)" "$XDG_CONFIG_HOME/fontconfig/conf.d/50-hyprmo.conf" 644
}

hyprland() {
	defaultconfig "$(xdg_data_path hyprmo/appcfg/hyperland.conf)" "$XDG_CONFIG_HOME/hypr/hyprland.conf" 644
	defaultconfig "$(xdg_data_path hyprmo/appcfg/foot.ini)" "$XDG_CONFIG_HOME/foot/foot.ini" 644
	defaultconfig "$(xdg_data_path hyprmo/appcfg/waybar_config)" "$XDG_CONFIG_HOME/waybar/config" 644
	defaultconfig "$(xdg_data_path hyprmo/appcfg/mako.conf)" "$XDG_CONFIG_HOME/mako/config" 644
	defaultconfig "$(xdg_data_path hyprmo/appcfg/bonsai_tree.json)" "$XDG_CONFIG_HOME/hyprmo/bonsai_tree.json" 644
	defaultconfig "$(xdg_data_path hyprmo/appcfg/wob.ini)" "$XDG_CONFIG_HOME/wob/wob.ini" 644
	defaultconfig "$(xdg_data_path hyprmo/appcfg/conky.conf)" "$XDG_CONFIG_HOME/hyprmo/conky.conf" 644
}


#set default mode
[ -z "$*" ] && set -- interactive

# Don't allow running with sudo, or as root
if [ -n "$SUDO_USER" ]; then
	echo "$0 can't be run with sudo, it must be run as your user" >&2
	exit 127
fi

if [ "$USER" = "root" ]; then
	echo "$0 can't be run as root, it must be run as your user" >&2
	exit 127
fi

# Execute idempotent migrations
find "$(xdg_data_path hyprmo/migrations)" -type f | sort -n | tr '\n' '\0' | xargs -0 sh

if [ -z "$*" ]; then
	set -- sync interactive
fi

#modes may be chained
for MODE in "$@"; do
	case "$MODE" in
		"interactive"|"all")
			common
			hyprland
			xorg
			checkhooks
			;;
		"sync"|"reset")
			case "$HYPRMO_WM" in
				hyprland)
					common
					hyprland
					;;
				*)
					common
					hyprland
					xorg
					;;
			esac

			checkhooks
			;;
		"state")
			NEED_MIGRATION="$(find "$XDG_CONFIG_HOME/" -name "*.needs-migration")"
			if [ -n "$NEED_MIGRATION" ]; then
				hyprmo_log "The following configuration files need migration: $NEED_MIGRATION"
				exit "$(echo "$NEED_MIGRATION" | wc -l)" #exit code represents number of files needing migration
			else
				hyprmo_log "All configuration files are up to date"
			fi
			;;
		*)
			hyprmo_log "Invalid mode: $MODE"
			exit 2
			;;
	esac
done
