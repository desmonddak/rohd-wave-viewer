#!/usr/bin/env bash
set -euo pipefail
# Clean native library build artifacts (target/)

WELLEN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$WELLEN_DIR/../.." && pwd)"

source "$ROOT_DIR/scripts/setup_rust_env.sh"

echo "[clean-native] Running cargo clean..."
# Use --manifest-path to specify the Cargo.toml location
"$RUSTUP_BIN" run "$RUST_TOOLCHAIN" cargo clean --manifest-path "$WELLEN_DIR/Cargo.toml"

echo "[clean-native] Removing target directory..."
rm -rf "$WELLEN_DIR/target"

echo "[clean-native] Done. To rebuild: rust/wellen_bridge/build_native.sh"
