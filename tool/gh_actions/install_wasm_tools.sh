#!/usr/bin/env bash
set -euo pipefail
# Install wasm-pack and wasm-bindgen-cli using the existing Rust toolchain.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load rust environment (expects install_rust_1_92.sh or equivalent run beforehand)
source "$ROOT_DIR/scripts/setup_rust_env.sh"

# Ensure cargo is available
if ! command -v cargo >/dev/null 2>&1; then
  echo "[install-wasm-tools] ERROR: cargo not found. Run install_rust_1_92.sh first." >&2
  exit 1
fi

# Install wasm-pack if missing
if ! command -v wasm-pack >/dev/null 2>&1; then
  echo "[install-wasm-tools] Installing wasm-pack via cargo..."
  cargo install wasm-pack || true
else
  echo "[install-wasm-tools] wasm-pack already installed"
fi

# Install wasm-bindgen-cli if missing
if ! command -v wasm-bindgen >/dev/null 2>&1; then
  echo "[install-wasm-tools] Installing wasm-bindgen-cli via cargo..."
  cargo install -f wasm-bindgen-cli || true
else
  echo "[install-wasm-tools] wasm-bindgen already installed"
fi

echo "[install-wasm-tools] Done."
