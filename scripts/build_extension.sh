#!/bin/bash
# Build script for ROHD Wave Viewer VS Code extension
# This script builds the Flutter web app with WASM support and installs it as a VS Code extension.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

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

echo "$FLUTTER_VER"
echo "$CARGO_VER"
echo "$RUSTUP_VER"
echo "$WASM_PACK_VER"
echo "$NODE_VER"
echo "$NPM_VER"

# Check for required tools
command -v flutter >/dev/null 2>&1 || { echo "Error: flutter not found"; exit 1; }
command -v cargo >/dev/null 2>&1 || { echo "Error: cargo not found"; exit 1; }
export PATH="${HOME}/.cargo/bin:${PATH}"

export CARGO_HOME="${HOME}/.cargo"
export RUSTUP_HOME="${HOME}/.rustup"
export PATH="${CARGO_HOME}/bin:${PATH}"

echo "Using CARGO_HOME: $CARGO_HOME"
echo "Using RUSTUP_HOME: $RUSTUP_HOME"
echo "Using PATH: $PATH"
if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER-}" ]; then
  INVOKER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
  INVOKER_HOME="$HOME"
fi

_CARGO_RAW="${CARGO_HOME:-${INVOKER_HOME}/.cargo}"
_RUSTUP_RAW="${RUSTUP_HOME:-${INVOKER_HOME}/.rustup}"
export CARGO_HOME="${_CARGO_RAW%%:*}"
export RUSTUP_HOME="${_RUSTUP_RAW%%:*}"

echo "Using CARGO_HOME: $CARGO_HOME"
echo "Using RUSTUP_HOME: $RUSTUP_HOME"

export PATH="$CARGO_HOME/bin:$PATH"
echo "Using PATH: $PATH"

RUSTUP_BIN="$CARGO_HOME/bin/rustup"
if [ ! -x "$RUSTUP_BIN" ]; then
  if command -v rustup >/dev/null 2>&1; then
    RUSTUP_BIN="$(command -v rustup)"
  else
    RUSTUP_BIN=""
  fi
fi
if [ -z "$RUSTUP_BIN" ]; then
  echo "Error: rustup not found in $CARGO_HOME/bin or PATH. Please install rustup.";
  exit 1;
fi
echo "Using rustup: $RUSTUP_BIN"

if [ -n "$RUSTUP_BIN" ]; then
  if ! "$RUSTUP_BIN" show active-toolchain >/dev/null 2>&1; then
    echo "No default Rust toolchain configured; installing 'stable' and setting it as default..."
    "$RUSTUP_BIN" default stable || {
      echo "Failed to set default toolchain. Please run '$RUSTUP_BIN default stable' manually as the owning user.";
    }
  fi
fi

_CARGO_RAW="${CARGO_HOME:-${HOME}/.cargo}"
_RUSTUP_RAW="${RUSTUP_HOME:-${HOME}/.rustup}"
export CARGO_HOME="${_CARGO_RAW%%:*}"
export RUSTUP_HOME="${_RUSTUP_RAW%%:*}"

for dir in "$CARGO_HOME" "$RUSTUP_HOME"; do
  if [ -e "$dir" ]; then
    owner=$(stat -c %U "$dir" 2>/dev/null || true)
    if [ "$owner" = "root" ]; then
      echo "Error: $dir is owned by root. This can happen if Rust/cargo was run with sudo."
      echo "Please fix ownership so your user can write there, for example:"
      echo "  sudo chown -R $(id -u):$(id -g) $dir"
      exit 1
    fi
  fi
done

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

if [ -d "$HOME/.cache/.wasm-pack" ]; then
  cache_bin=$(find "$HOME/.cache/.wasm-pack" -type d -path '*/bin' -print -quit 2>/dev/null || true)
  if [ -n "$cache_bin" ]; then
    export PATH="$cache_bin:$PATH"
    echo "Added wasm-pack cache bin to PATH: $cache_bin"
  fi
fi

if [ -z "${FORCE_CARGO_INSTALL-}" ]; then
  if ! command -v wasm-bindgen >/dev/null 2>&1; then
    echo "wasm-bindgen not found. Installing via 'cargo install -f wasm-bindgen-cli'..."
    cargo install -f wasm-bindgen-cli || {
      echo "Automatic install of wasm-bindgen-cli failed. Please install manually: cargo install -f wasm-bindgen-cli";
      exit 1;
    }
  else
    echo "wasm-bindgen detected; skipping cargo install. Set FORCE_CARGO_INSTALL=1 to reinstall."
  fi
else
  echo "FORCE_CARGO_INSTALL set; reinstalling wasm-bindgen-cli"
  cargo install -f wasm-bindgen-cli || {
    echo "Automatic install of wasm-bindgen-cli failed. Please install manually: cargo install -f wasm-bindgen-cli";
    exit 1;
  }
fi

echo "Checking Rust toolchain..."
"$RUSTUP_BIN" toolchain list | grep -q nightly || "$RUSTUP_BIN" toolchain install nightly
"$RUSTUP_BIN" target add wasm32-unknown-unknown --toolchain nightly 2>/dev/null || true
"$RUSTUP_BIN" component add rust-src --toolchain nightly 2>/dev/null || true

echo ""
echo "=== Step 1: Generating bindings and building WASM ==="
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

"$ROOT_DIR/scripts/generate_frb.sh"
"$ROOT_DIR/scripts/build_rust_wasm.sh"
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
python3 scripts/fix_bootstrap.py
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

echo ""
echo "=== Step 5: Patching WASM for VS Code webview compatibility ==="
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

echo ""
echo "=== Step 6: Compiling VS Code extension ==="
echo "Installing npm dependencies..."
cd vscode-extension
if ! command -v node >/dev/null 2>&1; then
  echo "Error: node not found. Please install Node.js (recommended via nvm or your package manager)."
  echo "Ubuntu/Debian example: sudo apt update && sudo apt install -y nodejs npm"
  exit 1
fi
if ! command -v npm >/dev/null 2>&1; then
  echo "Error: npm not found. Please install npm (often provided with Node.js)."
  echo "Ubuntu/Debian example: sudo apt update && sudo apt install -y nodejs npm"
  exit 1
fi

npm install
echo "Compiling TypeScript to JavaScript..."
npm run compile
cd ..
echo "✓ VS Code extension compiled"

echo ""
echo "=== Step 7: Installing VS Code extension ==="
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

## Optionally build a .vsix package (script lives in scripts/). This is
## guarded: only run if the packaging script exists and is executable.
VSIX_SCRIPT="$SCRIPT_DIR/scripts/build_vsix.tcsh"
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

