#!/usr/bin/env bash
# Clean script for ROHD Wave Viewer VS Code extension
# Removes all generated artifacts from the extension build

set -euo pipefail

echo "=== Cleaning ROHD Wave Viewer Extension Build ==="

# Ensure repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.." || exit 1
REPO_ROOT="$(pwd)"

echo "REPO_ROOT: $REPO_ROOT"

# Clean Rust bridge artifacts (WASM and generated FRB files)
echo "Cleaning Rust bridge artifacts..."
"$REPO_ROOT/rust/wellen_bridge/clean.sh"

# Remove Flutter web build artifacts
if [ -d "$REPO_ROOT/build/web" ]; then
  echo "Removing build/web/..."
  rm -rf "$REPO_ROOT/build/web"
fi

# Remove TypeScript compilation output
if [ -d "$REPO_ROOT/vscode-extension/out" ]; then
  echo "Removing vscode-extension/out/..."
  rm -rf "$REPO_ROOT/vscode-extension/out"
fi

# Note: node_modules and package-lock.json are usually left in place for incremental rebuilds.
# To force a complete rebuild of npm dependencies, manually remove:
#   rm -rf vscode-extension/node_modules vscode-extension/package-lock.json

echo ""
echo "=== Extension build cleaned ==="
echo ""
echo "To rebuild, run:"
echo "  bash scripts/build_extension.sh"
