#!/usr/bin/env bash
# One F3 identity getter plus matching ACKs, guarded by battery >15%.
# Uses only the normal DF/FD channel; install Bleak as described in README.md.
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
run_watch_tool f3 "$@"
