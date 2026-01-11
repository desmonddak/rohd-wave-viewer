#!/usr/bin/env bash
set -euo pipefail
# Install Rust 1.92 toolchain into per-user ~/.cargo and ~/.rustup
# Also installs wasm targets and helper CLIs needed for building wellen_bridge.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Determine invoking user's home (handles sudo)
if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER-}" ]; then
  INVOKER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
  INVOKER_HOME="$HOME"
fi

export CARGO_HOME="${CARGO_HOME:-${INVOKER_HOME}/.cargo}"
export RUSTUP_HOME="${RUSTUP_HOME:-${INVOKER_HOME}/.rustup}"

# Normalize potential colon-separated envs
CARGO_HOME="${CARGO_HOME%%:*}"
RUSTUP_HOME="${RUSTUP_HOME%%:*}"
export CARGO_HOME RUSTUP_HOME

export PATH="$CARGO_HOME/bin:$PATH"

RUST_VERSION="1.92.0"

echo "[install-rust] CARGO_HOME=$CARGO_HOME"
echo "[install-rust] RUSTUP_HOME=$RUSTUP_HOME"

# Install rustup if missing
RUSTUP_BIN="$CARGO_HOME/bin/rustup"
if ! command -v "$RUSTUP_BIN" >/dev/null 2>&1; then
  echo "[install-rust] rustup not found; installing to $CARGO_HOME/bin"
  # Prefer curl, fallback to wget
  if command -v curl >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain "$RUST_VERSION"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain "$RUST_VERSION"
  else
    echo "[install-rust] ERROR: neither curl nor wget found; please install one." >&2
    exit 1
  fi
else
  echo "[install-rust] rustup already present at $RUSTUP_BIN"
fi

# Ensure toolchain and components
"$CARGO_HOME/bin/rustup" toolchain install "$RUST_VERSION" || true
"$CARGO_HOME/bin/rustup" default "$RUST_VERSION"
"$CARGO_HOME/bin/rustup" target add wasm32-unknown-unknown --toolchain "$RUST_VERSION" || true
"$CARGO_HOME/bin/rustup" component add rust-src --toolchain "$RUST_VERSION" || true
"$CARGO_HOME/bin/rustup" component add rustfmt --toolchain "$RUST_VERSION" || true

# Show versions
"$CARGO_HOME/bin/rustc" --version || true
"$CARGO_HOME/bin/cargo" --version || true
"$CARGO_HOME/bin/rustup" show || true

# Install helper CLIs (idempotent)
if ! command -v wasm-pack >/dev/null 2>&1; then
  echo "[install-rust] Installing wasm-pack via cargo..."
  "$CARGO_HOME/bin/cargo" install wasm-pack || true
fi
if ! command -v wasm-bindgen >/dev/null 2>&1; then
  echo "[install-rust] Installing wasm-bindgen-cli via cargo..."
  "$CARGO_HOME/bin/cargo" install -f wasm-bindgen-cli || true
fi

echo "[install-rust] Rust $RUST_VERSION installation complete."
