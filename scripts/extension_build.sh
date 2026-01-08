#!/usr/bin/env bash
set -euo pipefail
# Build the Flutter web app and package the extension
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[extension-build] Building Flutter web app"
cd "$ROOT_DIR"
flutter build web --release --target lib/main_web.dart
echo "[extension-build] Packaging and installing extension"
"$ROOT_DIR/scripts/build_extension.sh"
echo "[extension-build] Done"
