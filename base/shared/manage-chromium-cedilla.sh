#!/usr/bin/env bash
# manage-chromium-cedilla.sh — Forwarder to canonical Python orchestrator
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/manage-chromium-cedilla.py" "$@"
