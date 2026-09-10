#!/usr/bin/env bash
# report.sh — Forwarder to canonical Python report tool
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/report.py" "$@"
