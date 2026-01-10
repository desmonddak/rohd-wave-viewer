// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// dart_wellen.dart
// Wellen waveform library bindings for ROHD.
//
// 2026 January 03
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

///
/// This package provides Dart bindings to the wellen Rust library for
/// reading and writing waveform files in various formats:
///
/// - **VCD** - Value Change Dump (IEEE 1364)
/// - **FST** - Fast Signal Trace (GTKWave)
/// - **GHW** - GHDL Waveform
///
/// ## Reading Waveforms
///
/// ```dart
/// import 'package:dart_wellen/dart_wellen.dart';
///
/// final reader = WellenReader();
/// await reader.loadFile('simulation.vcd');
///
/// // Get the signal hierarchy
/// final hierarchy = await reader.getHierarchy();
///
/// // Get waveform data for specific signals
/// final data = await reader.getSignalData(['top.clk', 'top.reset']);
/// ```
///
/// ## Writing Waveforms (WaveDumper Extension)
///
/// ```dart
/// import 'package:dart_wellen/dart_wellen.dart';
///
/// // Create a WaveDumper that writes to FST format
/// final dumper = WellenWaveDumper(
///   'output.fst',
///   format: WaveFormat.fst,
/// );
///
/// // Use with ROHD simulation
/// Simulator.registerAction(dumper);
/// await Simulator.run();
/// await dumper.close();
/// ```
library;

// Re-export common types from module_structure_api for convenience
export 'package:module_structure_api/module_structure_api.dart'
    show
        ModuleStructure,
        Module,
        Signal,
        SignalInfo,
        MetaData,
        WaveFormat,
        WaveformData,
        Data;

export 'src/wellen_module_structure_api.dart';
export 'src/wellen_reader.dart';
export 'src/wellen_wave_dumper.dart';
export 'src/wellen_writer.dart';
