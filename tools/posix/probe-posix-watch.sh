#!/usr/bin/env bash
# Connect, check battery, enumerate services and disconnect. No proprietary writes.
# Set HRYFINE_WATCH_ADDRESS; dependencies and platform differences: README.md.
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
run_watch_tool probe "$@"
