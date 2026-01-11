#!/usr/bin/env bash
set -euo pipefail
# Clean native library build artifacts (target/)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/scripts/setup_rust_env.sh"

echo "[clean-native] Running cargo clean..."
cd "$SCRIPT_DIR"
"$RUSTUP_BIN" run "$RUST_TOOLCHAIN" cargo clean

echo "[clean-native] Removing target directory..."
rm -rf "$SCRIPT_DIR/target"

echo "[clean-native] Done. To rebuild: rust/wellen_bridge/build_native.sh"
