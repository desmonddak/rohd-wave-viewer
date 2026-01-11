#!/usr/bin/env bash
set -euo pipefail
# Legacy shim: the wellen_bridge build script now lives in rust/wellen_bridge/build.sh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
echo "[build-wellen] Deprecated: use rust/wellen_bridge/build.sh"
exec "$ROOT_DIR/rust/wellen_bridge/build.sh"
