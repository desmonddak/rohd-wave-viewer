# Development Environment Inventory

This file captures observed tools used for building the project (web and native), where they were found on disk in the current environment, the observed versions, and my best guess about how they were installed. Use the verification commands shown to reproduce these observations.

---

## Summary (observed on 2026-01-04)

- Linux host with Flutter SDK installed at `/opt/flutter`.
- Rust installed via `rustup` into `~/.cargo` (stable toolchain active).
- Node & npm available system-wide at `/usr/bin` (Node v12.22.9, npm 8.5.1).
- `wasm-pack` installed under `~/.cargo/bin`.
- `wasm-bindgen` / `wasm-opt` not found on PATH.

---

## Tools

- rustup
  - Path: `/home/ganewto/.cargo/bin/rustup`
  - Observed: `rustup 1.28.2 (e4f3ad6f8 2025-04-28)`
  - Likely installed via: `curl https://sh.rustup.rs | sh` (standard rustup installer).
  - Verify: `rustup --version` and `rustup show`

- cargo
  - Path: `/home/ganewto/.cargo/bin/cargo`
  - Observed: `cargo 1.92.0 (344c4567c 2025-10-21)`
  - Comes from rustup toolchain (installed alongside `rustc` by rustup).
  - Verify: `cargo --version`

- rustc
  - Path: `/home/ganewto/.cargo/bin/rustc`
  - Observed: `rustc 1.92.0 (ded5c06cf 2025-12-08)`
  - Comes from rustup toolchain.
  - Verify: `rustc --version`

- flutter
  - Path: `/opt/flutter/bin/flutter`
  - Observed: `Flutter 3.29.1 • channel stable` (bundled Dart 3.7.0)
  - Likely installed by downloading official Flutter SDK and extracting to `/opt/flutter` (manual install), or via system package if your environment provides it. `/opt` typically indicates a manual extraction or system-wide install by an administrator.
  - Verify: `/opt/flutter/bin/flutter --version`

- dart
  - Path: `/opt/flutter/bin/dart`
  - Observed: `Dart SDK version: 3.7.0` (bundled with Flutter)
  - Verify: `/opt/flutter/bin/dart --version`

- node
  - Path: `/usr/bin/node`
  - Observed: `v12.22.9`
  - Likely installed via OS package manager (apt) or preinstalled system Node package. On Debian/Ubuntu, `apt install nodejs` typically places binary in `/usr/bin`.
  - Please note: Node 12 is relatively old; many modern JS tools prefer Node 16+ or 18+.
  - Verify: `node --version`

- npm
  - Path: `/usr/bin/npm`
  - Observed: `8.5.1`
  - Likely installed together with `node` (apt, Node installer, or NodeSource). Verify with `npm --version`.

- yarn
  - Observed: not found on PATH (Command not found).
  - If needed, typical install is `npm install -g yarn` or package manager (apt/yarnpkg repo).
  - Verify: `which yarn`

- pnpm
  - Observed: not found on PATH.
  - Typical install: `npm install -g pnpm` or `corepack enable` for Node 16+.
  - Verify: `which pnpm`

- wasm-pack
  - Path: `/home/ganewto/.cargo/bin/wasm-pack`
  - Observed: `wasm-pack 0.13.1`
  - Likely installed via `cargo install wasm-pack` or from prebuilt installer; commonly installed with `cargo install wasm-pack`.
  - Verify: `wasm-pack --version`

- wasm-bindgen / wasm-bindgen-cli
  - Observed: not found on PATH.
  - Often installed via `cargo install -f wasm-bindgen-cli` or provided by `wasm-pack` invocation. If build scripts call `wasm-bindgen` directly, install with `cargo install wasm-bindgen-cli`.
  - Verify: `which wasm-bindgen` and `wasm-bindgen --version`

- wasm-opt (Binaryen)
  - Observed: not found on PATH.
  - Commonly installed via OS package manager (`apt install binaryen`) or downloaded from Binaryen releases.
  - Verify: `which wasm-opt`

- git
  - Path: `/usr/bin/git`
  - Likely installed via `apt install git`.
  - Verify: `git --version`

---

## Project manifests and important dependencies

- `pubspec.yaml` (project root)
  - Uses `flutter_rust_bridge: 2.6.0` and `ffi`.
  - Flutter build and pub dependencies resolved in `pubspec.lock`.
  - Verify: `cat pubspec.yaml` and `cat pubspec.lock`.

- `rust/wellen_bridge/Cargo.toml`
  - Key crates:
    - `flutter_rust_bridge = "=2.6.0"`
    - `wellen = { version = "0.20.1", features = ["serde1"] }`
    - build-dependency: `flutter_rust_bridge_codegen = "=2.7.0"`
  - `flutter_rust_bridge_codegen` must be available (usually via `cargo install flutter_rust_bridge_codegen`).

- `vscode-extension/package.json` and `vscode-ext-package/extension/package.json`
  - TypeScript-based extension with `typescript` and `@types/*` in devDependencies.
  - The project uses the Flutter web build artifacts inside the VS Code extension WebView.

- `web/pkg/package.json` and `web/pkg/wellen_bridge.js`
  - These are generated wasm package artifacts (WASM + wasm-bindgen glue) that are embedded into Flutter web build output.

---

## Notes about likely installation sources

- Anything inside `/home/<user>/.cargo/bin` (cargo, rustup-managed tools, wasm-pack when installed via `cargo`) was most likely installed via `rustup` + `cargo install ...`.
- `/opt/flutter` typically indicates a manual Flutter SDK download and extraction (or a system-wide install performed by an admin). The Flutter SDK bundles Dart.
- `/usr/bin/node` and `/usr/bin/npm` usually come from the OS package manager (`apt` on Debian/Ubuntu) or NodeSource apt repos. To check exact package provenance on Debian/Ubuntu use `dpkg -S /usr/bin/node`.
- `wasm-pack` was present in `~/.cargo/bin` and was likely installed with `cargo install wasm-pack`.
- Missing items that you may need to install explicitly:
  - `wasm-bindgen-cli` (install with `cargo install -f wasm-bindgen-cli`)
  - `wasm-opt` (install with `sudo apt install binaryen` or download Binaryen)
  - `flutter_rust_bridge_codegen` (install with `cargo install flutter_rust_bridge_codegen --version 2.7.0`)

---

## Quick verification commands

```bash
# Rust / Cargo / rustup
rustup --version
rustup show
cargo --version
rustc --version

# wasm tools
wasm-pack --version
which wasm-bindgen || echo "wasm-bindgen not found"
which wasm-opt || echo "wasm-opt not found"

# Node / npm
node --version
npm --version
which yarn || echo "yarn not installed"
which pnpm || echo "pnpm not installed"

# Flutter / Dart
/opt/flutter/bin/flutter --version
/opt/flutter/bin/dart --version

# Project checks
cat pubspec.yaml | sed -n '1,120p'
cat rust/wellen_bridge/Cargo.toml | sed -n '1,120p'
ls -l web/pkg
```

---

## Suggested installs (if you need to make a reproducible environment)

- Install rustup (if not present):
  - `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
- Install required cargo tools:
  - `cargo install flutter_rust_bridge_codegen --version 2.7.0`
  - `cargo install wasm-pack`
  - `cargo install -f wasm-bindgen-cli` (if scripts call `wasm-bindgen` directly)
- Install Binaryen (provides `wasm-opt`):
  - Ubuntu/Debian: `sudo apt install binaryen`

### LLVM / Clang / Binaryen (needed for ffigen / wasm-opt)

ffigen (used by `flutter_rust_bridge_codegen`) requires LLVM's libclang to parse C headers, and `wasm-opt` (from Binaryen) is used by `wasm-pack` for wasm optimizations. If these are missing you'll see errors like "ffigen could not find LLVM" or failed Binaryen downloads.

Install on Debian/Ubuntu:

```bash
sudo apt update
sudo apt install -y clang libclang-dev llvm-dev binaryen
```

On Fedora/RHEL:

```bash
sudo dnf install clang llvm-devel libclang-devel binaryen
```

On macOS (Homebrew):

```bash
brew install llvm binaryen
# Then export LIBCLANG_PATH to the lib dir, for example:
export LIBCLANG_PATH="$(brew --prefix llvm)/lib"
```

If LLVM or Binaryen are installed in a custom location, set `LIBCLANG_PATH` to the directory containing `libclang.so` (or `libclang.dylib` on macOS) before running the build script.

- Node (recommended modern LTS):
  - Use `nvm` to install Node 18+: `curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash` then `nvm install --lts`.
  - Alternatively on Debian/Ubuntu you can install via apt:

```bash
sudo apt update
sudo apt install -y nodejs npm
```

Note: system package managers may ship older Node versions. `nvm` is recommended for installing a modern LTS (Node 18+).

- Flutter SDK:
  - Download stable from flutter.dev and extract to `/opt/flutter` or a user-writable location, then add to PATH.

---

## Rust permissions and per-user installs

- Problem: If `~/.cargo` or `~/.rustup` are owned by `root` (often from running installers with `sudo`), `cargo install` will fail or install into `/root/.cargo`, leading to permission problems.
- Quick fix: change ownership to your user:

```bash
sudo chown -R $(id -u):$(id -g) $HOME/.cargo $HOME/.rustup
```

- Alternative: use per-shell overrides to keep cargo/rustup in a user-writable location without changing global defaults:

```bash
export CARGO_HOME="$HOME/.cargo"
export RUSTUP_HOME="$HOME/.rustup"
export PATH="$CARGO_HOME/bin:$PATH"
```

- If you see build scripts that attempted to install tools globally (using `sudo`), prefer re-running them as your user after fixing ownership or updating the environment above.

---

If you want, I can:

- Produce a `setup.sh` that checks/installs the missing CLI pieces non-destructively (only prompts or prints commands to run), or
- Extract exact build commands from the repository build scripts (e.g., `build_extension.sh` / `build.sh`) so you can reproduce the web and native builds step-by-step.
