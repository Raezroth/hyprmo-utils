#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# include common definitions
# shellcheck source=configs/default_hooks/hyprmo_hook_icons.sh
. hyprmo_hook_icons.sh
# shellcheck source=scripts/core/hyprmo_common.sh
. hyprmo_common.sh

set -e

VPNDEVICE="$(nmcli con show --active | grep -E 'wireguard|vpn' | awk '{ print $1 }' | paste -s -d '|')"

nofail() {
	"$@" || return 0
}

stderr() {
	sxmo_log "$*"
}

menu() {
	dmenu -i "$@"
}

notify_sucess() {
	MSG="$1"
	shift
	if "$@"; then
		hyprmo_notify_user.sh "$MSG succeed"
	else
		hyprmo_notify_user.sh "$MSG failure"
		stderr "$*"
	fi
}

connections() {
	nmcli -c no -f device,type,name -t c show | \
		sed "s/802-11-wireless:/$icon_wif /" | \
		sed "s/gsm:/$icon_mod /" | \
		sed "s/vpn*:/$icon_key /" |\
		sed "s/wireguard*:/$icon_key /" |\
		sed "s/802-3-ethernet:/$icon_usb /" | \
		sed "s/^:/$icon_dof /" |\
		sed "s/^cdc-wdm.*:/$icon_don /" |\
		sed -E "s/^$VPNDEVICE.*:/$icon_don /" |\
		sed "s/^wlan.*:/$icon_don /" |\
		sed "s/^wwan.*:/$icon_don /" |\
		sed "s/^eth.*:/$icon_don /" |\
		sed "s/^usb.*:/$icon_don /"
}

toggleconnection() {
	CONNLINE="$1"
	if echo "$CONNLINE" | grep -q "^$icon_don "; then
		CONNNAME="$(echo "$CONNLINE" | cut -d' ' -f3-)"
		notify_sucess "Disabling connection" \
			nmcli c down "$CONNNAME"
	else
		CONNNAME="$(echo "$CONNLINE" | cut -d' ' -f3-)"
		rfkill list wifi | grep -q "yes" || WIFI_ENABLED=1
		if [ "$(echo "$CONNLINE" | cut -d' ' -f2)" = "$icon_wif" ] && [ -z "$WIFI_ENABLED" ]; then
			hyprmo_notify_user.sh "Enabling wifi first."
			doas hyprmo_wifitoggle.sh
		fi
		notify_sucess "Enabling connection" \
			nmcli c up "$CONNNAME"
	fi
}

togglegsm() {
	if nmcli radio wwan | grep -q "enabled"; then
			hyprmo_notify_user.sh "Disabling GSM"
			nmcli radio wwan off
	else
			hyprmo_notify_user.sh "Enabling GSM"
			nmcli radio wwan on
	fi
}

deletenetworkmenu() {
	CHOICE="$(
		printf %b "$icon_cls Close Menu\n$(connections)" |
			menu -p "Delete Network"
	)"
	[ -z "$CHOICE" ] && return
	echo "$CHOICE" | grep -q "Close Menu" && return
	CONNNAME="$(echo "$CHOICE" | cut -d' ' -f3-)"
	notify_sucess "Deleting connection" \
		nmcli c delete "$CONNNAME"
}

getifname() {
	IFTYPE="$1"
	IFNAME="$(nmcli d | grep -m 1 "$IFTYPE" | cut -d' ' -f1)"
	if [ -z "$IFNAME" ]; then
		hyprmo_notify_user.sh "No interface with type $IFTYPE found"
		IFNAME=lo
	fi
	echo "$IFNAME"
}

addnetworkgsmmenu() {
	CONNNAME="$(
		echo "$icon_cls Close Menu" |
			hyprmo_dmenu.sh -p "Alias"
	)"
	[ -z "$CONNNAME" ] && return
	echo "$CONNNAME" | grep -q "Close Menu" && return

	APN="$(
		echo "$icon_cls Close Menu" |
			hyprmo_dmenu.sh -p "APN"
	)"
	[ -z "$APN" ] && return
	echo "$APN" | grep -q "Close Menu" && return

	USERNAME="$(printf "None\n%s Close Menu\n" "$icon_cls" | menu -p "Username")"
	case "$USERNAME" in
		""|"$icon_cls Close Menu")
			return
			;;
		None)
			unset USERNAME
			;;
	esac

	PASSWORD="$(printf "None\n%s Close Menu\n" "$icon_cls" | menu -p "Password")"
	case "$PASSWORD" in
		""|"$icon_cls Close Menu")
			return
			;;
		None)
			unset PASSWORD
			;;
	esac

	notify_sucess "Adding connection" \
		nmcli c add type gsm ifname "$(getifname gsm)" con-name "$CONNNAME" \
		apn "$APN" ${PASSWORD:+gsm.password "$PASSWORD"} \
		${USERNAME:+gsm.username "$USERNAME"}
}

addnetworkwpamenu() {
	SSID="$(cat <<EOF | hyprmo_dmenu.sh -p "SSID"
$icon_cls Close Menu
$(nmcli d wifi list | tail -n +2 | grep -v '^\*' | awk -F'  ' '{ print $6 }' | grep -v '\-\-')
EOF
	)"
	[ -z "$SSID" ] && return
	echo "$SSID" | grep -q "Close Menu" && return

	PASSPHRASE="$(cat <<EOF | hyprmo_dmenu.sh -p "Passphrase"
$icon_cls Close Menu
None
EOF
	)"

	if [ -z "$PASSPHRASE" ] || [ "None" = "$PASSPHRASE" ]; then
		unset PASSPHRASE
	fi
	echo "$PASSPHRASE" | grep -q "Close Menu" && return

	notify_sucess "Adding connection" \
		nmcli c add type wifi ifname wlan0 con-name "$SSID" ssid "$SSID" \
		${PASSPHRASE:+802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk "$PASSPHRASE"}
}

addhotspotusbmenu() {
	CONNNAME="$(
		echo "$icon_cls Close Menu" |
			hyprmo_dmenu.sh -p "Alias"
	)"
	[ -z "$CONNNAME" ] && return
	echo "$CONNNAME" | grep -q "Close Menu" && return

	# TODO: restart udhcpd after disconnecting on postmarketOS
	notify_sucess "Adding hotspot" \
		nmcli c add type ethernet ifname usb0 con-name "$CONNNAME" \
		ipv4.method shared
}

addhotspotwifimenu() {
	SSID="$(
		echo "$icon_cls Close Menu" |
			hyprmo_dmenu.sh -p "SSID"
	)"
	[ -z "$SSID" ] && return
	echo "$SSID" | grep -q "Close Menu" && return

	key="$(
		echo "$icon_cls Close Menu" |
			hyprmo_dmenu.sh -p "Passphrase"
	)"
	[ -z "$key" ] && return
	echo "$key" | grep -q "Close Menu" && return

	key1="$(
		echo "$icon_cls Close Menu" |
			hyprmo_dmenu.sh -p "Confirm"
	)"
	[ -z "$key1" ] && return
	echo "$key1" | grep -q "Close Menu" && return

	if [ "$key" != "$key1" ]; then
		hyprmo_notify_user.sh "key mismatch"
		return
	fi

	# valid keys for WPA networks have a lengths of 8-63 characters
	keylen=$( echo "$key" | tr -d '\n' | wc -c )
	keylen=$(( keylen ))
	if [ $keylen -lt 8 ]; then
		hyprmo_notify_user.sh "key too short ($keylen < 8)"
		return
	elif [ $keylen -gt 63 ]; then
		hyprmo_notify_user.sh "key too long ($keylen > 63)"
		return
	fi

	channel="$(
		printf "%s Close Menu\n11\n" "$icon_cls" | hyprmo_dmenu.sh -p "Channel"
	)"
	[ -z "$channel" ] && return
	echo "$channel" | grep -q "Close Menu" && return

	notify_sucess "Adding hotspot wifi" \
		nmcli device wifi hotspot ifname wlan0 con-name "Hotspot $SSID" \
		ssid "$SSID" channel "$channel" band bg password "$key"
}

networksmenu() {
	while true; do
		CHOICE="$(
			rfkill list wifi | grep -q "yes" || WIFI_ENABLED=1

			grep . << EOF | hyprmo_dmenu.sh -p "Networks"
$icon_cls Close Menu
$(
	if [ -z "$WIFI_ENABLED" ]; then
		connections | grep -v "$icon_wif"
	else
		connections
	fi
)
$icon_mod Add a GSM Network
$([ -z "$WIFI_ENABLED" ] || printf "%s Add a WPA Network\n" "$icon_wif")
$([ -z "$WIFI_ENABLED" ] || printf "%s Add a Wifi Hotspot\n" "$icon_wif")
$icon_usb Add a USB Hotspot
$icon_cls Delete a Network
$(
	if [ -z "$WIFI_ENABLED" ]; then
		printf "%s Enable Wifi\n" "$icon_wif"
	else
		printf "%s Disable Wifi\n" "$icon_wif"
	fi
)
$icon_cfg Nmtui
$(
	if nmcli radio wwan | grep -q "enabled"; then
			printf "%s Disable GSM\n" $icon_modem_disabled
	else
			printf "%s Enable GSM\n" $icon_modem_registered
	fi
)
$icon_cfg Ifconfig
$([ -z "$WIFI_ENABLED" ] || printf "%s Scan Wifi Networks\n" "$icon_wif")
EOF
		)" || exit

		case "$CHOICE" in
			*"Close Menu" )
				exit
				;;
			*"Add a GSM Network" )
				addnetworkgsmmenu
				;;
			*"Add a WPA Network" )
				addnetworkwpamenu
				;;
			*"Add a Wifi Hotspot" )
				addhotspotwifimenu
				;;
			*"Add a USB Hotspot")
				addhotspotusbmenu
				;;
			*"Delete a Network" )
				deletenetworkmenu
				;;
			*"Nmtui" )
				hyprmo_terminal.sh nmtui || continue # Killeable
				;;
			*"Disable GSM"|*"Enable GSM" )
				togglegsm
				;;
			*"Ifconfig" )
				hyprmo_terminal.sh watch -n 2 ifconfig || continue # Killeable
				;;
			*"Scan Wifi Networks" )
				hyprmo_terminal.sh watch -n 2 nmcli d wifi list || continue # Killeable
				;;
			*"Disable Wifi"|*"Enable Wifi" )
				doas hyprmo_wifitoggle.sh
				;;
			*)
				toggleconnection "$CHOICE"
				;;
		esac
	done
}

if [ $# -gt 0 ]; then
	"$@"
else
	networksmenu
fi
