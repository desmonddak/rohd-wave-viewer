#!/usr/bin/env bash
set -euo pipefail
# Clean compiled Rust artifacts and generated bindings
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
echo "[clean] Cleaning Rust target dirs and wasm/pkg outputs"
rm -rf "$ROOT_DIR/rust/wellen_bridge/target" || true
rm -rf "$ROOT_DIR/rust/pkg" || true
rm -rf "$ROOT_DIR/web/pkg" || true

echo "[clean] Removing generated FRB files (Dart & Rust) and temp FRB configs"
mapfile -d $'\0' -t CLEAN_FILES < <(find "$ROOT_DIR" -type f \( -name 'frb_generated*.rs' -o -name 'frb_generated*.dart' -o -path '*/lib/src/rust/frb_*.dart' -o -name 'flutter_rust_bridge.generated.*.yaml' \) -print0)
if [ ${#CLEAN_FILES[@]} -gt 0 ]; then
	printf "%s\n" "${CLEAN_FILES[@]}"
	rm -f "${CLEAN_FILES[@]}"
else
	echo "[clean] No generated FRB files found"
fi

echo "[clean] Done"
