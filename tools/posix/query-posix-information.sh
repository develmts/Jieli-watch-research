#!/usr/bin/env bash
# Run the same 15 information getters as the Windows batch, with 800 ms spacing.
# No setters/OTA start. Battery checked before each query. See README.md for setup.
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
run_watch_tool information "$@"
