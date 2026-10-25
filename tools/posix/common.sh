#!/usr/bin/env bash
# Shared launcher. Requires Bash 3.2+ and Python 3.10+; see README.md.
# Source this file from an entry point; paths work independently of the cwd.
set -euo pipefail
POSIX_TOOLS_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RESEARCH_ROOT="$(CDPATH= cd -- "$POSIX_TOOLS_DIR/../.." && pwd)"
PYTHON="${HRYFINE_PYTHON:-$RESEARCH_ROOT/.venv/bin/python}"
if [[ ! -x "$PYTHON" ]]; then
    PYTHON="${HRYFINE_PYTHON:-python3}"
fi
if ! command -v "$PYTHON" >/dev/null 2>&1; then
    printf '%s\n' 'Python unavailable. Install Python 3.10+; see tools/posix/README.md.' >&2
    exit 1
fi
run_watch_tool() {
    exec "$PYTHON" "$POSIX_TOOLS_DIR/watch_ble.py" "$@"
}
