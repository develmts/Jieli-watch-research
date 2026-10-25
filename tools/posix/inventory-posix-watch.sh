#!/usr/bin/env bash
# Read GATT characteristics/descriptors; record per-read failures. No subscriptions.
# Requires readable battery >15%, Bleak and OS Bluetooth access; see README.md.
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
run_watch_tool inventory "$@"
