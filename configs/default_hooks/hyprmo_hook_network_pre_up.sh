#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# This is called when any network prepares to go up.
# $1 = device name (eg. wlan0)
# $2 = device type (eg. wifi)

# Some examples:

# Notify the user when a network goes down.
# hyprmo_notify_user.sh "$2 ($1) preparing to go up."
