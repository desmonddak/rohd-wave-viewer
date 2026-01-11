#!/usr/bin/env bash
set -euo pipefail
# Build rust wasm package (wellen_bridge) for web/pkg using wasm-pack

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/scripts/setup_rust_env.sh"

echo "[rust-wasm] Building wasm package using wasm-pack..."

cd "$ROOT_DIR/rust/wellen_bridge"

# Require tools to be pre-installed (see tool/gh_actions/install_wasm_tools.sh)
if ! command -v wasm-pack >/dev/null 2>&1; then
    echo "[rust-wasm] ERROR: wasm-pack not found. Run tool/gh_actions/install_wasm_tools.sh first." >&2
    exit 1
fi

if ! command -v wasm-bindgen >/dev/null 2>&1; then
    echo "[rust-wasm] ERROR: wasm-bindgen-cli not found. Run tool/gh_actions/install_wasm_tools.sh first." >&2
    exit 1
fi

export PATH="$CARGO_HOME/bin:$PATH"

# Ensure required toolchain is present (installed by install_rust_1_92.sh)
if ! "$RUSTUP_BIN" toolchain list | grep -q "$RUST_TOOLCHAIN"; then
    echo "[rust-wasm] ERROR: Rust toolchain $RUST_TOOLCHAIN missing. Run tool/gh_actions/install_rust_1_92.sh." >&2
    exit 1
fi

"$RUSTUP_BIN" run "$RUST_TOOLCHAIN" wasm-pack build --target no-modules --out-dir ../../web/pkg

echo "[rust-wasm] wasm-pack build finished"
