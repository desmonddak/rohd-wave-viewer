#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[full-build] Backing up generated files"
"$SCRIPT_DIR/backup_generated.sh"

echo "[full-build] Cleaning compiled Rust artifacts and generated files"
"$SCRIPT_DIR/clean_rust_and_generated.sh"

echo "[full-build] Step 1: build wellen (FRB + wasm)"
"$ROOT_DIR/scripts/wellen_build.sh"

echo "[full-build] Step 2: build extension (Flutter web + package)"
"$ROOT_DIR/scripts/extension_build.sh"

echo "[full-build] Done"
