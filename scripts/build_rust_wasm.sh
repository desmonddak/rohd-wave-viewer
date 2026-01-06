#!/usr/bin/env bash
set -euo pipefail
# Build rust wasm package (wellen_bridge) for web/pkg using wasm-pack

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/scripts/setup_rust_env.sh"

echo "[rust-wasm] Building wasm package using wasm-pack..."

cd "$ROOT_DIR/rust/wellen_bridge"

# Ensure wasm-pack available
if ! command -v wasm-pack >/dev/null 2>&1; then
    echo "[rust-wasm] wasm-pack not found; installing via cargo..."
    cargo install wasm-pack || true
fi

# Ensure wasm-bindgen CLI available via cargo install if needed
if ! command -v wasm-bindgen >/dev/null 2>&1; then
    echo "[rust-wasm] wasm-bindgen not found; installing via cargo..."
    cargo install -f wasm-bindgen-cli || true
fi

export PATH="$CARGO_HOME/bin:$PATH"

# Ensure nightly toolchain is available
if ! "$RUSTUP_BIN" toolchain list | grep -q "$RUST_TOOLCHAIN"; then
    echo "[rust-wasm] Rust toolchain $RUST_TOOLCHAIN not found; attempting to install..."
    if ! "$RUSTUP_BIN" toolchain install "$RUST_TOOLCHAIN"; then
        echo "[rust-wasm] ERROR: failed to install $RUST_TOOLCHAIN via $RUSTUP_BIN" >&2
        echo "Please install the toolchain manually, e.g:" >&2
        echo "  $RUSTUP_BIN toolchain install $RUST_TOOLCHAIN" >&2
        exit 1
    fi
fi

"$RUSTUP_BIN" run "$RUST_TOOLCHAIN" wasm-pack build --target no-modules --out-dir ../../web/pkg

echo "[rust-wasm] wasm-pack build finished"
