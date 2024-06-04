#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 hyprmo Contributors

# include common definitions
# shellcheck source=scripts/core/hyprmo_common.sh
. hyprmo_common.sh

hyprmo_terminal.sh sh -c "tail -n9999 -f $HYPRMO_LOGDIR/modemlog.tsv"
