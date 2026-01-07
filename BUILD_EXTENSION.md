# ROHD Wave Viewer - VS Code Extension Build Guide

This document describes how to build and install the ROHD Wave Viewer as a VS Code extension.

## Prerequisites

### Cargo Binary Path

The build scripts use `${HOME}/.cargo/bin` in the PATH to ensure Rust-installed tools (like `wasm-pack`) are available. When you install Rust via `rustup`, binaries are placed in `~/.cargo/bin/`:

```bash
# Verify cargo is installed and check its location
which cargo

# Verify wasm-pack is in .cargo/bin
ls ~/.cargo/bin/wasm-pack
```

The build script adds this to PATH:

```bash
export PATH="${HOME}/.cargo/bin:${PATH}"
```

This ensures `wasm-pack`, `cargo`, and other Rust tools are found first in the PATH.

### Required Tools

1. **Flutter SDK** (3.3.0 or later)

   ```bash
   flutter --version
   ```

2. **Rust** (nightly toolchain required for WASM)

   ```bash
   # Install Rust
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   
   # Install nightly toolchain
   rustup toolchain install nightly
   
   # Add WASM target
   rustup target add wasm32-unknown-unknown --toolchain nightly
   
   # Add rust-src component (required for build-std)
   rustup component add rust-src --toolchain nightly
   ```

3. **wasm-pack** (Rust WASM compilation tool - installs to ~/.cargo/bin)

   ```bash
   cargo install wasm-pack
   ```

4. **flutter_rust_bridge_codegen** (Dart FFI code generator)

   ```bash
   dart pub global activate flutter_rust_bridge
   ```

5. **Node.js and npm** (for TypeScript extension compilation)

   ```bash
   node --version
   npm --version
   ```

## Quick Build

Run the build script:

```bash
./scripts/build_extension.sh
```

This will:

1. Build WASM bindings for the wellen Rust library
2. Build the Flutter web app
3. Fix flutter_bootstrap.js for webview compatibility
4. Compile the VS Code extension TypeScript
5. Install the extension to `~/.vscode/extensions/`

## Manual Build Steps

### Step 1: Build WASM Bindings

Before building, ensure the Rust tools are in your PATH:

```bash
export PATH="${HOME}/.cargo/bin:${PATH}"
```

**For tcsh shell**, use `setenv` instead:

```tcsh
setenv PATH "${HOME}/.cargo/bin:${PATH}"
```

Generate the Dart bindings from the Rust API:

```bash
rustup run nightly flutter_rust_bridge_codegen generate --config-file flutter_rust_bridge.yaml
```

Then compile the Rust `wellen_bridge` crate to WebAssembly using `--target no-modules` (required for VS Code webview compatibility):

```bash
cd rust/wellen_bridge
rustup run nightly wasm-pack build --target no-modules --out-dir ../../web/pkg
cd ../..
```

**Why `setenv PATH "${HOME}/.cargo/bin:${PATH}"`?**

- When you install Rust tools with `cargo install wasm-pack`, they are placed in `~/.cargo/bin/`
- This directory must be in your PATH for the shell to find `wasm-pack`
- The build prepends this path to ensure these tools are found first
- On tcsh, use `setenv` instead of `export`

**Important WASM Flags**:

- `--target no-modules`: Generates a global `wasm_bindgen` object instead of ES module exports. VS Code webviews do not support ES module syntax in iframes.
- `--release` is implied in wasm-pack
- All Rust functions must be marked with `#[frb(sync)]` to avoid WorkerPool creation (VS Code webviews don't support SharedArrayBuffer for worker threading)

This compiles the Rust `wellen_bridge` crate to WebAssembly and generates:

- `web/pkg/wellen_bridge.js` - JavaScript bindings (no ES module exports with `--target no-modules`)
- `web/pkg/wellen_bridge_bg.wasm` - WebAssembly module
- `web/pkg/wellen_bridge_bg.wasm` - WebAssembly module

### Step 2: Build Flutter Web App

```bash
flutter build web --release --target lib/main_web.dart
```

**Important**: Use `lib/main_web.dart` as the target, not `lib/main.dart`. The web entry point:

- Disables URL strategies (required for VS Code webview)
- Initializes WASM via `WellenModuleStructureApi.init()` which calls the global `wasm_bindgen()` function
- Sets up message handling for VCD content from the extension
- The WASM module is loaded from `web/index.html` before Flutter initializes

### Step 3: Fix flutter_bootstrap.js

The Flutter build output needs modifications for VS Code webview:

```bash
python3 scripts/fix_bootstrap.py
```

This script:

- Adds `"useLocalCanvasKit": true` to use bundled CanvasKit (avoids CSP issues)
- Removes service worker settings (not supported in webviews)

### Step 4: Compile VS Code Extension

```bash
cd vscode-extension
npm install
npm run compile
cd ..
```

### Step 5: Install Extension

```bash
# Remove old installation
rm -rf ~/.vscode/extensions/local.rohd-wave-viewer-vscode-0.0.1

# Create extension directory
mkdir -p ~/.vscode/extensions/local.rohd-wave-viewer-vscode-0.0.1

# Copy extension files
cp -r vscode-ext-package/extension/* ~/.vscode/extensions/local.rohd-wave-viewer-vscode-0.0.1/
cp vscode-extension/out/extension.js ~/.vscode/extensions/local.rohd-wave-viewer-vscode-0.0.1/out/
cp -r build/web ~/.vscode/extensions/local.rohd-wave-viewer-vscode-0.0.1/media/flutter_web
```

### Step 6: Reload VS Code

Use Command Palette: `Developer: Reload Window`

## Usage

After installation, open any `.vcd` file in VS Code. The ROHD Wave Viewer will:

1. Load the Flutter web app in a webview
2. Initialize the wellen WASM module
3. Parse the VCD file contents
4. Display the waveform data

## Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                    VS Code Extension                         │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              extension.ts                            │    │
│  │  - Registers custom editor for .vcd files           │    │
│  │  - Creates webview with Flutter web app             │    │
│  │  - Reads VCD file and sends via postMessage         │    │
│  └─────────────────────────────────────────────────────┘    │
│                          ↓ postMessage                       │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Flutter Web App                         │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │  main_web.dart                              │    │    │
│  │  │  - Receives VCD content via JS interop      │    │    │
│  │  │  - Passes to WellenModuleStructureApi       │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │  rohd_wellen (Dart package)                 │    │    │
│  │  │  - WellenModuleStructureApi                 │    │    │
│  │  │  - flutter_rust_bridge FFI                  │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  │                        ↓                              │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │  wellen_bridge (Rust → WASM)                │    │    │
│  │  │  - VCD/FST/GHW parsing via wellen crate     │    │    │
│  │  │  - Compiled to WebAssembly                  │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## VS Code Webview WASM Configuration

VS Code webviews have strict sandboxing that affects WASM:

1. **No SharedArrayBuffer**: WASM WorkerPool threads cannot be used. All Rust functions must be synchronous (`#[frb(sync)]`).

2. **No ES Modules**: The webview iframe doesn't support ES module exports. Use `wasm-pack build --target no-modules` to generate a global `wasm_bindgen` object instead.

3. **No Service Workers**: Cannot register service workers. Set `"serviceWorkerVersion": false` in flutter_bootstrap.js or remove all service worker logic.

4. **CSP Headers**: The `wasm-unsafe-eval` CSP directive is required in the extension manifest for WASM to execute.

### Rust Function Markers

All functions exposed via flutter_rust_bridge must use the sync attribute:

```rust
#[frb(sync)]
pub fn load_waveform_from_bytes(bytes: Vec<u8>) -> Result<WaveformMetadata, String> {
    // Implementation
}
```

This prevents the codec from attempting to create async worker threads.

### "Extension not activating"

- Check Developer Tools console for errors
- Ensure extension.js is compiled: `cd vscode-extension && npm run compile`

### "wasm-pack command not found" or "cargo command not found"

- **Cause**: `~/.cargo/bin` is not in your PATH
- **Fix**: Add to your shell profile (~/.bashrc, ~/.zshrc, or ~/.tcshrc):

  ```bash
  export PATH="$HOME/.cargo/bin:$PATH"  # bash/zsh
  ```

  Or for tcsh:

  ```tcsh
  setenv PATH "$HOME/.cargo/bin:$PATH"
  ```

- **Temporary**: Run build with explicit PATH: `export PATH="${HOME}/.cargo/bin:${PATH}" && ./scripts/build_extension.sh`

### "flutter_rust_bridge_codegen not found"

- **Cause**: Dart global packages not in PATH
- **Fix**: Ensure Dart bin directory is in PATH and reactivate:

  ```bash
  dart pub global activate flutter_rust_bridge
  ```

- **Verify**: `which flutter_rust_bridge_codegen` should show the path

### "Unexpected token 'export'" or "export is not defined"

- **Cause**: Using `wasm-pack build --target web` which generates ES module syntax
- **Fix**: Use `wasm-pack build --target no-modules` instead

### "Failed to create WorkerPool: DataCloneError"

- **Cause**: Rust functions are not marked with `#[frb(sync)]`, causing WorkerPool creation attempts
- **Fix**: Add `#[frb(sync)]` to all functions in `rust/wellen_bridge/src/api.rs` and regenerate bindings

### "wasm_bindgen is not defined"

- **Cause**: The WASM script hasn't loaded before initialization
- **Fix**: Ensure `<script src="pkg/wellen_bridge.js"></script>` is in `web/index.html` before the flutter-init script

### "No waveform loaded" error in Module Structure panel

- **Cause**: Bloc initializes before VCD is received
- **Fix**: RohdModulePanel now has automatic retry logic with 500ms delay when VCD is loaded

### "WASM not loading"

- Ensure `pkg/` directory is in `media/flutter_web/`
- Check CSP headers in extension.ts include `wasm-unsafe-eval`

### "CanvasKit not loading"

- Ensure `useLocalCanvasKit: true` is in flutter_bootstrap.js
- Check `canvaskit/` directory exists in flutter_web

### "VCD not parsing"

- Check console for `[WebWellen]` and `[WebMain]` log messages
- Ensure WellenModuleStructureApi.init() completes before receiving VCD
