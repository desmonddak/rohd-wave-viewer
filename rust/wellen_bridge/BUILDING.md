# Building wellen_bridge

This crate builds with a single pinned Rust toolchain (1.92.0) plus helper tools. Everything installs under ~/.cargo and ~/.rustup.

## Prerequisites

Install once per environment/machine:

```bash
# Rust 1.92.0 toolchain
tool/gh_actions/install_rust_1_92.sh

# WASM tools
tool/gh_actions/install_wasm_tools.sh

# Build tools + LLVM/libclang (for codegen)
tool/gh_actions/install_build_tools.sh
```

These installers auto-detect your OS and package manager, handle both CI (root) and local dev (regular user) contexts.

Verify installation:

```bash
rustc --version        # should be 1.92.0
wasm-pack --version
wasm-bindgen --version
flutter_rust_bridge_codegen --version   # should be 2.7.0
clang --version        # verifies LLVM/libclang
```

## Build WASM (for web)

From the repo root, this auto-detects and builds only what's missing:

```bash
./rust/wellen_bridge/build.sh
```

Or explicitly:

```bash
./rust/wellen_bridge/build_wasm.sh
```

Output lands in `web/pkg/` (wellen_bridge.js, wellen_bridge_bg.wasm, etc.).

## Build native (for desktop)

From the repo root:

```bash
./rust/wellen_bridge/build_native.sh
```

Output lands in `rust/wellen_bridge/target/release/libwellen_bridge.so` (or .dylib on macOS, .dll on Windows).

## Generate Dart bindings (required for both WASM and native)

The Dart/Rust bridge (FFI) bindings are generated from Rust annotations:

```bash
scripts/build_dart_wellen_bridge.sh
```

This:

- Detects libclang via ldconfig or filesystem search
- Runs flutter_rust_bridge_codegen to generate Dart interfaces
- Creates `packages/dart_wellen/lib/src/rust/frb_generated.dart`
- Creates `rust/wellen_bridge/src/frb_generated.rs`

The build_wasm.sh and build_native.sh scripts automatically call this if needed.

## Integrated build flows

### Full WASM (web)

```bash
# One-time setup
tool/gh_actions/install_rust_1_92.sh
tool/gh_actions/install_wasm_tools.sh
tool/gh_actions/install_build_tools.sh

# Build (auto-generates Dart bindings, builds WASM)
rust/wellen_bridge/build.sh
```

### Full native (desktop)

```bash
# One-time setup
tool/gh_actions/install_rust_1_92.sh
tool/gh_actions/install_build_tools.sh

# Build Dart bindings
scripts/build_dart_wellen_bridge.sh

# Build native library
rust/wellen_bridge/build_native.sh
```

### From Flutter app level

```bash
# Builds everything Flutter needs
make linux                    # includes native lib + Dart bindings
make extension                # includes WASM + Dart bindings
```

## Cleaning

```bash
# Clean WASM artifacts only
./rust/wellen_bridge/clean_wasm.sh

# Clean native artifacts only
./rust/wellen_bridge/clean_native.sh

# Clean everything (native + WASM + generated FRB files)
./rust/wellen_bridge/clean.sh
```

Manual cleanup:

```bash
cd rust/wellen_bridge
cargo clean
rm -rf target/
rm -rf ../../web/pkg
rm -f src/frb_generated.rs
rm -f ../../packages/dart_wellen/lib/src/rust/frb_generated.dart
```

## Troubleshooting

**libclang not found during codegen:**

```bash
# Set LIBCLANG_PATH if auto-detection fails
export LIBCLANG_PATH=/usr/lib/llvm-14/lib
scripts/build_dart_wellen_bridge.sh
```

**Rust version mismatch:**

```bash
# Ensure pinned 1.92.0 is active
source scripts/setup_rust_env.sh
rustc --version
```

**Missing WASM target:**

```bash
rustup target add wasm32-unknown-unknown --toolchain 1.92.0
```

**Stale generated files:**

```bash
# Clean and rebuild
rust/wellen_bridge/clean.sh
rust/wellen_bridge/build.sh
```
