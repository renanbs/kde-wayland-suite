#!/usr/bin/env bash
# profile-machine.sh — Forwarder to canonical Python profiler
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/profile-machine.py" "$@"
