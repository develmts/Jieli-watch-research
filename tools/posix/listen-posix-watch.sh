#!/usr/bin/env bash
# Target advertisement scan, then 20 seconds of battery/FF14/normal notifications.
# Notifications cause OS-managed CCCD writes. No OTA subscription or app command.
# --skip-advertisements avoids the first scan; --MaintainConnection is unsupported.
# Install Bleak and OS requirements as described in README.md.
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
run_watch_tool listen "$@"
