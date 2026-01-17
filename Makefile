ROOT := $(abspath $(CURDIR))
FLUTTER ?= flutter
NODE ?= node

PKG_NAME := $(shell command -v $(NODE) >/dev/null 2>&1 && $(NODE) -p "require('$(ROOT)/vscode-extension/package.json').name" || echo rohd-wave-viewer-vscode)
PKG_VERSION := $(shell command -v $(NODE) >/dev/null 2>&1 && $(NODE) -p "require('$(ROOT)/vscode-extension/package.json').version" || echo 0.0.1)
EXT_STAGE := $(ROOT)/build/extension/$(PKG_NAME)-$(PKG_VERSION)
WEB_BUILD := $(ROOT)/build/web
LINUX_BUNDLE := $(ROOT)/build/linux/x64/release/bundle
NATIVE_LIB := $(ROOT)/rust/wellen_bridge/target/release
DART_FRB := $(ROOT)/packages/dart_wellen/lib/src/rust/frb_generated.dart
DART_FRB_RUST := $(ROOT)/rust/wellen_bridge/src/frb_generated.rs
WASM_PKG := $(ROOT)/web/pkg
VSIX := $(ROOT)/build/rohd-wave-viewer.vsix

.PHONY: all extension web linux vsix wasm rust-native rust-wasm dart-wellen \
	pub-get test install-local install-remote install-vsix uninstall \
	clean full-clean clean-extension clean-web clean-linux clean-rust help

help:
	@echo "ROHD Wave Viewer - Build Targets"
	@echo ""
	@echo "Main targets:"
	@echo "  all              - Build VS Code extension (default)"
	@echo "  extension        - Build VS Code extension"
	@echo "  web              - Build Flutter web app"
	@echo "  linux            - Build Flutter Linux desktop app"
	@echo "  vsix             - Package extension as .vsix"
	@echo ""
	@echo "Install/Test targets:"
	@echo "  install-local    - Install extension for local testing (dev mode)"
	@echo "  install-remote   - Install extension in remote container (~/.vscode-server)"
	@echo "  install-vsix     - Install packaged .vsix file"
	@echo "  uninstall        - Remove installed development extension"
	@echo ""
	@echo "Rust/dependency targets:"
	@echo "  rust-wasm        - Build Rust WASM package (web/pkg)"
	@echo "  rust-native      - Build Rust native library (target/release)"
	@echo "  dart-wellen      - Generate Dart FFI bindings (FRB codegen)"
	@echo "  pub-get          - Download Dart/Flutter dependencies"
	@echo "  test             - Run Dart tests for dart_wellen package"
	@echo ""
	@echo "Clean targets:"
	@echo "  clean            - Clean build outputs (extension, web, linux)"
	@echo "  full-clean       - Clean all artifacts including Rust builds"
	@echo "  clean-extension  - Clean extension build"
	@echo "  clean-web        - Clean Flutter web build"
	@echo "  clean-linux      - Clean Flutter Linux build"
	@echo "  clean-rust       - Clean Rust artifacts (WASM + native)"
	@echo ""
	@echo "Prerequisites for builds:"
	@echo "  - Flutter SDK"
	@echo "  - Rust toolchain 1.92+ (run: tool/gh_actions/install_rust_1_92.sh)"
	@echo "  - WASM tools (run: tool/gh_actions/install_wasm_tools.sh)"
	@echo "  - Build tools (run: tool/gh_actions/install_build_tools.sh)"

all: extension

# Ensure Dart/Flutter dependencies are downloaded
pub-get:
	@echo "Downloading Dart/Flutter dependencies (root)..."
	@cd "$(ROOT)" && $(FLUTTER) pub get
	@echo "Downloading Dart/Flutter dependencies (dart_wellen package)..."
	@cd "$(ROOT)/packages/dart_wellen" && $(FLUTTER) pub get
	@echo "Downloading Dart/Flutter dependencies (module_structure_api package)..."
	@cd "$(ROOT)/packages/module_structure_api" && $(FLUTTER) pub get
	@echo "Downloading Dart/Flutter dependencies (module_structure_repository package)..."
	@cd "$(ROOT)/packages/module_structure_repository" && $(FLUTTER) pub get

# Generate Dart FFI bindings from Rust (requires libclang, flutter_rust_bridge_codegen)
dart-wellen: pub-get
	@if [ ! -f "$(DART_FRB)" ]; then \
		echo "Generating Flutter Rust Bridge bindings (Dart interface)..."; \
		bash "$(ROOT)/scripts/build_dart_wellen_bridge.sh"; \
	else \
		echo "✓ Dart bindings present: $(DART_FRB)"; \
	fi

# Build Rust WASM package (requires wasm-pack, wasm-bindgen-cli, binaryen)
rust-wasm: dart-wellen
	@if [ ! -d "$(WASM_PKG)" ]; then \
		echo "Building Rust WASM package..."; \
		$(MAKE) -C "$(ROOT)/rust/wellen_bridge" wasm; \
	else \
		echo "✓ WASM package present: $(WASM_PKG)"; \
	fi

# Build Rust native library for Linux/macOS/Windows (requires Rust toolchain)
rust-native: dart-wellen
	@echo "Building native Rust library..."
	@$(MAKE) -C "$(ROOT)/rust/wellen_bridge" native

# Build Flutter web app (depends on rust-wasm and pub-get)
web: pub-get rust-wasm
	@echo "Building Flutter web app..."
	@cd "$(ROOT)" && $(FLUTTER) build web --release --target lib/main_web.dart
	@echo "Copying WASM package into build/web..."
	@rm -rf "$(WEB_BUILD)/pkg"
	@cp -r "$(WASM_PKG)" "$(WEB_BUILD)/"
	@echo "Patching flutter_bootstrap.js for webview compatibility..."
	@python3 "$(ROOT)/scripts/fix_bootstrap.py"
	@echo "✓ Flutter web app built"

# Build VS Code extension (depends on web build)
extension: web
	@echo "Building VS Code extension..."
	@cd "$(ROOT)" && npm --prefix vscode-extension install
	@cd "$(ROOT)/vscode-extension" && npm run compile
	@echo "Staging extension assets..."
	@rm -rf "$(EXT_STAGE)"
	@mkdir -p "$(EXT_STAGE)"
	@cp -r "$(ROOT)/vscode-ext-package/extension/"* "$(EXT_STAGE)/"
	@mkdir -p "$(EXT_STAGE)/out"
	@if [ -d "$(ROOT)/vscode-extension/out" ]; then cp -r "$(ROOT)/vscode-extension/out/"* "$(EXT_STAGE)/out/"; fi
	@if [ -d "$(WEB_BUILD)" ]; then mkdir -p "$(EXT_STAGE)/media" && rm -rf "$(EXT_STAGE)/media/flutter_web" && cp -r "$(WEB_BUILD)" "$(EXT_STAGE)/media/flutter_web"; fi
	@echo "✓ Extension staged at $(EXT_STAGE)"

# Build .vsix package (depends on extension)
vsix: extension
	@echo "Packaging VSIX..."
	@cd "$(ROOT)" && bash scripts/build_vsix.tcsh
	@mkdir -p "$(ROOT)/build"
	@if [ -f "$(ROOT)/rohd-wave-viewer.vsix" ]; then mv -f "$(ROOT)/rohd-wave-viewer.vsix" "$(VSIX)"; fi
	@echo "✓ VSIX available at $(VSIX)"

# Install extension for local development/testing (symlink to build directory)
install-local: extension
	@echo "Installing extension for local testing..."
	@mkdir -p "$$HOME/.vscode/extensions"
	@rm -rf "$$HOME/.vscode/extensions/$(PKG_NAME)-$(PKG_VERSION)"
	@ln -sf "$(EXT_STAGE)" "$$HOME/.vscode/extensions/$(PKG_NAME)-$(PKG_VERSION)"
	@echo "✓ Extension symlinked to ~/.vscode/extensions/$(PKG_NAME)-$(PKG_VERSION)"
	@echo "  Reload VS Code window to activate the extension"

# Install extension for remote container testing (copy to .vscode-server)
install-remote: extension
	@echo "Installing extension for remote container..."
	@mkdir -p "$$HOME/.vscode-server/extensions"
	@rm -rf "$$HOME/.vscode-server/extensions/$(PKG_NAME)-$(PKG_VERSION)"
	@cp -r "$(EXT_STAGE)" "$$HOME/.vscode-server/extensions/$(PKG_NAME)-$(PKG_VERSION)"
	@echo "✓ Extension installed to ~/.vscode-server/extensions/$(PKG_NAME)-$(PKG_VERSION)"
	@echo "  Reload VS Code window to activate the extension"

# Install from packaged .vsix file using VS Code CLI
install-vsix: vsix
	@echo "Installing extension from VSIX..."
	@if command -v code >/dev/null 2>&1; then \
		code --install-extension "$(VSIX)" --force; \
		echo "✓ Extension installed via VS Code CLI"; \
	else \
		echo "ERROR: 'code' CLI not found. Install manually:"; \
		echo "  1. Open VS Code"; \
		echo "  2. Extensions view (Ctrl+Shift+X)"; \
		echo "  3. '...' menu → Install from VSIX"; \
		echo "  4. Select: $(VSIX)"; \
		exit 1; \
	fi

# Uninstall development extension
uninstall:
	@echo "Uninstalling development extension..."
	@rm -rf "$$HOME/.vscode/extensions/$(PKG_NAME)-$(PKG_VERSION)"
	@rm -rf "$$HOME/.vscode-server/extensions/$(PKG_NAME)-$(PKG_VERSION)"
	@if command -v code >/dev/null 2>&1; then \
		code --uninstall-extension "$(shell $(NODE) -p "require('$(ROOT)/vscode-extension/package.json').publisher").$(PKG_NAME)" 2>/dev/null || true; \
	fi
	@echo "✓ Extension uninstalled (reload VS Code to complete)"

# Build Flutter Linux desktop app (depends on rust-native and pub-get)
linux: pub-get rust-native
	@echo "Building Flutter Linux desktop app..."
	@mkdir -p "$(ROOT)/build/native_assets/linux"
	@cd "$(ROOT)" && $(FLUTTER) pub get
	@cd "$(ROOT)" && $(FLUTTER) build linux --release
	@echo "✓ Linux bundle located at $(LINUX_BUNDLE)"

# Run Dart tests with native library in LD_LIBRARY_PATH
test: rust-native pub-get
	@echo "Running Dart tests for dart_wellen package..."
	@cd "$(ROOT)" && LD_LIBRARY_PATH="$(NATIVE_LIB):$${LD_LIBRARY_PATH:-}" \
		dart test packages/dart_wellen/test/wellen_reader_simple_test.dart

# Clean build outputs (fast - preserves Rust artifacts)
clean: clean-extension clean-web clean-linux
	@echo "✓ Clean complete (Rust artifacts preserved)"

# Clean all artifacts including Rust builds (slower to rebuild)
full-clean: clean clean-rust
	@echo "✓ Full clean complete"

# Clean extension artifacts
clean-extension:
	@echo "Cleaning extension artifacts..."
	@rm -rf "$(EXT_STAGE)"
	@rm -f "$(VSIX)"
	@rm -rf "$(ROOT)/vscode-extension/out"
	@rm -rf "$(ROOT)/vscode-extension/node_modules"

# Clean Flutter web build
clean-web:
	@echo "Cleaning Flutter web build..."
	@rm -rf "$(WEB_BUILD)"

# Clean Flutter Linux build
clean-linux:
	@echo "Cleaning Flutter Linux build..."
	@rm -rf "$(ROOT)/build/linux"
	@rm -rf "$(ROOT)/build/native_assets"

# Clean Rust artifacts (WASM and native)
clean-rust:
	@echo "Cleaning Rust artifacts..."
	@$(MAKE) -C "$(ROOT)/rust/wellen_bridge" clean
	@echo "✓ Rust artifacts cleaned"
