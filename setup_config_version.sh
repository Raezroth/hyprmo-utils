#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 hyprmo Contributors

case "$1" in
	*.json)
		# we ignore json files
		exit
esac

case "$(busybox head -n1 "$1")" in
	"#"*)
		comment="#"
		;;
	!*)
		comment="!"
		;;
	--*)
		comment="--"
		;;
	*)
		exit # we skip this file
		;;
esac

busybox md5sum "$1" | \
	busybox cut -d" " -f1 | \
	busybox xargs -I{} busybox sed -i "2i$comment configversion: {}" \
	"$1"
