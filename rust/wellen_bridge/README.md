# Wellen Bridge

This Rust crate provides Flutter bindings to the [wellen](https://crates.io/crates/wellen) waveform parsing library using [flutter_rust_bridge](https://github.com/aspect-ratio-studios/flutter_rust_bridge).

## Supported Formats

- **VCD** - Value Change Dump
- **FST** - Fast Signal Trace (GTKWave)
- **GHW** - GHDL Waveform

## Prerequisites

1. **Rust toolchain** (1.70+)

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

2. **flutter_rust_bridge_codegen**

   ```bash
   cargo install flutter_rust_bridge_codegen
   ```

3. **LLVM** (for code generation)
   - Ubuntu: `sudo apt install llvm-dev libclang-dev clang`
   - macOS: `brew install llvm`
   - Windows: Download from <https://releases.llvm.org/>

## Building

### Generate Dart bindings

From the project root:

```bash
flutter_rust_bridge_codegen generate
```

This will generate Dart code in `lib/src/generated/`.

### Build the Rust library

For Linux:

```bash
cd rust/wellen_bridge
cargo build --release
```

For macOS:

```bash
cd rust/wellen_bridge
cargo build --release
```

For Android (requires NDK):

```bash
cargo install cargo-ndk
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android
cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 -t x86 -o ../android/app/src/main/jniLibs build --release
```

For iOS:

```bash
rustup target add aarch64-apple-ios x86_64-apple-ios
cargo build --release --target aarch64-apple-ios
cargo build --release --target x86_64-apple-ios
```

## API

### Load a waveform file

```dart
import 'package:rohd_wave_viewer/wellen_module_structure_api.dart';

final api = WellenModuleStructureApi();
await api.loadFile('path/to/waveform.vcd');
```

### Get module structure

```dart
final structure = await api.getModuleStructure();
for (final module in structure.modules) {
  print('Module: ${module.name}');
  for (final signal in module.signals) {
    print('  Signal: ${signal.name} (${signal.type})');
  }
}
```

### Get waveform data

```dart
final waveformData = await api.getWaveformData(
  signalIds: ['top.clk', 'top.counter.value'],
  startTime: 0,
  endTime: 1000,
);

for (final signal in waveformData) {
  print('Signal: ${signal.signalId}');
  for (final point in signal.data) {
    print('  ${point.time}: ${point.value}');
  }
}
```

### Stream waveform data incrementally

```dart
await for (final data in api.streamWaveformData(signalIds: ['top.clk'])) {
  // Process data as it arrives
  updateUI(data);
}
```

## Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                     Flutter/Dart                            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  WellenModuleStructureApi                            │   │
│  │  - loadFile(path)                                    │   │
│  │  - getModuleStructure()                              │   │
│  │  - getWaveformData(signalIds, timeRange)             │   │
│  └──────────────────────────────────────────────────────┘   │
│                           │                                 │
│                           │ flutter_rust_bridge             │
│                           ▼                                 │
├─────────────────────────────────────────────────────────────┤
│                     Rust (FFI)                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  wellen_bridge                                       │   │
│  │  - load_waveform(file_path)                          │   │
│  │  - get_waveform_structure()                          │   │
│  │  - get_waveform_data(signal_ids, start, end)         │   │
│  └──────────────────────────────────────────────────────┘   │
│                           │                                 │
│                           ▼                                 │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  wellen library                                      │   │
│  │  - VCD/FST/GHW parsing                               │   │
│  │  - Signal hierarchy                                  │   │
│  │  - Time-indexed value lookup                         │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Performance Notes

- **Header parsing** is fast and loads the signal hierarchy
- **Body parsing** loads the time table (can be slow for large files)
- **Signal loading** is lazy - signals are loaded on demand
- For very large files, consider using `streamWaveformData` for incremental loading
