#!/usr/bin/env bash
set -euo pipefail
# Backup generated FRB-related files (Rust and Dart) into build_backups with a timestamp
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TS="$(date +%Y%m%dT%H%M%S)"
DEST="$ROOT_DIR/build_backups/generated.$TS"
mkdir -p "$DEST"
echo "[backup] Saving generated files to $DEST"
cd "$ROOT_DIR"

# Use a simpler find expression (portable) and create a tar.gz
mapfile -d $'\0' -t FILES < <(find . -type f \( -name 'frb_generated*.rs' -o -name 'frb_*.rs' -o -name 'frb_generated*.dart' -o -path './packages/*/lib/src/rust/*.dart' \) -print0)

if [ ${#FILES[@]} -eq 0 ]; then
  echo "[backup] No generated files found; nothing to archive"
  rmdir "$DEST" || true
  exit 0
fi

tar -czf "$DEST/files.$TS.tar.gz" "${FILES[@]}"

echo "[backup] Archive created: $DEST/files.$TS.tar.gz"
echo "[backup] Contents:"
tar -tzf "$DEST/files.$TS.tar.gz" | sed -n '1,200p'

echo "[backup] Done"

