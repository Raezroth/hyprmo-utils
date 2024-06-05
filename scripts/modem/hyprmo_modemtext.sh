#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# include common definitions
# shellcheck source=configs/default_hooks/hyprmo_hook_icons.sh
. hyprmo_hook_icons.sh
# shellcheck source=scripts/core/hyprmo_common.sh
. hyprmo_common.sh

set -e

err() {
	sxmo_log "$1"
	echo "$1" | dmenu
	kill $$
}

choosenumbermenu() {
	# Prompt for number
	NUMBER="$(
		printf %b "\n$icon_cls Cancel\n$icon_grp More contacts\n$(hyprmo_contacts.sh | grep -E "\+[0-9]+$")" |
		awk NF |
		hyprmo_dmenu.sh -p "Number" -i |
		cut -d: -f2 |
		tr -d -- '- '
	)"

	if echo "$NUMBER" | grep -q "Morecontacts"; then
		NUMBER="$( #joined words without space is not a bug
			printf %b "\nCancel\n$(hyprmo_contacts.sh --all)" |
				grep . |
				hyprmo_dmenu.sh -p "Number" -i |
				cut -d: -f2 |
				tr -d -- '- '
		)"
	fi

	if printf %s "$NUMBER" | grep -q "Cancel"; then
		exit 1
	elif NUMBER="$(hyprmo_validnumber.sh "$NUMBER")"; then
		printf %s "$NUMBER"
	else
		hyprmo_notify_user.sh "That doesn't seem like a valid number"
	fi
}

sendtextmenu() {
	if [ -n "$1" ]; then
		NUMBER="$1"
	else
		NUMBER="$(choosenumbermenu)"
	fi

	[ -z "$NUMBER" ] && exit 1

	DRAFT="$HYPRMO_LOGDIR/$NUMBER/draft.txt"
	if [ ! -f "$DRAFT" ]; then
		mkdir -p "$(dirname "$DRAFT")"
		echo "$HYPRMO_DEFAULT_DRAFT" > "$DRAFT"
	fi

	# shellcheck disable=SC2086
	hyprmo_terminal.sh $EDITOR "$DRAFT"

	while true
	do
		# We use them in printf statements
		export icon_cls
		export icon_att
		export icon_usr

		ATTACHMENTS=
		if [ -f "$HYPRMO_LOGDIR/$NUMBER/draft.attachments.txt" ]; then
			# shellcheck disable=SC2016
			ATTACHMENTS="$(
				tr '\n' '\0' < "$HYPRMO_LOGDIR/$NUMBER/draft.attachments.txt" |
				xargs -0 -I{} sh -c 'printf "%s %s %s :: %s\n" "$icon_cls" "$icon_att" "$(basename "{}")" "{}"'
			)"
		fi

		RECIPIENTS=
		if [ "$(printf %s "$NUMBER" | xargs pnc find | wc -l)" -gt 1 ]; then
			# shellcheck disable=SC2016
			RECIPIENTS="$(printf %s "$NUMBER" | xargs pnc find | xargs -I{} sh -c 'printf "$icon_cls $icon_usr "$(hyprmo_contacts.sh --name {})" :: {}\n"')"
		fi

		CHOICES="$(printf "%s Send to %s (%s)\n%b\n%s Add Recipient\n%b\n%s Add Attachment\n%s Edit '%s'\n%s Cancel\n" \
			"$icon_snd" "$(hyprmo_contacts.sh --name "$NUMBER")" "$NUMBER" "$RECIPIENTS" "$icon_usr" "$ATTACHMENTS" "$icon_att" "$icon_edt" \
			"$(cat "$HYPRMO_LOGDIR/$NUMBER/draft.txt")" "$icon_cls" \
			| awk NF
		)"

		CONFIRM="$(printf %b "$CHOICES" | dmenu -i -p "Confirm")"
		case "$CONFIRM" in
			*"Send"*)
				if hyprmo_modemsendsms.sh "$NUMBER" -f "$DRAFT"; then
					rm "$DRAFT"
					hyprmo_log "Sent text to $NUMBER"
					exit 0
				else
					err "Failed to send txt to $NUMBER"
				fi
				;;
			# Remove Attachment
			"$icon_cls $icon_att"*)
				FILE="$(printf %s "$CONFIRM" | awk -F' :: ' '{print $2}')"
				sed -i "\|$FILE|d" "$HYPRMO_LOGDIR/$NUMBER/draft.attachments.txt"
				if [ ! -s "$HYPRMO_LOGDIR/$NUMBER/draft.attachments.txt" ] ; then
					rm "$HYPRMO_LOGDIR/$NUMBER/draft.attachments.txt"
				fi
				;;
			# Remove Recipient
			"$icon_cls $icon_usr"*)
				if [ "$(printf %s "$NUMBER" | xargs pnc find | wc -l)" -gt 1 ]; then
					OLDNUMBER="$NUMBER"
					RECIPIENT="$(printf %s "$CONFIRM" | awk -F' :: ' '{print $2}')"
					NUMBER="$(printf %s "$OLDNUMBER" | sed "s/$RECIPIENT//")"
					mkdir -p "$HYPRMO_LOGDIR/$NUMBER"
					DRAFT="$HYPRMO_LOGDIR/$NUMBER/draft.txt"
					if [ -f "$HYPRMO_LOGDIR/$OLDNUMBER/draft.txt" ]; then
						# TODO: if there is already a DRAFT warn the user?
						mv "$HYPRMO_LOGDIR/$OLDNUMBER/draft.txt" "$DRAFT"
					fi
					if [ -f "$HYPRMO_LOGDIR/$OLDNUMBER/draft.attachments.txt" ]; then
						mv "$HYPRMO_LOGDIR/$OLDNUMBER/draft.attachments.txt" \
							"$HYPRMO_LOGDIR/$NUMBER/draft.attachments.txt"
					fi
					[ -e "$HYPRMO_LOGDIR/$NUMBER/sms.txt" ] || touch "$HYPRMO_LOGDIR/$NUMBER/sms.txt"
					hyprmo_hook_tailtextlog.sh "$NUMBER" &
				fi
				;;
			*"Edit"*)
				sendtextmenu "$NUMBER"
				;;
			*"Add Attachment")
				ATTACHMENT="$(hyprmo_files.sh "$HOME" --select-only)"
				if [ -f "$ATTACHMENT" ]; then
					printf "%s\n" "$ATTACHMENT" >> "$HYPRMO_LOGDIR/$NUMBER/draft.attachments.txt"
				fi
				;;
			*"Add Recipient")
				OLDNUMBER="$NUMBER"
				ADDEDNUMBER="$(choosenumbermenu)"

				if ! echo "$ADDEDNUMBER" | grep -q '^+'; then
					echo "We can't add numbers that don't start with +"
				elif echo "$OLDNUMBER" | grep -q "$ADDEDNUMBER"; then
					echo "Number already a recipient."
				else
					NUMBER="$(printf %s%s "$NUMBER" "$ADDEDNUMBER" | xargs pnc find | sort -u | tr -d '\n')"
					mkdir -p "$HYPRMO_LOGDIR/$NUMBER"
					DRAFT="$HYPRMO_LOGDIR/$NUMBER/draft.txt"
					if [ -f "$HYPRMO_LOGDIR/$OLDNUMBER/draft.txt" ]; then
						# TODO: if there is already a DRAFT warn the user?
						mv "$HYPRMO_LOGDIR/$OLDNUMBER/draft.txt" "$DRAFT"
					fi
					if [ -f "$HYPRMO_LOGDIR/$OLDNUMBER/draft.attachments.txt" ]; then
						mv "$HYPRMO_LOGDIR/$OLDNUMBER/draft.attachments.txt" \
						"$HYPRMO_LOGDIR/$NUMBER/draft.attachments.txt"
					fi
					[ -e "$HYPRMO_LOGDIR/$NUMBER/sms.txt" ] || touch "$HYPRMO_LOGDIR/$NUMBER/sms.txt"
					hyprmo_hook_tailtextlog.sh "$NUMBER" &
				fi
				;;
			*"Cancel")
				exit 1
				;;
		esac
	done
}

conversationloop() {
	if [ -n "$1" ]; then
		NUMBER="$1"
	else
		NUMBER="$(choosenumbermenu)"
	fi

	set -e

	hyprmo_keyboard.sh open

	while true; do
		DRAFT="$HYPRMO_LOGDIR/$NUMBER/draft.txt"
		if [ ! -f "$DRAFT" ]; then
			mkdir -p "$(dirname "$DRAFT")"
			touch "$DRAFT"
		fi

		# shellcheck disable=SC2086
		$EDITOR "$DRAFT"
		hyprmo_modemsendsms.sh "$NUMBER" -f "$DRAFT" || continue
		rm "$DRAFT"
	done
}

readtextmenu() {
	# E.g. only display logfiles for directories that exist and join w contact name
	ENTRIES="$(cat <<EOF
$icon_cls Close Menu
$icon_edt Send a Text
$(hyprmo_contacts.sh --texted)
EOF
	)"
	PICKED="$(printf %b "$ENTRIES" | hyprmo_dmenu.sh -p "Texts" -i)" || exit

	if echo "$PICKED" | grep "Close Menu"; then
		exit 1
	elif echo "$PICKED" | grep "Send a Text"; then
		sendtextmenu
	else
		hyprmo_hook_tailtextlog.sh "$(echo "$PICKED" | cut -d: -f2 | sed 's/^ //')"
	fi
}

if [ -z "$*" ]; then
	readtextmenu
else
	"$@"
fi
