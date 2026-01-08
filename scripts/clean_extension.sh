#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# NOTE: This repo separates extension source from packaging assets:
# - `vscode-extension/` : TypeScript source and compiled `out/`.
# - `vscode-ext-package/extension/` : packaging/template assets (media, manifest).
# Cleaning removes any previously packaged Flutter web build copied into the packaging assets folder.
echo "[clean-extension] Removing Flutter web build and packaged media"
rm -rf "$ROOT_DIR/build/web" || true
rm -rf "$ROOT_DIR/vscode-ext-package/extension/media/flutter_web" || true
rm -rf "$HOME/.vscode/extensions/local.rohd-wave-viewer-vscode-0.0.1/media/flutter_web" || true
echo "[clean-extension] Done"
