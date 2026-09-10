#!/usr/bin/env bash
# setup-suite.sh — Forwarder to canonical Python setup wizard
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/setup-suite.py" "$@"
