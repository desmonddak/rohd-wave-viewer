#!/bin/bash
# Build script for ROHD Wave Viewer
# Builds both Rust wellen_bridge library and Flutter Linux app

set -e

echo "=== ROHD Wave Viewer Build Script ==="
echo ""

# Set Rust stable toolchain path
RUST_STABLE="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin"
export PATH="$RUST_STABLE:$PATH"

# Verify Rust version
echo "Using Rust version:"
cargo --version
echo ""

# Build Rust library
echo "Building Rust wellen_bridge library..."
cd rust/wellen_bridge
cargo build --release
echo "✓ Rust library built"
echo ""

# Build Flutter app
cd ../..
echo "Building Flutter Linux app..."
flutter build linux --debug
echo "✓ Flutter app built"
echo ""

# Copy shared library to bundle
echo "Copying libwellen_bridge.so to Flutter bundle..."
cp rust/wellen_bridge/target/release/libwellen_bridge.so build/linux/x64/debug/bundle/lib/
echo "✓ Library copied"
echo ""

echo "=== Build Complete ==="
echo ""
echo "To run the app:"
echo "  ./build/linux/x64/debug/bundle/rohd_wave_viewer [path/to/waveform.vcd]"
echo ""
echo "Example:"
echo "  ./build/linux/x64/debug/bundle/rohd_wave_viewer surfer/examples/picorv32.vcd"
