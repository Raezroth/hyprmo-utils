#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# include common definitions
# shellcheck source=scripts/core/hyprmo_common.sh
. hyprmo_common.sh

# Create xdg user directories, such as ~/Pictures
xdg-user-dirs-update

hyprmo_jobs.sh start daemon_manager superd

# let time to superd to start correctly
while ! superctl status > /dev/null 2>&1; do
	sleep 0.5
done

# Not dangerous if "locker" isn't an available state
hyprmo_state.sh set locker

if [ -n "$HYPRMO_ROTATE_START" ]; then
	hyprmo_rotate.sh
fi

# Load our sound daemons

if [ -z "$HYPRMO_NO_AUDIO" ]; then
	if [ "$(command -v pulseaudio)" ]; then
		superctl start pulseaudio
	elif [ "$(command -v pipewire)" ]; then
		# pipewire-pulse will start pipewire
		superctl start pipewire-pulse
		superctl start wireplumber
	fi

fi

# mako/dunst are required for warnings.
# load some other little things here too.
case "$HYPRMO_WM" in
	hyprland)
		superctl start mako
		superctl start hyprmo_wob
		superctl start hyprmo_menumode_toggler
		superctl start bonsaid
		;;
esac

# Turn on auto-suspend
if hyprmo_wakelock.sh isenabled; then
	hyprmo_wakelock.sh lock hyprmo_not_suspendable infinite
	superctl start hyprmo_autosuspend
fi

# To setup initial unlock state
hyprmo_state.sh set unlock

# Turn on lisgd
if [ ! -e "$XDG_CACHE_HOME"/hyprmo/hyprmo.nogesture ]; then
	superctl start hyprmo_hook_lisgd
fi

if [ -z "$SXMO_NO_MODEM" ] && command -v ModemManager > /dev/null; then
	# Turn on the dbus-monitors for modem-related tasks
	superctl start hyprmo_modemmonitor

	# place a wakelock for 120s to allow the modem to fully warm up (eg25 +
	# elogind/systemd would do this for us, but we don't use those.)
	hyprmo_wakelock.sh lock hyprmo_modem_warming_up 120s
fi

# Start the desktop widget (e.g. clock)
superctl start hyprmo_conky

# Monitor the battery
superctl start hyprmo_battery_monitor

# It watch network changes and update the status bar icon by example
superctl start hyprmo_networkmonitor

# The daemon that display notifications popup messages
superctl start hyprmo_notificationmonitor

# Play a funky startup tune if you want (disabled by default)
#mpv --quiet --no-video ~/welcome.ogg &

# mmsd and vvmd
if [ -z "$HYPRMO_NO_MODEM" ]; then
	if [ -f "${HYPRMO_MMS_BASE_DIR:-"$HOME"/.mms/modemmanager}/mms" ]; then
		superctl start mmsd-tng
	fi

	if [ -f "${HYPRMO_VVM_BASE_DIR:-"$HOME"/.vvm/modemmanager}/vvm" ]; then
		superctl start vvmd
	fi
fi

# add some warnings if things are not setup correctly
if ! command -v "hyprmo_deviceprofile_$HYPRMO_DEVICE_NAME.sh";  then
	hyprmo_notify_user.sh --urgency=critical \
		"No deviceprofile found $HYPRMO_DEVICE_NAME. Hyprmo uses deviceprofiles from SXMO. See: https://sxmo.org/deviceprofile"
fi

hyprmo_migrate.sh state || hyprmo_notify_user.sh --urgency=critical \
	"Config needs migration" "$? file(s) in your sxmo configuration are out of date and disabled - using defaults until you migrate (run hyprmo_migrate.sh)"
