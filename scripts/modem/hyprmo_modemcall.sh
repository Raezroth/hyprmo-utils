#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

err() {
	printf %b "$1" | dmenu
	exit
}

hyprmo_terminal.sh sh -c "mmcli -m any && read"
