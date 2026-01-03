// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// wellen_writer.dart
// Wellen-based waveform file writer for VCD, FST formats.
//
// 2025 Intel Corporation

import 'dart:async';
import 'dart:io';

import 'package:module_structure_api/module_structure_api.dart';

/// A writer for waveform files.
///
/// This class provides functionality to write VCD and FST waveform files.
/// It can be used standalone or as part of a WaveDumper implementation.
///
/// Example usage:
/// ```dart
/// final writer = WellenWriter();
///
/// await writer.open(
///   '/path/to/output.vcd',
///   format: WaveFormat.vcd,
///   timescale: '1ns',
/// );
///
/// // Register signals
/// writer.registerSignal(SignalInfo(
///   id: 'clk',
///   name: 'clk',
///   fullPath: 'top.clk',
///   type: 'wire',
///   width: 1,
///   scopeId: 0,
/// ));
///
/// // Write data
/// writer.writeHeader();
/// writer.writeValue(0, 'clk', '0');
/// writer.writeValue(5, 'clk', '1');
/// writer.writeValue(10, 'clk', '0');
///
/// await writer.close();
/// ```
class WellenWriter {
  /// The file being written to.
  File? _file;

  /// The output sink.
  IOSink? _sink;

  /// The output format.
  WaveFormat _format = WaveFormat.vcd;

  /// The timescale string.
  String _timescale = '1ns';

  /// Registered signals.
  final Map<String, _SignalRegistration> _signals = {};

  /// Next VCD identifier code.
  int _nextIdCode = 0;

  /// Current simulation time.
  int _currentTime = -1;

  /// Whether the header has been written.
  bool _headerWritten = false;

  /// Whether the writer is open.
  bool get isOpen => _sink != null;

  /// The output format.
  WaveFormat get format => _format;

  /// Open a file for writing.
  ///
  /// [filePath] - Path to the output file.
  /// [format] - Output format (VCD or FST). Defaults to VCD.
  /// [timescale] - Timescale string (e.g., "1ns", "1ps"). Defaults to "1ns".
  /// [date] - Optional date string for the header.
  /// [version] - Optional version string for the header.
  Future<void> open(
    String filePath, {
    WaveFormat format = WaveFormat.vcd,
    String timescale = '1ns',
    String? date,
    String? version,
  }) async {
    if (_sink != null) {
      throw WellenWriterException('Writer is already open');
    }

    if (format == WaveFormat.ghw) {
      throw WellenWriterException('GHW format is read-only');
    }

    if (format == WaveFormat.unknown) {
      throw WellenWriterException('Unknown format is not supported');
    }

    _format = format;
    _timescale = timescale;
    _file = File(filePath);
    _sink = _file!.openWrite();

    // Write VCD header preamble
    if (_format == WaveFormat.vcd) {
      _sink!.writeln('\$date');
      _sink!.writeln('   ${date ?? DateTime.now().toIso8601String()}');
      _sink!.writeln('\$end');
      _sink!.writeln('\$version');
      _sink!.writeln('   ${version ?? 'ROHD Wellen Writer 1.0'}');
      _sink!.writeln('\$end');
      _sink!.writeln('\$timescale');
      _sink!.writeln('   $_timescale');
      _sink!.writeln('\$end');
    }

    // TODO: Implement FST writing via Rust FFI
    if (_format == WaveFormat.fst) {
      throw WellenWriterException('FST writing not yet implemented');
    }
  }

  /// Register a signal to be written.
  ///
  /// Signals must be registered before calling [writeHeader].
  void registerSignal(SignalInfo signal) {
    if (_headerWritten) {
      throw WellenWriterException(
        'Cannot register signals after header is written',
      );
    }

    final idCode = _generateIdCode();
    _signals[signal.id] = _SignalRegistration(
      info: signal,
      vcdCode: idCode,
    );
  }

  /// Register multiple signals at once.
  void registerSignals(Iterable<SignalInfo> signals) {
    for (final signal in signals) {
      registerSignal(signal);
    }
  }

  /// Write the header section with scope and signal definitions.
  ///
  /// Must be called after registering all signals and before writing values.
  void writeHeader() {
    if (_sink == null) {
      throw WellenWriterException('Writer is not open');
    }
    if (_headerWritten) {
      throw WellenWriterException('Header already written');
    }

    if (_format == WaveFormat.vcd) {
      _writeVcdHeader();
    }

    _headerWritten = true;
  }

  /// Write a value change for a signal.
  ///
  /// [time] - Simulation time.
  /// [signalId] - The signal identifier (full path).
  /// [value] - The value as a string (e.g., "0", "1", "01010101", "x", "z").
  void writeValue(int time, String signalId, String value) {
    if (_sink == null) {
      throw WellenWriterException('Writer is not open');
    }
    if (!_headerWritten) {
      throw WellenWriterException('Header must be written first');
    }

    final registration = _signals[signalId];
    if (registration == null) {
      throw WellenWriterException('Signal not registered: $signalId');
    }

    if (_format == WaveFormat.vcd) {
      // Write time if changed
      if (time != _currentTime) {
        _sink!.writeln('#$time');
        _currentTime = time;
      }

      // Write value change
      final width = registration.info.width ?? 1;
      if (width == 1) {
        // Single-bit: just value followed by code
        _sink!.writeln('$value${registration.vcdCode}');
      } else {
        // Multi-bit: b prefix, value, space, code
        _sink!.writeln('b$value ${registration.vcdCode}');
      }
    }
  }

  /// Write multiple value changes for the same time.
  void writeValues(int time, Map<String, String> values) {
    for (final entry in values.entries) {
      writeValue(time, entry.key, entry.value);
    }
  }

  /// Write signal data from a list of WaveformData objects.
  void writeSignalData(List<WaveformData> signalDataList) {
    // Collect all time points
    final allTimes = <int>{};
    for (final signalData in signalDataList) {
      for (final point in signalData.data) {
        allTimes.add(point.time);
      }
    }

    // Sort times
    final sortedTimes = allTimes.toList()..sort();

    // Build a map of time -> signal -> value
    final timeToValues = <int, Map<String, String>>{};
    for (final time in sortedTimes) {
      timeToValues[time] = {};
    }

    for (final signalData in signalDataList) {
      for (final point in signalData.data) {
        timeToValues[point.time]![signalData.signalId] = point.value;
      }
    }

    // Write in time order
    for (final time in sortedTimes) {
      writeValues(time, timeToValues[time]!);
    }
  }

  /// Flush buffered output.
  Future<void> flush() async {
    await _sink?.flush();
  }

  /// Close the writer.
  Future<void> close() async {
    if (_sink != null) {
      await _sink!.flush();
      await _sink!.close();
      _sink = null;
      _file = null;
    }

    _signals.clear();
    _nextIdCode = 0;
    _currentTime = -1;
    _headerWritten = false;
  }

  /// Write the VCD header with scope definitions.
  void _writeVcdHeader() {
    // Group signals by scope
    final scopes = <String, List<_SignalRegistration>>{};

    for (final reg in _signals.values) {
      final scopePath = _getScopePath(reg.info.fullPath ?? reg.info.id);
      scopes.putIfAbsent(scopePath, () => []).add(reg);
    }

    // Write scope hierarchy
    final writtenScopes = <String>{};

    for (final scopePath in scopes.keys.toList()..sort()) {
      _writeScopeHierarchy(scopePath, writtenScopes, scopes);
    }

    // Close any open scopes
    for (var i = 0; i < writtenScopes.length; i++) {
      _sink!.writeln('\$upscope \$end');
    }

    // End definitions
    _sink!.writeln('\$enddefinitions \$end');
  }

  /// Write scope hierarchy for a given path.
  void _writeScopeHierarchy(
    String scopePath,
    Set<String> writtenScopes,
    Map<String, List<_SignalRegistration>> scopes,
  ) {
    if (writtenScopes.contains(scopePath)) {
      return;
    }

    // Write parent scopes first
    final parts = scopePath.split('.');
    var currentPath = '';

    for (var i = 0; i < parts.length; i++) {
      if (i > 0) currentPath += '.';
      currentPath += parts[i];

      if (!writtenScopes.contains(currentPath)) {
        // Close previous scope if needed
        if (i > 0) {
          // Don't close, we're going deeper
        }

        _sink!.writeln('\$scope module ${parts[i]} \$end');
        writtenScopes.add(currentPath);
      }
    }

    // Write signals in this scope
    final signals = scopes[scopePath];
    if (signals != null) {
      for (final reg in signals) {
        final typeStr = _vcdVarType(reg.info.type);
        _sink!.writeln(
          '\$var $typeStr ${reg.info.width ?? 1} ${reg.vcdCode} ${reg.info.name} \$end',
        );
      }
    }
  }

  /// Get the scope path from a full signal path.
  String _getScopePath(String fullPath) {
    final lastDot = fullPath.lastIndexOf('.');
    if (lastDot < 0) return '';
    return fullPath.substring(0, lastDot);
  }

  /// Convert signal type to VCD variable type.
  String _vcdVarType(String signalType) {
    switch (signalType.toLowerCase()) {
      case 'wire':
        return 'wire';
      case 'reg':
        return 'reg';
      case 'logic':
        return 'wire';
      case 'integer':
        return 'integer';
      case 'real':
        return 'real';
      case 'parameter':
        return 'parameter';
      default:
        return 'wire';
    }
  }

  /// Generate a VCD identifier code.
  String _generateIdCode() {
    // VCD uses printable ASCII characters 33-126 for codes
    // We'll use a simple scheme: !, ", #, ... up to ~
    // For more signals, we'll use multi-character codes

    var code = _nextIdCode++;
    var result = '';

    do {
      final charCode = 33 + (code % 94); // ASCII 33-126
      result = String.fromCharCode(charCode) + result;
      code = code ~/ 94;
    } while (code > 0);

    return result;
  }
}

/// Internal signal registration data.
class _SignalRegistration {
  final SignalInfo info;
  final String vcdCode;

  _SignalRegistration({
    required this.info,
    required this.vcdCode,
  });
}

/// Exception thrown by WellenWriter operations.
class WellenWriterException implements Exception {
  /// Creates a new WellenWriterException with the given message.
  WellenWriterException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'WellenWriterException: $message';
}
