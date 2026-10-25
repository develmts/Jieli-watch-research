#!/usr/bin/env bash
# Windows notification DLL replacement: check the interpreted Bleak backend.
# No compiler or C# runtime is needed; install requirements.txt as documented.
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
exec "$PYTHON" -c 'import sys, importlib.metadata; assert sys.version_info >= (3,10), "Python 3.10+ required"; import bleak; print("Notification backend ready; Bleak " + importlib.metadata.version("bleak"))'
