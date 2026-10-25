#!/usr/bin/env bash
# One bounded session; defaults to battery only. Select --query identity, etc.
# Dependencies: Python 3.10+, Bleak and OS Bluetooth access; see README.md.
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
run_watch_tool session "$@"
