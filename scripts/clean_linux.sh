#!/usr/bin/env bash
# Clean script for ROHD Wave Viewer Linux desktop build
# Removes all generated artifacts from `flutter build linux`

set -euo pipefail

echo "=== Cleaning ROHD Wave Viewer Linux Build ==="

# Ensure repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.." || exit 1
REPO_ROOT="$(pwd)"

echo "REPO_ROOT: $REPO_ROOT"

# Remove Linux build artifacts
if [ -d "$REPO_ROOT/build/linux" ]; then
  echo "Removing build/linux/..."
  rm -rf "$REPO_ROOT/build/linux"
fi

# Remove native assets directory (created during build)
if [ -d "$REPO_ROOT/build/native_assets" ]; then
  echo "Removing build/native_assets/..."
  rm -rf "$REPO_ROOT/build/native_assets"
fi

echo ""
echo "=== Linux build cleaned ==="
echo ""
echo "To rebuild, run:"
echo "  bash scripts/build_linux.sh"
