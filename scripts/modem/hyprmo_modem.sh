#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# include common definitions
# shellcheck source=configs/default_hooks/sxmo_hook_icons.sh
. hyprmo_hook_icons.sh
# shellcheck source=scripts/core/sxmo_common.sh
. hyprmo_common.sh

# We use this directory to store states, so it must exist
mkdir -p "$XDG_RUNTIME_DIR/sxmo_calls"

stderr() {
	hyprmo_log "$*"
}

cleanupnumber() {
	if pnc valid "$1"; then
		echo "$1"
		return
	fi

	REFORMATTED="$(pnc find ${DEFAULT_COUNTRY:+-c "$DEFAULT_COUNTRY"} "$1")"
	if [ -n "$REFORMATTED" ]; then
		echo "$REFORMATTED"
		return
	fi

	echo "$1"
}

checkforfinishedcalls() {
	exec 3<> "${XDG_RUNTIME_DIR:-HOME}/hyprmo_modem.checkforfinishedcalls.lock"
	flock -x 3
	#find all finished calls
	for FINISHEDCALLID in $(
		mmcli -m any --voice-list-calls |
		grep terminated |
		grep -oE "Call\/[0-9]+" |
		cut -d'/' -f2
	); do
		FINISHEDNUMBER="$(hyprmo_modemcall.sh vid_to_number "$FINISHEDCALLID")"
		FINISHEDNUMBER="$(cleanupnumber "$FINISHEDNUMBER")"
		mmcli -m any --voice-delete-call "$FINISHEDCALLID"

		rm -f "$XDG_RUNTIME_DIR/sxmo_calls/${FINISHEDCALLID}.monitoredcall"

		CONTACT="$(hyprmo_contacts.sh --name-or-number "$FINISHEDNUMBER")"

		TIME="$(date +%FT%H:%M:%S%z)"
		mkdir -p "$HYPRMO_LOGDIR"
		if [ -f "$XDG_RUNTIME_DIR/sxmo_calls/${FINISHEDCALLID}.discardedcall" ]; then
			#this call was discarded
			hyprmo_notify_user.sh "Call with $CONTACT terminated"
			stderr "Discarded call from $FINISHEDNUMBER"
			printf %b "$TIME\tcall_finished\t$FINISHEDNUMBER\n" >> "$HYPRMO_LOGDIR/modemlog.tsv"
		elif [ -f "$XDG_RUNTIME_DIR/sxmo_calls/${FINISHEDCALLID}.pickedupcall" ]; then
			#this call was picked up
			hyprmo_notify_user.sh "Call with $CONTACT terminated"
			stderr "Finished call from $FINISHEDNUMBER"
			printf %b "$TIME\tcall_finished\t$FINISHEDNUMBER\n" >> "$HYPRMO_LOGDIR/modemlog.tsv"
		elif [ -f "$XDG_RUNTIME_DIR/sxmo_calls/${FINISHEDCALLID}.hangedupcall" ]; then
			#this call was hung up by the user
			hyprmo_notify_user.sh "Call with $CONTACT terminated"
			stderr "Finished call from $FINISHEDNUMBER"
			printf %b "$TIME\tcall_finished\t$FINISHEDNUMBER\n" >> "$HYPRMO_LOGDIR/modemlog.tsv"
		elif [ -f "$XDG_RUNTIME_DIR/sxmo_calls/${FINISHEDCALLID}.initiatedcall" ]; then
			#this call was hung up by the contact
			hyprmo_notify_user.sh "Call with $CONTACT terminated"
			stderr "Finished call from $FINISHEDNUMBER"
			printf %b "$TIME\tcall_finished\t$FINISHEDNUMBER\n" >> "$HYPRMO_LOGDIR/modemlog.tsv"
		elif [ -f "$XDG_RUNTIME_DIR/sxmo_calls/${FINISHEDCALLID}.mutedring" ]; then
			#this ring was muted up
			stderr "Muted ring from $FINISHEDNUMBER"
			printf %b "$TIME\tring_muted\t$FINISHEDNUMBER\n" >> "$HYPRMO_LOGDIR/modemlog.tsv"
		else
			#this is a missed call
			# Add a notification for every missed call

			NOTIFMSG="Missed call from $CONTACT ($FINISHEDNUMBER)"
			stderr "$NOTIFMSG"
			printf %b "$TIME\tcall_missed\t$FINISHEDNUMBER\n" >> "$HYPRMO_LOGDIR/modemlog.tsv"

			stderr "Invoking missed call hook (async)"
			hyprmo_hook_missed_call.sh "$CONTACT" &

			hyprmo_notificationwrite.sh \
				random \
				"TERMNAME='$NOTIFMSG' sxmo_terminal.sh sh -c \"echo '$NOTIFMSG at $(date)' && read\"" \
				none \
				"Missed $icon_phn $CONTACT ($FINISHEDNUMBER)"
		fi

		# If it was the last call
		if ! hyprmo_modemcall.sh list_active_calls | grep -q .; then
			# Cleanup
			hyprmo_vibrate 1000 "${HYPRMO_VIBRATE_STRENGTH:-1}" &
			hyprmo_jobs.sh stop incall_menu
			hyprmo_jobs.sh stop proximity_lock

			if hyprmo_modemaudio.sh is_call_audio_mode; then
				if ! hyprmo_modemaudio.sh reset_audio; then
					hyprmo_notify_user.sh --urgency=critical "We failed to reset call audio"
				fi
			fi

			hyprmo_hook_after_call.sh
		else
			# Or refresh the menu
			hyprmo_jobs.sh start incall_menu hyprmo_modemcall.sh incall_menu
		fi
	done
}

checkforincomingcalls() {
	VOICECALLID="$(
		mmcli -m any --voice-list-calls -a |
		grep -Eo '[0-9]+ incoming \(ringing-in\)' |
		grep -Eo '[0-9]+'
	)"
	[ -z "$VOICECALLID" ] && return

	[ -f "$XDG_RUNTIME_DIR/sxmo_calls/${VOICECALLID}.monitoredcall" ] && return # prevent multiple rings
	rm "$XDG_RUNTIME_DIR/sxmo_calls/$VOICECALLID."* 2>/dev/null # we cleanup all dangling event files
	touch "$XDG_RUNTIME_DIR/sxmo_calls/${VOICECALLID}.monitoredcall" #this signals that we handled the call

	# Determine the incoming phone number
	stderr "Incoming Call..."
	INCOMINGNUMBER=$(sxmo_modemcall.sh vid_to_number "$VOICECALLID")
	INCOMINGNUMBER="$(cleanupnumber "$INCOMINGNUMBER")"

	TIME="$(date +%FT%H:%M:%S%z)"
	if cut -f1 "$HYPRMO_BLOCKFILE" 2>/dev/null | grep -q "^$INCOMINGNUMBER$"; then
		stderr "BLOCKED call from number: $VOICECALLID"
		hyprmo_modemcall.sh mute "$VOICECALLID"
		printf %b "$TIME\tcall_ring\t$INCOMINGNUMBER\n" >> "$HYPRMO_BLOCKDIR/modemlog.tsv"
	else
		stderr "Invoking ring hook (async)"
		CONTACTNAME=$(hyprmo_contacts.sh --name-or-number "$INCOMINGNUMBER")
		hyprmo_jobs.sh start ringing hyprmo_hook_ring.sh "$CONTACTNAME"

		mkdir -p "$HYPRMO_LOGDIR"
		printf %b "$TIME\tcall_ring\t$INCOMINGNUMBER\n" >> "$HYPRMO_LOGDIR/modemlog.tsv"

		hyprmo_jobs.sh start proximity_lock hyprmo_proximitylock.sh
		

		# If we already got an active call
		if hyprmo_modemcall.sh list_active_calls \
			| grep -v ringing-in \
			| grep -q .; then
			# Refresh the incall menu
			hyprmo_jobs.sh start incall_menu hyprmo_modemcall.sh incall_menu
		else
			# Or fire the incomming call menu
			hyprmo_jobs.sh start incall_menu hyprmo_modemcall.sh incoming_call_menu "$VOICECALLID"
		fi

		stderr "Call from number: $INCOMINGNUMBER (VOICECALLID: $VOICECALLID)"
	fi
}

# this function is called in the modem hook when the modem registers
checkforstucksms() {
	stuck_messages="$(mmcli -m any --messaging-list-sms)"
	if ! echo "$stuck_messages" | grep -q "^No sms messages were found"; then
		hyprmo_notify_user.sh "WARNING: $(echo "$stuck_messages" | wc -l) stuck sms found.  Run hyprmo_modem.sh checkforstucksms view to view or delete to delete."
		case "$1" in
			"delete")
				mmcli -m any --messaging-list-sms | while read -r line; do
					sms_number="$(echo "$line" | cut -d'/' -f6 | cut -d' ' -f1)"
					hyprmo_log "Deleting sms $sms_number"
					mmcli -m any --messaging-delete-sms="$sms_number"
				done
				;;
			"view")
				mmcli -m any --messaging-list-sms | while read -r line; do
					sms_number="$(echo "$line" | cut -d'/' -f6 | cut -d' ' -f1)"
					mmcli -m any -s "$sms_number" -K
				done
				;;
		esac
	fi
}

checkfornewtexts() {
	exec 3<> "${XDG_RUNTIME_DIR:-HOME}/hyprmo_modem.checkfornewtexts.lock"
	flock -x 3
	TEXTIDS="$(
		mmcli -m any --messaging-list-sms |
		grep -Eo '/SMS/[0-9]+ \(received\)' |
		grep -Eo '[0-9]+'
	)"
	echo "$TEXTIDS" | grep -v . && return

	# Loop each textid received and read out the data into appropriate logfile
	for TEXTID in $TEXTIDS; do
		TEXTDATA="$(mmcli -m any -s "$TEXTID" -J)"
		# SMS with no TEXTID is an SMS WAP (I think). So skip.
		if [ -z "$TEXTDATA" ]; then
			stderr "Received an empty SMS (TEXTID: $TEXTID).  I will assume this is an MMS."
			printf %b "$(date +%FT%H:%M:%S%z)\tdebug_mms\tNULL\tEMPTY (TEXTID: $TEXTID)\n" >> "$HYPRMO_LOGDIR/modemlog.tsv"
			if [ -f "${HYPRMO_MMS_BASE_DIR:-"$HOME"/.mms/modemmanager}/mms" ]; then
				continue
			else
				stderr "WARNING: mmsdtng not found or unconfigured, treating as normal sms."
			fi
		fi
		TEXT="$(printf %s "$TEXTDATA" | jq -r .sms.content.text)"
		NUM="$(printf %s "$TEXTDATA" | jq -r .sms.content.number)"
		NUM="$(cleanupnumber "$NUM")"

		TIME="$(printf %s "$TEXTDATA" | jq -r .sms.properties.timestamp)"
		TIME="$(date +%FT%H:%M:%S%z -d "$TIME")"

		# Note: this will *not* block MMS, since we have to unpack the phone numbers for an MMS
		# later.
		#
		# TODO: a user *could* block the sms wap number (which would be user error).  But then
		# the mms would not be processed.  So probably give a warning here if the user has blocked
		# the sms wap number?
		if cut -f1 "$HYPRMO_BLOCKFILE" 2>/dev/null | grep -q "^$NUM$"; then
			mkdir -p "$HYPRMO_BLOCKDIR/$NUM"
			stderr "BLOCKED text from number: $NUM (TEXTID: $TEXTID)"
			hyprmo_hook_smslog.sh "recv" "$NUM" "$NUM" "$TIME" "$TEXT" >> "$HYPRMO_BLOCKDIR/$NUM/sms.txt"
			printf %b "$TIME\trecv_txt\t$NUM\t${#TEXT} chars\n" >> "$HYPRMO_BLOCKDIR/modemlog.tsv"
			mmcli -m any --messaging-delete-sms="$TEXTID"
			continue
		fi

		if [ "$TEXT" = "--" ] && [ ! "$NUM" = "+223344556678" ]; then
			stderr "Text from $NUM (TEXTID: $TEXTID) with '--'.  I will assume this is an MMS."
			printf %b "$TIME\tdebug_mms\t$NUM\t$TEXT\n" >> "$HYPRMO_LOGDIR/modemlog.tsv"
			if [ -f "${HYPRMO_MMS_BASE_DIR:-"$HOME"/.mms/modemmanager}/mms" ]; then
				continue
			else
				stderr "WARNING: mmsdtng not found or unconfigured, treating as normal sms."
			fi
		fi

		mkdir -p "$HYPRMO_LOGDIR/$NUM"
		stderr "Text from number: $NUM (TEXTID: $TEXTID)"
		hyprmo_hook_smslog.sh "recv" "$NUM" "$NUM" "$TIME" "$TEXT" >> "$HYPRMO_LOGDIR/$NUM/sms.txt"
		printf %b "$TIME\trecv_txt\t$NUM\t${#TEXT} chars\n" >> "$HYPRMO_LOGDIR/modemlog.tsv"

		tries=1
		while ! mmcli -m any --messaging-delete-sms="$TEXTID";
		do
			if [ $tries -gt 5 ];
			then
				break
			fi
			echo "Failed to delete text $TEXTID. Will retry"
			sleep 3
			tries=$((tries+1))
		done
		CONTACTNAME=$(hyprmo_contacts.sh --name-or-number "$NUM")

		if [ -z "$HYPRMO_DISABLE_SMS_NOTIFS" ]; then
			hyprmo_notificationwrite.sh \
				random \
				"hyprmo_hook_tailtextlog.sh '$NUM'" \
				"$HYPRMO_LOGDIR/$NUM/sms.txt" \
				"$CONTACTNAME: $TEXT"

		fi

		if hyprmo_state.sh get | grep -q screenoff; then
			sxmo_state.sh set lock
		fi

		hyprmo_hook_sms.sh "$CONTACTNAME" "$TEXT"
	done
}

hyprmo_wakelock.sh lock hyprmo_modem_used 30s
"$@"
hyprmo_wakelock.sh unlock hyprmo_modem_used
