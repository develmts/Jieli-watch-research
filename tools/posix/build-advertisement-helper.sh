#!/usr/bin/env bash
# Windows advertisement DLL replacement: validate the shared Bleak backend.
# This does not install dependencies or start Bluetooth scanning.
set -euo pipefail
exec bash "$(dirname -- "${BASH_SOURCE[0]}")/build-posix-helper.sh" "$@"
