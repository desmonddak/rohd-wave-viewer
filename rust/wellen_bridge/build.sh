#!/usr/bin/env bash
set -euo pipefail
# Build the wellen_bridge WASM package. Assumes dependencies already installed via tool/gh_actions installers.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Prepare Rust environment (uses pinned 1.92 toolchain and PATH/CARGO_HOME setup)
source "$ROOT_DIR/scripts/setup_rust_env.sh"

# Run flutter_rust_bridge code generation (uses libclang, rustfmt, dart fmt)
"$ROOT_DIR/scripts/generate_frb.sh"

# Build the wasm package (expects wasm-pack/wasm-bindgen already installed)
"$SCRIPT_DIR/build_wasm.sh"

echo "[wellen-bridge] Build complete. Artifacts in $ROOT_DIR/web/pkg"
