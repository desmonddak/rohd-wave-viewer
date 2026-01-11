#!/usr/bin/env bash
set -euo pipefail
# Clean WASM build artifacts (web/pkg)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "[clean-wasm] Removing WASM build artifacts..."
rm -rf "$ROOT_DIR/web/pkg"
echo "[clean-wasm] Done. To rebuild: rust/wellen_bridge/build_wasm.sh"
