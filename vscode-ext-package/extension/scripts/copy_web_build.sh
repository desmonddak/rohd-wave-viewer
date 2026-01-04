#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/web"
MEDIA_DIR="$ROOT_DIR/media"

if [ ! -d "$BUILD_DIR" ]; then
  echo "Flutter build not found at $BUILD_DIR"
  echo "Run: flutter build web" >&2
  exit 1
fi

rm -rf "$MEDIA_DIR"
mkdir -p "$MEDIA_DIR"
cp -r "$BUILD_DIR"/* "$MEDIA_DIR/"

# Remove service worker registration (if present)
if grep -q "navigator.serviceWorker" "$MEDIA_DIR/index.html"; then
  sed -i.bak -E "s/\s*navigator\.serviceWorker\.register\([^)]+\);?//g" "$MEDIA_DIR/index.html" || true
fi

# Ensure base href is relative
sed -i.bak -E "s#<base href=\"/\">#<base href=\"./\">#g" "$MEDIA_DIR/index.html" || true

echo "Copied web build to $MEDIA_DIR"
