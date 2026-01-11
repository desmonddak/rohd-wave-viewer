#!/usr/bin/env bash
# Build script for ROHD Wave Viewer (Linux desktop)
# Assumes: Rust toolchain 1.92.0 installed, wellen_bridge built, Dart interface ready.
# Focus: Dart/Flutter build for Linux.

set -euo pipefail

echo "=== ROHD Wave Viewer Build (Linux) ==="

# Ensure repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.." || exit 1
REPO_ROOT="$(pwd)"

# Set Rust env (for running any Dart/FFI setup if needed)
export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
export PATH="$CARGO_HOME/bin:$PATH"

echo "Dart/Flutter build for Linux:"
echo "  REPO_ROOT: $REPO_ROOT"
echo ""

# Verify Rust wellen_bridge is built
WELLEN_DIR="$REPO_ROOT/rust/wellen_bridge"
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
  echo "Native library not found at: $LIB_SRC"
  echo "Building native library..."
  "$REPO_ROOT/rust/wellen_bridge/build_native.sh" || {
    echo "ERROR: Failed to build native library"
    exit 1
  }
fi

echo "Verified Rust library: $LIB_SRC"

# Copy native lib to Flutter package expected path
FLUTTER_NATIVE_DIR="$REPO_ROOT/packages/dart_wellen/linux"
mkdir -p "$FLUTTER_NATIVE_DIR"
cp -f "$LIB_SRC" "$FLUTTER_NATIVE_DIR/" || {
  echo "ERROR: Failed to copy native lib to $FLUTTER_NATIVE_DIR"
  exit 1
}
echo "Copied native library to $FLUTTER_NATIVE_DIR/"

# Flutter steps
if ! command -v cmake &>/dev/null || ! command -v ninja &>/dev/null || \
   (! command -v g++ &>/dev/null && ! command -v clang++ &>/dev/null) || \
   ! command -v pkg-config &>/dev/null; then
  echo "ERROR: Missing build tools (cmake, ninja, C++ compiler, pkg-config)."
  echo "Hint: run tool/gh_actions/install_build_tools.sh"
  exit 1
fi
if ! command -v flutter &>/dev/null; then
  echo "ERROR: flutter not found on PATH. Install Flutter and ensure 'flutter' is available."
  exit 1
fi

echo ""
echo "Fetching Flutter dependencies..."
flutter pub get

# Ensure native_assets directory exists (Flutter's CMake install rule expects it)
mkdir -p "$REPO_ROOT/build/native_assets/linux"

echo ""
echo "Building Flutter Linux application (release)..."
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
