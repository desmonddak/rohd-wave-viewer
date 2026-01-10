#!/usr/bin/env bash
set -euo pipefail

# Run tests with LD_LIBRARY_PATH set to Rust wellen bridge build output
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Set LD_LIBRARY_PATH to include the wellen_bridge release build
export LD_LIBRARY_PATH="${ROOT_DIR}/rust/wellen_bridge/target/release:${LD_LIBRARY_PATH:-}"

echo "[run-tests] LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
echo "[run-tests] Running dart tests..."

# Run tests from project root
cd "$ROOT_DIR"

# Run the simplified wellen reader tests
dart test packages/dart_wellen/test/wellen_reader_simple_test.dart "$@"
