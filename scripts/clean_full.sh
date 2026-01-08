#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[clean-full] Cleaning wellen and extension artifacts"
"$ROOT_DIR/scripts/clean_wellen.sh"
"$ROOT_DIR/scripts/clean_extension.sh"
echo "[clean-full] Done"
