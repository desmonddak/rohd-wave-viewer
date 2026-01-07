#!/usr/bin/env bash
set -euo pipefail
# Build the Rust wellen bindings and wasm package
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[wellen-build] Generating FRB and building Rust -> wasm"
"$ROOT_DIR/scripts/generate_frb.sh"
"$ROOT_DIR/scripts/build_rust_wasm.sh"
echo "[wellen-build] Done"
