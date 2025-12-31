# rohd_wellen

Dart bindings to the [wellen](https://github.com/ekiwi/wellen) Rust library for reading and writing waveform files.

This package provides:

- **Reading** VCD, FST, and GHW waveform files
- **Writing** VCD (and FST in future) waveform files  
- A **WellenWaveDumper** class compatible with ROHD's simulation pattern

## Features

| Format | Reading | Writing          |
|--------|---------|------------------|
| VCD    | ✅      | ✅               |
| FST    | ✅      | 🚧 (planned)     |
| GHW    | ✅      | ❌ (read-only)   |

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  rohd_wellen:
    path: packages/rohd_wellen
```

### Rust Toolchain

This package uses Rust via `flutter_rust_bridge`. You need:

1. [Rust toolchain](https://rustup.rs/)
2. Run code generation:

   ```bash
   cd packages/rohd_wellen
   flutter_rust_bridge_codegen generate
   ```

## Usage

### Reading Waveform Files

```dart
import 'package:rohd_wellen/rohd_wellen.dart';

Future<void> main() async {
  final reader = WellenReader();
  
  // Load a waveform file
  await reader.loadFile('simulation.vcd');
  
  // Get the signal hierarchy
  final structure = await reader.getStructure();
  print('Format: ${structure.metadata.format}');
  print('Timescale: ${structure.metadata.timescale}');
  
  // List all signals
  for (final signalId in structure.allSignalIds) {
    print('Signal: $signalId');
  }
  
  // Get waveform data for specific signals
  final data = await reader.getSignalData(['top.clk', 'top.reset']);
  for (final signal in data) {
    print('${signal.signalId}: ${signal.data.length} transitions');
  }
  
  // Stream data for large waveforms
  await for (final chunk in reader.streamSignalData(
    structure.allSignalIds,
    chunkSize: 10,
  )) {
    print('Loaded ${chunk.length} signals');
  }
  
  await reader.close();
}
```

### Writing Waveform Files

```dart
import 'package:rohd_wellen/rohd_wellen.dart';

Future<void> main() async {
  final writer = WellenWriter();
  
  await writer.open(
    'output.vcd',
    format: WaveFormat.vcd,
    timescale: '1ns',
  );
  
  // Register signals
  writer.registerSignal(SignalInfo(
    id: 'top.clk',
    name: 'clk',
    fullPath: 'top.clk',
    signalType: 'wire',
    bitWidth: 1,
    scopeId: 0,
  ));
  
  writer.registerSignal(SignalInfo(
    id: 'top.data',
    name: 'data',
    fullPath: 'top.data',
    signalType: 'wire',
    bitWidth: 8,
    scopeId: 0,
  ));
  
  // Write header
  writer.writeHeader();
  
  // Write value changes
  writer.writeValue(0, 'top.clk', '0');
  writer.writeValue(0, 'top.data', '00000000');
  writer.writeValue(5, 'top.clk', '1');
  writer.writeValue(10, 'top.clk', '0');
  writer.writeValue(10, 'top.data', '10101010');
  
  await writer.close();
}
```

### WellenWaveDumper (ROHD-style API)

```dart
import 'package:rohd_wellen/rohd_wellen.dart';

Future<void> main() async {
  final dumper = WellenWaveDumper(
    'simulation.vcd',
    format: WaveFormat.vcd,
    timescale: '1ps',
  );
  
  // Register signals before opening
  dumper.registerSignal(SignalInfo(
    id: 'top.clk',
    name: 'clk',
    fullPath: 'top.clk',
    signalType: 'wire',
    bitWidth: 1,
    scopeId: 0,
  ));
  
  await dumper.open();
  
  // Record value changes (batched by timestamp)
  dumper.recordChange(0, 'top.clk', '0');
  dumper.recordChange(5, 'top.clk', '1');
  dumper.recordChange(10, 'top.clk', '0');
  dumper.recordChange(15, 'top.clk', '1');
  
  await dumper.close();
}
```

## Architecture

```text
packages/rohd_wellen/
├── lib/
│   ├── rohd_wellen.dart          # Main library export
│   └── src/
│       ├── models/               # Data models
│       │   ├── hierarchy.dart
│       │   ├── metadata.dart
│       │   ├── signal_data.dart
│       │   ├── signal_info.dart
│       │   └── wave_format.dart
│       ├── rust/
│       │   └── api.dart          # FFI bindings (generated)
│       ├── wellen_reader.dart    # Read VCD/FST/GHW
│       ├── wellen_writer.dart    # Write VCD/FST
│       └── wellen_wave_dumper.dart # ROHD-compatible API
└── rust/
    ├── Cargo.toml
    └── src/
        └── api.rs                # Rust API using wellen
```

## Development

### Generate FFI Bindings

After modifying `rust/src/api.rs`:

```bash
flutter_rust_bridge_codegen generate
```

### Build Rust Library

```bash
cd rust
cargo build --release
```

### Run Tests

```bash
dart test
```

## License

BSD-3-Clause

## See Also

- [ROHD](https://github.com/intel/rohd) - Rapid Open Hardware Development framework
- [wellen](https://github.com/ekiwi/wellen) - Rust waveform library
- [surfer](https://gitlab.com/surfer-project/surfer) - Wave viewer using wellen
