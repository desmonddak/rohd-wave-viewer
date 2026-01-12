# Build Scripts Organization

This repository organizes build scripts into three areas for clarity and separation of concerns:

## 1. Tool Environment Setup (`tool/gh_actions/`)

Single comprehensive installer script for all toolchain dependencies:

- **`install_rust_1_92.sh`**: Install Rust 1.92.0 toolchain (per-user, ~/.cargo, ~/.rustup)
- **`install_wasm_tools.sh`**: Install wasm-pack, wasm-bindgen-cli, and binaryen (wasm-opt) for WASM builds
- **`install_build_tools.sh`**: Unified installer for:
  - C/C++ compiler (gcc/clang)
  - CMake & Ninja build tools
  - pkg-config
  - LLVM/libclang (for flutter_rust_bridge codegen)
  - GTK3 & graphics libraries (for Flutter Linux)
  - Works across Linux (apt/dnf/yum/pacman/zypper) and macOS (brew)
- **`install_dependencies.sh`**: Install Flutter/Dart dependencies (flutter pub get)
- **`build_wellen_bridge_ci.sh`**: CI-specific script for building the Rust bridge
- **`analyze_source.sh`**: Run static analysis on Dart code
- **`verify_formatting.sh`**: Check Dart code formatting
- **`generate_documentation.sh`**: Generate project documentation
- **`run_tests.sh`**: Run test suite

Run these once per environment/machine. Each installer:

- Auto-detects OS and package manager
- Handles both CI (root) and local dev (regular user) environments
- Skips if tools already present

## 2. Rust Library Building (`rust/wellen_bridge/`)

Self-contained Rust library build scripts:

### Build scripts

- **`build_wasm.sh`**: Build WASM package for web (outputs to `web/pkg/`)
- **`build_native.sh`**: Build native shared library for desktop (outputs to `target/release/`)
- **`build.sh`**: Orchestrator that runs Dart codegen + WASM build

### Rust Cleanup scripts

- **`clean_wasm.sh`**: Remove WASM artifacts
- **`clean_native.sh`**: Remove native build artifacts
- **`clean.sh`**: Full cleanup (native + WASM + generated FRB files)

**Assumptions**: Rust 1.92, wasm-pack, libclang pre-installed via tool/gh_actions/ scripts.

## 3. Application Building (`scripts/`)

High-level app build and support scripts:

### Dart interface generation

- **`build_dart_wellen_bridge.sh`**: Generate Flutter/Rust bridge Dart bindings
  - Runs flutter_rust_bridge_codegen with libclang detection
  - Handles absolute path rewriting for Rust config
  - Ready for both Linux and web builds

### Flutter app building

- **`build_linux.sh`**: Build Linux desktop app
  - Auto-builds native library if missing
  - Creates Flutter build directory structure
  - Outputs to `build/linux/x64/release/bundle/`

- **`build_extension.sh`**: Build VS Code extension
  - Auto-builds WASM if web/pkg missing
  - Auto-generates Dart interface if needed
  - Builds Flutter web app
  - Compiles TypeScript extension

### Cleanup scripts

- **`clean_linux.sh`**: Remove Linux build artifacts
- **`clean_extension.sh`**: Remove extension build artifacts (includes Rust bridge cleanup)

### Support scripts

- **`setup_rust_env.sh`**: Source this to load Rust toolchain environment
  - Sets CARGO_HOME, RUSTUP_HOME (per-user)
  - Ensures pinned Rust 1.92 is available
  - Exports RUSTUP_BIN for use in other scripts
  - Exports proxy environment variables for tool downloads

- **`fix_bootstrap.py`**: Patch flutter_bootstrap.js for VS Code webview compatibility

- **`run_dart_tests.sh`**: Run Dart tests for dart_wellen package

- **`run_wasm_test_nvm.sh`**: Run WASM tests using Node.js via nvm

- **`build_vsix.tcsh`**: Build VS Code extension package (.vsix file)

- **`configure_vscode_association.sh`**: Configure VS Code file associations

## Test Fixtures (`test/fixtures/`)

Single unified test fixture covering all waveform formats:

- **`xz_transitions.vcd`**: X/Z transition patterns (VCD format, 574 bytes)
- **`xz_transitions.fst`**: Same signals converted to FST (561 bytes)
- **`xz_transitions.ghw`**: Same signals in GHDL format (793 bytes, generated via GHDL)

Tests validate that all three formats correctly parse:

- Signal hierarchy (clk, data8 signals in 'test' module)
- Waveform data with X/Z (unknown/high-impedance) values
- Consistent representation across formats

## Quick Build Flows

### Web (WASM)

```bash
# One-time setup
tool/gh_actions/install_rust_1_92.sh
tool/gh_actions/install_wasm_tools.sh  # Installs wasm-pack, wasm-bindgen-cli, and binaryen
tool/gh_actions/install_build_tools.sh

# Build
rust/wellen_bridge/build.sh
scripts/build_extension.sh
```

**Note**: WASM builds require `binaryen` (wasm-opt) for optimization. The `install_wasm_tools.sh` script will install it via your system package manager. If you're behind a corporate proxy, ensure proxy environment variables (`http_proxy`, `https_proxy`, etc.) are set before running the build scripts.

### Linux Desktop

```bash
# One-time setup
tool/gh_actions/install_rust_1_92.sh
tool/gh_actions/install_build_tools.sh

# Build (auto-detects and builds dependencies as needed)
scripts/build_linux.sh
```

### Run tests

```bash
cd packages/dart_wellen
flutter test test/wellen_reader_simple_test.dart
```

## Architecture Principles

1. **Minimal environment setup** - Single comprehensive installer per tool type
2. **Auto-detection & lazy building** - App build scripts only rebuild what's missing
3. **Clear separation of concerns**:
   - `tool/gh_actions/` = environment only (dependencies)
   - `rust/wellen_bridge/` = Rust library (self-contained)
   - `scripts/` = app-level building (Dart/Flutter)

This ensures:

- CI containers run environment setup once, then build repeatedly
- Local developers can rebuild individual components without full setup
- Build scripts are simple and focused, not trying to do too much
- Easy to add new platforms or build targets
