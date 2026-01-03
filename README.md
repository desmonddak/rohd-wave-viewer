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

## Get involved

- [Join the Discord chat](https://discord.gg/jubxF84yGw)
- [GitHub Issues](https://github.com/intel/rohd-wave-viewer/issues)

## Contributing

ROHD Wave Viewer is under active development. If you're interested in contributing, have feedback or question, or found a bug, please see [CONTRIBUTING.md](https://github.com/intel/rohd-wave-viewer/blob/main/CONTRIBUTING.md).

----------------

Copyright (C) 2024-2025 Intel Corporation  
SPDX-License-Identifier: BSD-3-Clause
