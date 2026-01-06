#!/bin/bash
# Build script for ROHD Wave Viewer VS Code extension
# This script builds the Flutter web app with WASM support and installs it as a VS Code extension.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== ROHD Wave Viewer Build Script ==="

# Helper: run command and capture version, tolerant to missing command
capture_version() {
    local name="$1"; shift
    local cmd=("$@")
    if ! command -v "${cmd[0]}" >/dev/null 2>&1; then
        echo "${name}: not found"
        return 1
    fi
    local out
    if out="$(${cmd[@]} 2>&1)"; then
        # print first non-empty line
        local line
        line=$(printf "%s" "$out" | sed -n '1p')
        echo "${name}: ${line}"
        return 0
    else
        echo "${name}: unknown"
        return 2
    fi
}

# Compare actual vs expected, print warning if mismatch
check_version() {
    local label="$1"; local actual="$2"; local expectedEnv="$3"
    local expectedVal="${!expectedEnv}"
    if [ -n "$expectedVal" ]; then
        if [[ "$actual" != *"$expectedVal"* ]]; then
            echo "WARNING: ${label} version mismatch; expected '${expectedVal}', got '${actual}'"
        else
            echo "OK: ${label} matches expected '${expectedVal}'"
        fi
    fi
}

echo "Detected tool versions:"
FLUTTER_VER=$(capture_version "flutter" flutter --version || true)
CARGO_VER=$(capture_version "cargo" cargo --version || true)
RUSTUP_VER=$(capture_version "rustup" rustup --version || true)
WASM_PACK_VER=$(capture_version "wasm-pack" wasm-pack --version || true)
NODE_VER=$(capture_version "node" node --version || true)
NPM_VER=$(capture_version "npm" npm --version || true)
TSC_VER="$(cd vscode-extension 2>/dev/null && [ -f package.json ] && node -e "try{const p=require('./vscode-extension/package.json'); console.log((p.devDependencies && p.devDependencies.typescript)||p.dependencies.typescript||'') }catch(e){}" 2>/dev/null || true)"
if [ -n "$TSC_VER" ]; then
  echo "typescript (declared in package.json): ${TSC_VER}"
fi

# Print the captured versions so they are visible in stdout
echo "$FLUTTER_VER"
echo "$CARGO_VER"
echo "$RUSTUP_VER"
echo "$WASM_PACK_VER"
echo "$NODE_VER"
echo "$NPM_VER"

# Optional environment variables you can set to assert versions, e.g. EXPECT_FLUTTER
# check_version "flutter" "$FLUTTER_VER" EXPECT_FLUTTER
# check_version "cargo" "$CARGO_VER" EXPECT_CARGO


# Check for required tools
command -v flutter >/dev/null 2>&1 || { echo "Error: flutter not found"; exit 1; }
command -v cargo >/dev/null 2>&1 || { echo "Error: cargo not found"; exit 1; }
# Ensure cargo bin directory is on PATH so installed tools like wasm-pack are found
export PATH="${HOME}/.cargo/bin:${PATH}"

# Check for wasm-pack; attempt to install it automatically if missing
if ! command -v wasm-pack >/dev/null 2>&1; then
    echo "wasm-pack not found. Attempting to install via 'cargo install wasm-pack'..."
    if command -v cargo >/dev/null 2>&1; then
        cargo install wasm-pack || {
            echo "Automatic install of wasm-pack failed. Please install manually: cargo install wasm-pack";
            exit 1;
        }
    else
        echo "Error: cargo not found. Cannot install wasm-pack. Please install Rust and cargo first.";
        exit 1;
    fi
fi

# Ensure Rust nightly and wasm32 target are available
echo "Checking Rust toolchain..."
rustup toolchain list | grep -q nightly || rustup toolchain install nightly
rustup target add wasm32-unknown-unknown --toolchain nightly 2>/dev/null || true
rustup component add rust-src --toolchain nightly 2>/dev/null || true

# Step 1: Build WASM with flutter_rust_bridge
echo ""
echo "=== Step 1: Building WASM bindings ==="
echo "Generating Dart bindings from Rust API..."
rustup run nightly flutter_rust_bridge_codegen generate --config-file flutter_rust_bridge.yaml

echo "Compiling Rust to WebAssembly (--target no-modules for VS Code webview)..."
cd rust/wellen_bridge
export PATH="${HOME}/.cargo/bin:${PATH}"
rustup run nightly wasm-pack build --target no-modules --out-dir ../../web/pkg
cd ../..
echo "✓ WASM bindings built"

# Step 2: Build Flutter web using web-specific entry point
echo ""
echo "=== Step 2: Building Flutter web app ==="
echo "Building Flutter web with lib/main_web.dart (web-specific entry point)..."
flutter build web --release --target lib/main_web.dart
echo "✓ Flutter web app built"

# Step 3: Fix flutter_bootstrap.js for webview compatibility
echo ""
echo "=== Step 3: Fixing flutter_bootstrap.js for webview ==="
echo "Adding useLocalCanvasKit and removing service worker settings..."
python3 fix_bootstrap.py
echo "✓ flutter_bootstrap.js fixed"

# Step 4: Copy WASM pkg to build output (if not already there)
echo ""
echo "=== Step 4: Ensuring WASM pkg is in build output ==="
if [ -d "web/pkg" ]; then
    echo "Copying WASM package to Flutter build output..."
    rm -rf build/web/pkg
    cp -r web/pkg build/web/
    echo "✓ WASM package copied"
else
    echo "Error: web/pkg not found. WASM build may have failed."
    exit 1
fi

# Step 5: Compile TypeScript extension
echo ""
echo "=== Step 5: Compiling VS Code extension ==="
echo "Installing npm dependencies..."
cd vscode-extension
npm install
echo "Compiling TypeScript to JavaScript..."
npm run compile
cd ..
echo "✓ VS Code extension compiled"

# Step 6: Install extension
echo ""
echo "=== Step 6: Installing VS Code extension ==="
EXTENSION_DIR="$HOME/.vscode/extensions/local.rohd-wave-viewer-vscode-0.0.1"
echo "Installing to: $EXTENSION_DIR"
rm -rf "$EXTENSION_DIR"
mkdir -p "$EXTENSION_DIR"

# Copy extension files
echo "Copying extension files..."
cp -r vscode-ext-package/extension/* "$EXTENSION_DIR/"

# Copy compiled extension.js
echo "Copying compiled extension code..."
cp vscode-extension/out/extension.js "$EXTENSION_DIR/out/"

# Copy Flutter web build
echo "Copying Flutter web app..."
cp -r build/web "$EXTENSION_DIR/media/flutter_web"
echo "✓ Extension installed"

echo ""
echo "=== Build Complete ==="
echo "Extension installed to: $EXTENSION_DIR"
echo ""
echo "Please reload VS Code (Developer: Reload Window) to activate the extension."
echo "Then open any .vcd file to view waveforms."
