#!/usr/bin/env bash
# Active LE discovery, not Windows' cached/paired-device enumeration.
# Requires Bleak and OS Bluetooth permission; see README.md. Saves raw metadata.
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
run_watch_tool list "$@"
