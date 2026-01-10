#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[full-build-linux] Backing up generated files"
# Disabled to avoid creating build_backups directory
# "$SCRIPT_DIR/backup_generated.sh"

echo "[full-build-linux] Cleaning compiled Rust artifacts and generated files"
"$SCRIPT_DIR/clean_rust_and_generated.sh"

echo "[full-build-linux] Step 1: generate flutter_rust_bridge bindings"
"$SCRIPT_DIR/generate_frb.sh"

# Linux build uses native Rust (.so/.dylib/.dll); wasm artifacts from build_rust_wasm.sh
# are only needed for the web/extension flow, so we skip wasm here.

echo "[full-build-linux] Step 2: build native app"
bash "$SCRIPT_DIR/build_linux.sh"

echo "[full-build-linux] Done"
