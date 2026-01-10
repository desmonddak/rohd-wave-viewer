#!/usr/bin/env bash
# Build script for ROHD Wave Viewer (Linux desktop)
# Replaces previous build.sh logic with a single, robust linux build flow.
# - Uses user's Rust toolchain (~/.cargo, ~/.rustup)
# - Builds rust/wellen_bridge (native)
# - Copies native lib into packages/dart_wellen/linux
# - Runs flutter pub get and flutter build linux --release
# - Does NOT reference /opt/rust

set -euo pipefail

echo "=== ROHD Wave Viewer Build (linux) ==="

# Ensure repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.." || exit 1
REPO_ROOT="$(pwd)"

# Prefer user Rust toolchain locations and actively override non-home settings.
# 1) Source cargo env for PATH shims.
if [ -s "$HOME/.cargo/env" ]; then
  echo "Sourcing Rust environment from $HOME/.cargo/env"
  # shellcheck source=/dev/null
  . "$HOME/.cargo/env"
fi

# 2) Enforce HOME-based CARGO_HOME/RUSTUP_HOME to avoid /opt/rust permissions.
ORIG_CARGO_HOME="${CARGO_HOME:-}"
ORIG_RUSTUP_HOME="${RUSTUP_HOME:-}"
export CARGO_HOME="$HOME/.cargo"
export RUSTUP_HOME="$HOME/.rustup"
export PATH="$CARGO_HOME/bin:$PATH"

if [ -n "$ORIG_CARGO_HOME" ] && [ "$ORIG_CARGO_HOME" != "$CARGO_HOME" ]; then
  echo "Overriding CARGO_HOME: $ORIG_CARGO_HOME -> $CARGO_HOME"
fi
if [ -n "$ORIG_RUSTUP_HOME" ] && [ "$ORIG_RUSTUP_HOME" != "$RUSTUP_HOME" ]; then
  echo "Overriding RUSTUP_HOME: $ORIG_RUSTUP_HOME -> $RUSTUP_HOME"
fi

# Unset any project/global env var that might force /opt/rust registry
unset CARGO_REGISTRY_DIR 2>/dev/null || true

echo "Rust environment:"
echo "  CARGO_HOME: $CARGO_HOME"
echo "  RUSTUP_HOME: $RUSTUP_HOME"
if ! command -v cargo &>/dev/null; then
  echo "ERROR: cargo not found on PATH. Install Rust via rustup: https://rustup.rs/"
  exit 1
fi
echo "  cargo: $(which cargo)"
echo "  cargo version: $(cargo --version)"
echo ""

# Build rust native bridge
WELLEN_DIR="$REPO_ROOT/rust/wellen_bridge"
if [ ! -d "$WELLEN_DIR" ]; then
  echo "ERROR: Rust wellen_bridge directory not found at $WELLEN_DIR"
  exit 1
fi

echo "Building Rust wellen_bridge (release)..."
cd "$WELLEN_DIR"
# Ensure flutter_rust_bridge bindings exist
FRB_FILE="$WELLEN_DIR/src/frb_generated.rs"
if [ ! -f "$FRB_FILE" ]; then
  echo "frb_generated.rs not found; generating FRB bindings via scripts/generate_frb.sh"
  cd "$REPO_ROOT"
  ./scripts/generate_frb.sh
  cd "$WELLEN_DIR"
fi
# ensure a clean build environment is not strictly required; use build --release
cargo build --release

# locate built native library
LIB_SRC=""
case "$(uname -s)" in
  Linux*)
    LIB_SRC="$WELLEN_DIR/target/release/libwellen_bridge.so"
    ;;
  Darwin*)
    LIB_SRC="$WELLEN_DIR/target/release/libwellen_bridge.dylib"
    ;;
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    LIB_SRC="$WELLEN_DIR/target/release/wellen_bridge.dll"
    ;;
  *)
    LIB_SRC="$WELLEN_DIR/target/release/libwellen_bridge.so"
    ;;
esac

if [ ! -f "$LIB_SRC" ]; then
  echo "ERROR: Built native library not found. Expected one of:"
  echo "  $WELLEN_DIR/target/release/libwellen_bridge.so"
  echo "  $WELLEN_DIR/target/release/libwellen_bridge.dylib"
  echo "  $WELLEN_DIR/target/release/wellen_bridge.dll"
  exit 1
fi

echo "Native library built: $LIB_SRC"
ls -lh "$LIB_SRC" || true

# Copy native lib to Flutter package expected path
FLUTTER_NATIVE_DIR="$REPO_ROOT/packages/dart_wellen/linux"
mkdir -p "$FLUTTER_NATIVE_DIR"
cp -f "$LIB_SRC" "$FLUTTER_NATIVE_DIR/" || {
  echo "ERROR: Failed to copy native lib to $FLUTTER_NATIVE_DIR"
  exit 1
}
echo "Copied native library to $FLUTTER_NATIVE_DIR/"

# Return to repo root
cd "$REPO_ROOT"

# Flutter steps
if ! command -v flutter &>/dev/null; then
  echo "ERROR: flutter not found on PATH. Install Flutter and ensure 'flutter' is available."
  exit 1
fi

echo ""
echo "Fetching Flutter dependencies..."
flutter pub get

echo ""
echo "Building Flutter Linux application (release)..."
# Build linux bundle; pass --no-pub if pub already ran; keep default
flutter build linux --release

LINUX_BUNDLE="$REPO_ROOT/build/linux/x64/release/bundle"
if [ ! -d "$LINUX_BUNDLE" ]; then
  echo "ERROR: Flutter linux build output not found at $LINUX_BUNDLE"
  exit 1
fi

echo ""
echo "=== Build complete ==="
echo "Linux bundle: $LINUX_BUNDLE"
echo ""
echo "Run the application:"
echo "  $LINUX_BUNDLE/rohd_wave_viewer [path/to/waveform.vcd|fst|ghw]"
echo ""
echo "You can also set the waveform via environment:"
echo "  ROHD_WAVEFORM_FILE=path/to/file $LINUX_BUNDLE/rohd_wave_viewer"
