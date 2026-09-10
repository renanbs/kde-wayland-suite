#!/usr/bin/env bash
# diagnose-battery.sh — Forwarder to canonical Python diagnostic tool
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/diagnose-battery.py" "$@"
