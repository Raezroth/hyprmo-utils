#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Hyprmo Contributors

# include common definitions
# shellcheck source=scripts/core/hyprmo_common.sh
. hyprmo_common.sh

WINNAME="$1"
CHOICE="$2"

hyprmo_log "Unknown choice <$CHOICE> selected from contextmenu <$WINNAME>"
