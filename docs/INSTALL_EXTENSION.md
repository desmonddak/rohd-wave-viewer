# Installing ROHD Wave Viewer VS Code Extension

This document describes different methods for installing and testing the ROHD Wave Viewer VS Code extension.

## Table of Contents

- [For Developers (Local Testing)](#for-developers-local-testing)
- [For Remote Container Development](#for-remote-container-development)
- [For End Users (VSIX Package)](#for-end-users-vsix-package)
- [Troubleshooting](#troubleshooting)

---

## For Developers (Local Testing)

When actively developing the extension, use a symlink installation for fast iteration without rebuilding/reinstalling:

### Quick Start

```bash
# Build and install for local testing
make install-local

# Reload VS Code window (Ctrl+Shift+P → "Developer: Reload Window")
```

### What it does

- Creates a **symlink** from `~/.vscode/extensions/` to your build directory
- Changes to the extension are reflected immediately after rebuilding
- No need to reinstall after code changes

### Workflow

```bash
# 1. Make changes to extension TypeScript code
vim vscode-extension/src/extension.ts

# 2. Rebuild extension
make extension

# 3. Reload VS Code window
# Press Ctrl+Shift+P → "Developer: Reload Window"
```

### Uninstall

```bash
make uninstall
```

---

## For Remote Container Development

When developing inside a remote container (e.g., dev containers, SSH remote), VS Code uses `~/.vscode-server/extensions/` instead of `~/.vscode/extensions/`.

### Installation

```bash
# Build and install for remote container
make install-remote

# Reload VS Code window
```

### What happens

- **Copies** the extension to `~/.vscode-server/extensions/`
- Required because symlinks may not work reliably in remote environments
- Must reinstall after each change to extension code

### Extension Build Workflow

```bash
# 1. Make changes and rebuild
make extension

# 2. Reinstall to remote
make install-remote

# 3. Reload VS Code window
```

### How to check if you're in a remote environment

```bash
# If this directory exists, you're in a remote environment
ls ~/.vscode-server/extensions/
```

---

## For End Users (VSIX Package)

For distribution to users who want to install the extension without building from source.

### Creating the VSIX Package

```bash
# Build the .vsix package file
make vsix

# Output: build/rohd-wave-viewer.vsix
```

### Installing from VSIX (Method 1: CLI)

If you have the VS Code `code` command available:

```bash
# Install the packaged extension
make install-vsix

# Or manually:
code --install-extension build/rohd-wave-viewer.vsix
```

### Installing from VSIX (Method 2: GUI)

1. Open VS Code
2. Open Extensions view (`Ctrl+Shift+X` or `Cmd+Shift+X`)
3. Click the `...` menu at the top right
4. Select **"Install from VSIX..."**
5. Navigate to `build/rohd-wave-viewer.vsix`
6. Click **Install**
7. Reload VS Code when prompted

### Distributing the VSIX

Share the `build/rohd-wave-viewer.vsix` file with users via:

- GitHub Releases
- Internal file sharing
- VS Code Marketplace (requires publisher account)

---

## Extension Location Reference

Different installation methods place the extension in different locations:

| Method                | Location                        | Type    | Use Case          |
| --------------------- | ------------------------------- | ------- | ----------------- |
| `make install-local`  | `~/.vscode/extensions/`         | Symlink | Local development |
| `make install-remote` | `~/.vscode-server/extensions/`  | Copy    | Remote container  |
| `make install-vsix`   | `~/.vscode/extensions/`         | Copy    | End user install  |
| VS Code GUI (VSIX)    | `~/.vscode/extensions/`         | Copy    | End user install  |

---

## Troubleshooting

### Extension not appearing after installation

**Solution**: Reload the VS Code window

- Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
- Type "Developer: Reload Window" and press Enter

### Extension shows old version

**Solution**: Uninstall and reinstall

```bash
make uninstall
make install-local  # or install-remote
```

### "code command not found" when running install-vsix

**Solution**: Install VS Code CLI

```bash
# Open VS Code → Ctrl+Shift+P → "Shell Command: Install 'code' command in PATH"
```

Or install manually using the GUI method described above.

### Extension works locally but not in remote container

**Solution**: Use `make install-remote` instead of `make install-local`

Remote environments require installation to `~/.vscode-server/extensions/`, not `~/.vscode/extensions/`.

### Changes not reflected after rebuilding

**For symlink install (`install-local`)**:

- Just rebuild: `make extension`
- Reload window: `Ctrl+Shift+P → Developer: Reload Window`

**For copy install (`install-remote` or `install-vsix`)**:

- Must reinstall: `make install-remote` (or `install-vsix`)
- Then reload window

### Extension conflicts with published version

If there's both a development and published version:

```bash
# List all installed extensions
code --list-extensions

# Uninstall the published version
code --uninstall-extension local.rohd-wave-viewer-vscode

# Or uninstall all development versions
make uninstall
```

---

## Development Best Practices

### Recommended workflow for active development

```bash
# 1. Initial setup
make install-local

# 2. Development cycle (repeat)
#    - Edit code
#    - Build: make extension
#    - Test: Reload VS Code window

# 3. Final testing before release
make clean
make vsix
make install-vsix
# Test as end user would
```

### Testing in both environments

```bash
# Test locally
make install-local
# ... test ...

# Test in remote container
make install-remote
# ... test ...

# Test as VSIX package
make install-vsix
# ... test ...
```

### Cleaning up

```bash
# Remove all development installs
make uninstall

# Clean all build artifacts
make clean
```

---

## Summary Commands

```bash
# Development (fast iteration)
make install-local

# Remote container testing
make install-remote

# Create distributable package
make vsix

# Install from package
make install-vsix

# Remove extension
make uninstall

# View all targets
make help
```

For questions or issues, see the main [README.md](../README.md) or open an issue on GitHub.
