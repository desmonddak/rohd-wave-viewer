#!/usr/bin/env bash
set -euo pipefail
# Generate flutter_rust_bridge bindings for the repo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source rust env setup
source "$ROOT_DIR/scripts/setup_rust_env.sh"

echo "[frb-gen] Running flutter_rust_bridge_codegen..."

# Try to find libclang for ffigen
find_libclang() {
    if command -v ldconfig >/dev/null 2>&1; then
        ldconfig -p 2>/dev/null | awk '/libclang\.so/ {print $NF}' | head -n1
    fi
    return 0
}

_libclang=$(find_libclang)
if [ -z "$_libclang" ]; then
    _libclang=$(find /usr/lib /usr/lib64 /usr/lib/x86_64-linux-gnu /usr/local/lib /usr/lib/llvm-* -name 'libclang.so*' -print -quit 2>/dev/null || true)
fi
if [ -n "$_libclang" ]; then
    export LIBCLANG_PATH="$(dirname "$_libclang")"
    echo "[frb-gen] Found libclang: $_libclang"
    echo "[frb-gen] Setting LIBCLANG_PATH=$LIBCLANG_PATH"
else
    echo "[frb-gen] WARNING: libclang not found. ffigen may fail."
fi

# Ensure flutter_rust_bridge_codegen is installed (use cargo install if missing)
if ! command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
    echo "[frb-gen] flutter_rust_bridge_codegen not found; installing via cargo..."
    cargo install flutter_rust_bridge_codegen --version 2.7.0 --locked
fi

ORIG_CFG="$ROOT_DIR/packages/rohd_wellen/flutter_rust_bridge.yaml"
ORIG_DIR="$(dirname "$ORIG_CFG")"
TMP_CFG="$ORIG_DIR/flutter_rust_bridge.generated.$(date +%s).yaml"

if [ ! -f "$ORIG_CFG" ]; then
        echo "[frb-gen] ERROR: original config not found at $ORIG_CFG" >&2
        exit 1
fi


# Compute absolute paths for rust entries so codegen can compute Rust module paths
ABS_RUST_ROOT="$ROOT_DIR/rust/wellen_bridge"
ABS_RUST_OUTPUT="$ROOT_DIR/rust/wellen_bridge/src/frb_generated.rs"

echo "[frb-gen] Rewriting rust_root -> $ABS_RUST_ROOT"
echo "[frb-gen] Rewriting rust_output -> $ABS_RUST_OUTPUT"

# Keep dart_output and dart_root as package-local (they are already correct)
sed -E \
    -e "s|^rust_root:.*$|rust_root: $ABS_RUST_ROOT|" \
    -e "s|^rust_output:.*$|rust_output: $ABS_RUST_OUTPUT|" \
    "$ORIG_CFG" > "$TMP_CFG"

# Ensure dart_root is empty in the generated config so the generator will
# resolve package files (pubspec.yaml) from the package base_dir.
if grep -q "^dart_root:" "$TMP_CFG"; then
    sed -i 's|^dart_root:.*$|dart_root: "."|' "$TMP_CFG"
else
    printf "\ndart_root: \".\"\n" >> "$TMP_CFG"
fi

echo "[frb-gen] Using temporary config $TMP_CFG"

# Run codegen using the selected rustup with the temporary config
echo "[frb-gen] Temporary config contents:" 
sed -n '1,200p' "$TMP_CFG"

# Ensure nightly toolchain is available
if ! "$RUSTUP_BIN" toolchain list | grep -q "$RUST_TOOLCHAIN"; then
    echo "[frb-gen] Rust toolchain $RUST_TOOLCHAIN not found; attempting to install..."
    if ! "$RUSTUP_BIN" toolchain install "$RUST_TOOLCHAIN"; then
        echo "[frb-gen] ERROR: failed to install $RUST_TOOLCHAIN via $RUSTUP_BIN" >&2
        echo "Please install the toolchain manually, e.g:" >&2
        echo "  $RUSTUP_BIN toolchain install $RUST_TOOLCHAIN" >&2
        rm -f "$TMP_CFG"
        exit 1
    fi
fi

echo "[frb-gen] Invoking: $RUSTUP_BIN run $RUST_TOOLCHAIN flutter_rust_bridge_codegen generate --config-file $TMP_CFG (from packages/rohd_wellen)"
pushd "$ROOT_DIR/packages/rohd_wellen" >/dev/null
"$RUSTUP_BIN" run "$RUST_TOOLCHAIN" flutter_rust_bridge_codegen generate --config-file "$TMP_CFG"
popd >/dev/null

echo "[frb-gen] flutter_rust_bridge_codegen finished"

# Clean up temporary config
rm -f "$TMP_CFG"
