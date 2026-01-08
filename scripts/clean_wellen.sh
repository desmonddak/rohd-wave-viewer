#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[clean-wellen] Cleaning Rust build artifacts and generated files"
"$ROOT_DIR/scripts/clean_rust_and_generated.sh"
echo "[clean-wellen] Done"
