#!/bin/bash
# Cleanup script for ROHD Wave Viewer
# Removes all build artifacts from Rust and Flutter

set -e

echo "=== ROHD Wave Viewer Cleanup Script ==="
echo ""

echo "Cleaning Rust wellen_bridge build..."
cd rust/wellen_bridge
cargo clean
rm -rf target/
echo "✓ Rust build cleaned"
echo ""

echo "Removing libwellen_bridge.so from Flutter bundle..."
rm -f ../../build/linux/x64/debug/bundle/lib/libwellen_bridge.so
rm -f ../../build/linux/x64/release/bundle/lib/libwellen_bridge.so
echo "✓ Shared library removed"
echo ""

cd ../..
echo "Cleaning Flutter build..."
flutter clean
echo "✓ Flutter build cleaned"
echo ""

echo "=== Cleanup Complete ==="
echo "To rebuild, run:"
echo "  1. cd rust/wellen_bridge"
echo "  2. cargo build --release"
echo "  3. cd ../.."
echo "  4. flutter build linux --debug"
echo "  5. cp rust/wellen_bridge/target/release/libwellen_bridge.so build/linux/x64/debug/bundle/lib/"
