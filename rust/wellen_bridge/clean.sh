#!/usr/bin/env bash
set -euo pipefail
# Full cleanup: native build, WASM build, and generated FRB files

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "[clean] Full wellen_bridge cleanup..."

# Clean WASM artifacts
echo "[clean] Cleaning WASM build..."
"$SCRIPT_DIR/clean_wasm.sh"

# Clean native artifacts
echo "[clean] Cleaning native build..."
"$SCRIPT_DIR/clean_native.sh"

# Clean generated FRB files
echo "[clean] Removing generated FRB files..."
rm -f "$SCRIPT_DIR/src/frb_generated.rs"
rm -f "$ROOT_DIR/packages/dart_wellen/lib/src/rust/api"/*.dart 2>/dev/null || true
rm -f "$ROOT_DIR/packages/dart_wellen/lib/src/rust/frb_generated"*.dart 2>/dev/null || true
find "$ROOT_DIR/packages/dart_wellen" -type f -name 'flutter_rust_bridge.generated.*.yaml' -delete 2>/dev/null || true

echo ""
echo "[clean] Done. Full cleanup complete."
echo "To rebuild:"
echo "  WASM:   rust/wellen_bridge/build.sh"
echo "  Native: rust/wellen_bridge/build_native.sh"
