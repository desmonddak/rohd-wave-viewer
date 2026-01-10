#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[full-build] Backing up generated files"
# Disabled to avoid creating build_backups directory
# "$SCRIPT_DIR/backup_generated.sh"

echo "[full-build] Cleaning compiled Rust artifacts and generated files"
"$SCRIPT_DIR/clean_rust_and_generated.sh"

echo "[full-build] Step 1: generate flutter_rust_bridge bindings"
"$SCRIPT_DIR/generate_frb.sh"

echo "[full-build] Step 2: build Rust -> wasm"
"$SCRIPT_DIR/build_rust_wasm.sh"

echo "[full-build] Step 3: build extension (final)"
bash "$SCRIPT_DIR/build_extension.sh"

echo "[full-build] Done"
