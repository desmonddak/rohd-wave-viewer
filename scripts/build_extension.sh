#!/bin/bash
# Build script for ROHD Wave Viewer VS Code extension
# This script builds the Flutter web app and installs it as a VS Code extension.
# 
# NOTE: This script assumes Rust bindings and WASM have already been generated.
# Run full_build.sh for a complete build, or run generate_frb.sh and build_rust_wasm.sh
# separately before running this script.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

echo "=== ROHD Wave Viewer Extension Build Script ==="

# Check for required tools
# If node/npm aren't on PATH, attempt to source a per-user nvm install.
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  if [ -s "$HOME/.nvm/nvm.sh" ]; then
    echo "Sourcing nvm from $HOME/.nvm/nvm.sh to expose node/npm"
    # shellcheck source=/dev/null
    . "$HOME/.nvm/nvm.sh"
    # try to use default alias if present
    if command -v nvm >/dev/null 2>&1; then
      nvm use default >/dev/null 2>&1 || true
    fi
  fi
fi

command -v flutter >/dev/null 2>&1 || { echo "Error: flutter not found"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "Error: node not found"; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "Error: npm not found"; exit 1; }

echo "Detected tool versions:"
flutter --version | head -1
node --version
npm --version

# Verify WASM package exists (should have been built by build_rust_wasm.sh)
if [ ! -d "web/pkg" ]; then
  echo "Error: web/pkg not found. Run full_build.sh or build_rust_wasm.sh first."
  exit 1
fi

# Step 1: Build Flutter web using web-specific entry point
echo ""
echo "=== Step 1: Building Flutter web app ==="
echo "Building Flutter web with lib/main_web.dart (web-specific entry point)..."
flutter build web --release --target lib/main_web.dart
echo "✓ Flutter web app built"

# Step 2: Fix flutter_bootstrap.js for webview compatibility
echo ""
echo "=== Step 2: Fixing flutter_bootstrap.js for webview ==="
echo "Adding useLocalCanvasKit and removing service worker settings..."
python3 scripts/fix_bootstrap.py
echo "✓ flutter_bootstrap.js fixed"

# Step 3: Copy WASM pkg to build output (if not already there)
echo ""
echo "=== Step 3: Ensuring WASM pkg is in build output ==="
echo "Copying WASM package to Flutter build output..."
rm -rf build/web/pkg
cp -r web/pkg build/web/
echo "✓ WASM package copied"

# Step 4: Patch WASM for VS Code webview compatibility
echo ""
echo "=== Step 4: Patching WASM for VS Code webview compatibility ==="
if ! command -v wasm2wat >/dev/null 2>&1 || ! command -v wat2wasm >/dev/null 2>&1; then
  echo "WARNING: wabt tools (wasm2wat, wat2wasm) not found."
  echo "The extension may fail in VS Code Remote environments without this patch."
  echo "Install wabt: Ubuntu/Debian: sudo apt install wabt"
  echo "Skipping WASM patching..."
else
  WASM_FILE="build/web/pkg/wellen_bridge_bg.wasm"
  JS_FILE="build/web/pkg/wellen_bridge.js"
  WAT_FILE="/tmp/wellen_bridge_patched.wat"
    
  if [ -f "$WASM_FILE" ]; then
    echo "Converting WASM to WAT..."
    wasm2wat "$WASM_FILE" --enable-all -o "$WAT_FILE"
        
    echo "Patching externref table size (128 -> 132)..."
    sed -i 's/(table (;1;) 128 externref)/(table (;1;) 132 externref)/' "$WAT_FILE"
        
    echo "Fixing __wbindgen_externrefs export to point to externref table..."
    sed -i 's/(export "__wbindgen_externrefs" (table 0))/(export "__wbindgen_externrefs" (table 1))/' "$WAT_FILE"
        
    echo "Rebuilding patched WASM..."
    wat2wasm "$WAT_FILE" --enable-all -o "$WASM_FILE"
        
    if command -v wasm-objdump >/dev/null 2>&1; then
      echo "Verifying patch..."
      wasm-objdump -x "$WASM_FILE" 2>/dev/null | grep -E 'table\[1\].*externref|table\[1\] ->' || true
    fi
        
    rm -f "$WAT_FILE"
    echo "✓ WASM binary patched"
  else
    echo "Warning: $WASM_FILE not found, skipping WASM patching"
  fi
    
  if [ -f "$JS_FILE" ]; then
    echo "Patching JS for table.grow() fallback..."
    python3 - "$JS_FILE" << 'PYTHON_PATCH'
import sys
import re

js_file = sys.argv[1]
with open(js_file, 'r') as f:
  content = f.read()

old_pattern = r'''imports\.wbg\.__wbindgen_init_externref_table = function\(\) \{\n            const table = wasm\.__wbindgen_externrefs;\n            const offset = table\.grow\(4\);\n            table\.set\(0, undefined\);\n            table\.set\(offset \+ 0, undefined\);\n            table\.set\(offset \+ 1, null\);\n            table\.set\(offset \+ 2, true\);\n            table\.set\(offset \+ 3, false\);\n        \};'''

new_code = '''imports.wbg.__wbindgen_init_externref_table = function() {
      const table = wasm.__wbindgen_externrefs;
      // Patched: Try to grow, but if it fails (e.g., in VS Code Remote webview sandbox),
      // use existing table space. We pre-allocated extra space in the wasm binary.
      let offset;
      try {
        offset = table.grow(4);
      } catch (e) {
        console.warn('Table.grow(4) failed, using fallback:', e.message);
        // Fallback: Use indices at the end of the pre-allocated table (slots 128-131)
        offset = table.length - 4;
      }
      table.set(0, undefined);
      table.set(offset + 0, undefined);
      table.set(offset + 1, null);
      table.set(offset + 2, true);
      table.set(offset + 3, false);
    };'''

if re.search(old_pattern, content):
  content = re.sub(old_pattern, new_code, content)
  with open(js_file, 'w') as f:
    f.write(content)
  print("✓ JS patched with table.grow() fallback")
elif 'using fallback' in content:
  print("✓ JS already patched")
else:
  print("Warning: Could not find expected pattern in JS file, manual patching may be needed")
PYTHON_PATCH
  else
    echo "Warning: $JS_FILE not found, skipping JS patching"
  fi
fi

# Step 5: Compile VS Code extension
echo ""
echo "=== Step 5: Compiling VS Code extension ==="
echo "Installing npm dependencies..."
cd vscode-extension
npm install
echo "Compiling TypeScript to JavaScript..."
npm run compile
cd ..
echo "✓ VS Code extension compiled"

# Step 6: Install VS Code extension
echo ""
echo "=== Step 6: Installing VS Code extension ==="
EXTENSION_DIR="$HOME/.vscode/extensions/local.rohd-wave-viewer-vscode-0.0.1"
echo "Installing to: $EXTENSION_DIR"
rm -rf "$EXTENSION_DIR"
mkdir -p "$EXTENSION_DIR"

echo "Copying extension files..."
cp -r vscode-ext-package/extension/* "$EXTENSION_DIR/"

echo "Copying compiled extension code..."
if [ -e "$EXTENSION_DIR/out" ] && [ ! -d "$EXTENSION_DIR/out" ]; then
  rm -f "$EXTENSION_DIR/out"
fi
mkdir -p "$EXTENSION_DIR/out"
cp vscode-extension/out/extension.js "$EXTENSION_DIR/out/"

echo "Copying Flutter web app..."
if [ ! -d "build/web" ]; then
  echo "Error: build/web not found. Flutter web build may have failed."
  exit 1
fi

# Ensure media directory exists and avoid collisions
if [ -e "$EXTENSION_DIR/media" ] && [ ! -d "$EXTENSION_DIR/media" ]; then
  rm -f "$EXTENSION_DIR/media"
fi
mkdir -p "$EXTENSION_DIR/media"
rm -rf "$EXTENSION_DIR/media/flutter_web"
cp -r build/web "$EXTENSION_DIR/media/flutter_web"
echo "✓ Extension installed"

echo ""
echo "=== Build Complete ==="
echo "Extension installed to: $EXTENSION_DIR"
echo ""
echo "Please reload VS Code (Developer: Reload Window) to activate the extension."
echo "Then open any .vcd file to view waveforms."

# If running inside a remote container or SSH host that uses the vscode-server,
# also copy the installed extension into the server extensions dir so the
# remote Extension Host can load the compiled `out/` and `media/` assets.
REMOTE_SERVER_EXT_DIR="$HOME/.vscode-server/extensions/local.rohd-wave-viewer-vscode-0.0.1"
if [ -d "$HOME/.vscode-server" ]; then
  echo "Detected ~/.vscode-server; installing extension into remote server extensions directory: $REMOTE_SERVER_EXT_DIR"
  rm -rf "$REMOTE_SERVER_EXT_DIR"
  mkdir -p "$(dirname "$REMOTE_SERVER_EXT_DIR")"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "$EXTENSION_DIR/" "$REMOTE_SERVER_EXT_DIR/"
  else
    cp -a "$EXTENSION_DIR/." "$REMOTE_SERVER_EXT_DIR/"
  fi
  chown -R $(id -u):$(id -g) "$REMOTE_SERVER_EXT_DIR" || true
  echo "✓ Extension copied to remote server extensions directory"
fi

# Optionally build a .vsix package
VSIX_SCRIPT="$SCRIPT_DIR/build_vsix.tcsh"
if [ -x "$VSIX_SCRIPT" ]; then
  echo "Building .vsix package using $VSIX_SCRIPT..."
  if command -v bash >/dev/null 2>&1; then
    bash "$VSIX_SCRIPT" || {
      echo "Warning: Building .vsix failed; the rest of the build succeeded. You can run $VSIX_SCRIPT manually.";
    }
  else
    "$VSIX_SCRIPT" || {
      echo "Warning: Building .vsix failed; the rest of the build succeeded. You can run $VSIX_SCRIPT manually.";
    }
  fi
else
  echo "Note: VSIX packaging script not found or not executable at $VSIX_SCRIPT. Skipping .vsix build."
fi

