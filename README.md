# ROHD Wave Viewer

ROHD Wave Viewer is a waveform viewer tool built using the [Flutter](https://flutter.dev/) framework as part of the [ROHD](https://intel.github.io/rohd-website) ecosystem. It can be used in a browser, integrated as a Flutter widget, used as part of a debug stack, or run as a native desktop application. It can display waves passed via an API or read from a standard waveform file (e.g. VCD, FST).

**Status:** This project is under active development. Contributions and bug reports are welcome.

## Usage

Quick instructions to run the ROHD Wave Viewer and common controls.

### Provide a waveform file

Primary (recommended): pass the VCD/FST file as the first positional command-line argument when launching the application. This is the simplest way to open a specific file and is used by the native binary and by `flutter run` (use `--` to forward args to the app).

Example (native binary):

```bash
./build/linux/x64/release/bundle/rohd_wave_viewer /path/to/your/file.vcd
```

Example (flutter run):

```bash
flutter run -d linux -- /path/to/your/file.vcd
```

Secondary (convenient for repeated dev runs): set the `ROHD_WAVE_VCD` environment variable. This is useful when using `flutter run` repeatedly from the same shell so you don't need to pass `--` each time.

Example (Linux/macOS):

```bash
export ROHD_WAVE_VCD=/path/to/your/file.vcd
flutter run -d linux
```

On Windows (PowerShell):

```powershell
$env:ROHD_WAVE_VCD = 'C:\path\to\your\file.vcd'
flutter run -d windows
```

Precedence: if both a positional argument and `ROHD_WAVE_VCD` are provided, the positional argument takes precedence.

### Running the app

- Run via Flutter (useful for development):

```bash
flutter run -d linux  # or -d windows, -d macos, or -d web-server
```

- Build and run a native desktop binary (release):

```bash
flutter build linux   # or macos/windows depending on your platform
./build/linux/x64/release/bundle/rohd_wave_viewer  # example path
```

### Controls

- **Place / move marker (cursor):** Click a waveform row (without holding Control) to place the marker at that time. The marker is stored as a waveform time (picoseconds) and will stay anchored to waveform transitions across zoom/pan operations.
- **Pan (mouse):** Hold the Control key and drag with the left mouse button to pan horizontally and vertically. Regular drag without Control will not pan (so you don't accidentally move markers).
- **Zoom (mouse wheel):** Hold Control and scroll the mouse wheel to zoom. Zoom is focal: the pixel under the cursor remains fixed while zooming.
- **Pan with keyboard:** Use the arrow keys to scroll vertically/horizontally. `Up`/`Down` scroll by one signal-row (see `signalRowHeight`), `Left`/`Right` scroll horizontally.
- **Fit View:** Press `F` to reset zoom to 1.0 and jump to the start (time 0).

## Development & Testing

The ROHD Wave Viewer can be run and tested in three different configurations:

### 1. VS Code Extension Mode

Run as a VS Code extension for viewing VCD/FST files:

**Using VS Code Debug Panel (F5):**

- `Extension (workspace)` - Test extension from workspace
- `Extension (workspace) + Debug` - With Node.js debugger (port 9329)

**Installing the Extension:**

For local testing, remote container testing, or distributing as a VSIX package:

```bash
# Local development (fast iteration with symlinks)
make install-local

# Remote container testing
make install-remote

# Create VSIX package for distribution
make vsix

# Install from VSIX
make install-vsix
```

See **[docs/INSTALL_EXTENSION.md](docs/INSTALL_EXTENSION.md)** for complete installation instructions and troubleshooting.

**Using VS Code Tasks (Ctrl+Shift+B):**

- `Build Extension` - Compile TypeScript extension code

**Key Development Steps:**

1. Make changes to extension code in `vscode-extension/`
2. Press F5 to launch Extension Development Host
3. Open a `.vcd` or `.fst` file to trigger the wave viewer
4. Check Debug Console for extension logs

**Using Terminal:**

```bash
cd vscode-extension
npm run compile
# Then press F5 in VS Code to test
```

### 2. Web Mode

Run the Flutter wave viewer as a standalone web application:

**Using VS Code Debug Panel (F5):**

- `Web (Simple Browser)` - Run on port 9299 in VS Code
- `Web (Chrome)` - Open in Chrome browser

**Using VS Code Tasks:**

- `Flutter Web (port 9299)` - Run web server with main_web.dart

**Using Terminal:**

```bash
flutter run -d web-server --web-port=9299 --web-hostname=localhost lib/main_web.dart
```

Access at: **<http://localhost:9299>**

### 3. Linux Native Mode

Run the Flutter wave viewer as a native Linux desktop application:

**Using VS Code Debug Panel (F5):**

- `Linux Native` - Standard debug mode using main.dart
- `Linux Native (profile)` - Profile mode

**Using VS Code Tasks:**

- `Flutter Linux` - Run native application

**Using Terminal:**

```bash
# With VCD file argument
flutter run -d linux -- /path/to/file.vcd

# Using environment variable
export ROHD_WAVE_VCD=/path/to/file.vcd
flutter run -d linux

# Build release binary
flutter build linux
./build/linux/x64/release/bundle/rohd_wave_viewer /path/to/file.vcd
```

### Testing

Run unit and widget tests:

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/path/to/test_file.dart

# Run tests with coverage
flutter test --coverage
```

## Get involved

- [Join the Discord chat](https://discord.gg/jubxF84yGw)
- [GitHub Issues](https://github.com/intel/rohd-wave-viewer/issues)

## Contributing

ROHD Wave Viewer is under active development. If you're interested in contributing, have feedback or question, or found a bug, please see [CONTRIBUTING.md](https://github.com/intel/rohd-wave-viewer/blob/main/CONTRIBUTING.md).

----------------

Copyright (C) 2024-2025 Intel Corporation  
SPDX-License-Identifier: BSD-3-Clause
