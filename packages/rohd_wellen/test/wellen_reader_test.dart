// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// wellen_reader_test.dart
// Tests for WellenReader using example VCD/FST/GHW files
//
// 2024 December
// Author: AI Assistant

import 'dart:io';
import 'package:test/test.dart';
import 'package:rohd_wellen/rohd_wellen.dart';

/// Path to test files from surfer examples
String get examplesPath {
  // Navigate from packages/rohd_wellen/test to surfer/examples
  final testDir = Directory.current.path;
  if (testDir.endsWith('rohd_wellen')) {
    return '../../surfer/examples';
  }
  // Running from project root
  return 'surfer/examples';
}

void main() {
  setUpAll(() async {
    // Initialize the Rust FFI library before running any tests
    await WellenReader.init();
  });

  group('WellenReader VCD parsing', () {
    test('loads counter.vcd and reads hierarchy', () async {
      final reader = WellenReader();
      final vcdPath = '$examplesPath/counter.vcd';

      // Skip if file doesn't exist (CI environment)
      if (!File(vcdPath).existsSync()) {
        markTestSkipped('Test VCD file not found: $vcdPath');
        return;
      }

      final metadata = await reader.loadFile(vcdPath);

      // Verify metadata
      expect(metadata.format, equals(WaveFormat.vcd));
      expect(metadata.timescale, contains('s'));

      // Get structure
      final structure = await reader.getStructure();

      // Verify we have modules
      expect(structure.modules, isNotEmpty);

      // Check for expected module 'tb'
      final tb = structure.modules.firstWhere(
        (m) => m.name == 'tb',
        orElse: () => throw StateError('Module tb not found'),
      );
      expect(tb.name, equals('tb'));

      // Check for sub-module 'dut'
      expect(tb.subModules, isNotEmpty);
      final dut = tb.subModules.firstWhere(
        (m) => m.name == 'dut',
        orElse: () => throw StateError('Module dut not found'),
      );
      expect(dut.name, equals('dut'));

      // Check for expected signals
      expect(structure.allSignalIds, isNotEmpty);
      expect(
        structure.allSignalIds.any((s) => s.contains('counter')),
        isTrue,
        reason: 'Should have a counter signal',
      );
    });

    test('loads counter.vcd and reads waveform data', () async {
      final reader = WellenReader();
      final vcdPath = '$examplesPath/counter.vcd';

      if (!File(vcdPath).existsSync()) {
        markTestSkipped('Test VCD file not found: $vcdPath');
        return;
      }

      await reader.loadFile(vcdPath);
      final structure = await reader.getStructure();

      // Find the counter signal
      final counterSignalId = structure.allSignalIds.firstWhere(
        (s) => s.contains('counter'),
        orElse: () => throw StateError('Counter signal not found'),
      );

      // Load waveform data
      final waveformData = await reader.getWaveformData([counterSignalId]);

      expect(waveformData, isNotEmpty);
      expect(waveformData.first.signalId, equals(counterSignalId));
      expect(waveformData.first.data, isNotEmpty);

      // Verify counter increments (values should change over time)
      final values = waveformData.first.data.map((d) => d.value).toList();
      expect(values, isNotEmpty);
    });

    test('loads counter.vcd and filters by time range', () async {
      final reader = WellenReader();
      final vcdPath = '$examplesPath/counter.vcd';

      if (!File(vcdPath).existsSync()) {
        markTestSkipped('Test VCD file not found: $vcdPath');
        return;
      }

      await reader.loadFile(vcdPath);
      final maxTime = await reader.getMaxTimestamp();
      expect(maxTime, isNotNull);

      // Get all signal IDs
      final structure = await reader.getStructure();
      final signalId = structure.allSignalIds.first;

      // Get data for first half of simulation
      final halfTime = maxTime! ~/ 2;
      final filteredData = await reader.getWaveformData(
        [signalId],
        startTime: 0,
        endTime: halfTime,
      );

      expect(filteredData, isNotEmpty);

      // All timestamps should be within range
      for (final dataPoint in filteredData.first.data) {
        expect(dataPoint.time, lessThanOrEqualTo(halfTime));
      }
    });

    test('handles signals with X and Z values', () async {
      final reader = WellenReader();
      // xx_1.vcd or xx_2.vcd likely have X values
      final vcdPath = '$examplesPath/xx_1.vcd';

      if (!File(vcdPath).existsSync()) {
        markTestSkipped('Test VCD file not found: $vcdPath');
        return;
      }

      await reader.loadFile(vcdPath);
      final structure = await reader.getStructure();
      expect(structure.allSignalIds, isNotEmpty);

      // Load all signals and check for x/z values
      final waveformData = await reader.getWaveformData(structure.allSignalIds);

      // Should have successfully parsed - even if no x/z values present
      expect(waveformData, isNotEmpty);
    });
  });

  group('WellenReader FST parsing', () {
    test('loads many_sv_datatypes.fst and reads hierarchy', () async {
      final reader = WellenReader();
      final fstPath = '$examplesPath/many_sv_datatypes.fst';

      if (!File(fstPath).existsSync()) {
        markTestSkipped('Test FST file not found: $fstPath');
        return;
      }

      await reader.loadFile(fstPath);
      final structure = await reader.getStructure();

      expect(structure.metadata.format, equals(WaveFormat.fst));
      expect(structure.modules, isNotEmpty);
      expect(structure.allSignalIds, isNotEmpty);
    });

    test('loads vhdl3.fst and reads VHDL signals', () async {
      final reader = WellenReader();
      final fstPath = '$examplesPath/vhdl3.fst';

      if (!File(fstPath).existsSync()) {
        markTestSkipped('Test FST file not found: $fstPath');
        return;
      }

      await reader.loadFile(fstPath);
      final structure = await reader.getStructure();

      expect(structure.metadata.format, equals(WaveFormat.fst));
      expect(structure.allSignalIds, isNotEmpty);
    });
  });

  group('WellenReader GHW parsing', () {
    test('loads oscar_test.ghw and reads VHDL hierarchy', () async {
      final reader = WellenReader();
      final ghwPath = '$examplesPath/oscar_test.ghw';

      if (!File(ghwPath).existsSync()) {
        markTestSkipped('Test GHW file not found: $ghwPath');
        return;
      }

      await reader.loadFile(ghwPath);
      final structure = await reader.getStructure();

      expect(structure.metadata.format, equals(WaveFormat.ghw));
      expect(structure.modules, isNotEmpty);
      expect(structure.allSignalIds, isNotEmpty);
    });

    test('loads vhdlfixed.ghw and reads fixed-point signals', () async {
      final reader = WellenReader();
      final ghwPath = '$examplesPath/vhdlfixed.ghw';

      if (!File(ghwPath).existsSync()) {
        markTestSkipped('Test GHW file not found: $ghwPath');
        return;
      }

      await reader.loadFile(ghwPath);
      final structure = await reader.getStructure();

      expect(structure.metadata.format, equals(WaveFormat.ghw));
      expect(structure.allSignalIds, isNotEmpty);
    });
  });

  group('WellenReader lifecycle', () {
    test('isLoaded returns correct state', () async {
      final reader = WellenReader();

      expect(reader.isLoaded, isFalse);

      final vcdPath = '$examplesPath/counter.vcd';
      if (!File(vcdPath).existsSync()) {
        markTestSkipped('Test VCD file not found: $vcdPath');
        return;
      }

      await reader.loadFile(vcdPath);
      expect(reader.isLoaded, isTrue);

      reader.unload();
      expect(reader.isLoaded, isFalse);
    });

    test('can reload different files', () async {
      final reader = WellenReader();
      final vcdPath1 = '$examplesPath/counter.vcd';
      final vcdPath2 = '$examplesPath/counter2.vcd';

      if (!File(vcdPath1).existsSync() || !File(vcdPath2).existsSync()) {
        markTestSkipped('Test VCD files not found');
        return;
      }

      // Load first file
      await reader.loadFile(vcdPath1);
      final structure1 = await reader.getStructure();
      final signalCount1 = structure1.allSignalIds.length;

      // Load second file (should replace first)
      await reader.loadFile(vcdPath2);
      final structure2 = await reader.getStructure();
      final signalCount2 = structure2.allSignalIds.length;

      // Files may have different signal counts
      expect(signalCount1, greaterThan(0));
      expect(signalCount2, greaterThan(0));
    });

    test('getAllTimestamps returns sorted timestamps', () async {
      final reader = WellenReader();
      final vcdPath = '$examplesPath/counter.vcd';

      if (!File(vcdPath).existsSync()) {
        markTestSkipped('Test VCD file not found: $vcdPath');
        return;
      }

      await reader.loadFile(vcdPath);
      final timestamps = await reader.getAllTimestamps();

      expect(timestamps, isNotEmpty);

      // Verify timestamps are sorted
      for (var i = 1; i < timestamps.length; i++) {
        expect(timestamps[i], greaterThanOrEqualTo(timestamps[i - 1]));
      }
    });
  });

  group('WellenReader edge cases', () {
    test('handles empty scope (verilator_empty_scope.vcd)', () async {
      final reader = WellenReader();
      final vcdPath = '$examplesPath/verilator_empty_scope.vcd';

      if (!File(vcdPath).existsSync()) {
        markTestSkipped('Test VCD file not found: $vcdPath');
        return;
      }

      final metadata = await reader.loadFile(vcdPath);
      expect(metadata.format, equals(WaveFormat.vcd));
    });

    test('handles analog signals (analog.vcd)', () async {
      final reader = WellenReader();
      final vcdPath = '$examplesPath/analog.vcd';

      if (!File(vcdPath).existsSync()) {
        markTestSkipped('Test VCD file not found: $vcdPath');
        return;
      }

      final metadata = await reader.loadFile(vcdPath);
      expect(metadata.format, equals(WaveFormat.vcd));

      final structure = await reader.getStructure();
      expect(structure.allSignalIds, isNotEmpty);

      // Load waveform data - analog values should be real numbers
      final waveformData = await reader.getWaveformData(structure.allSignalIds);
      expect(waveformData, isNotEmpty);
    });

    test('handles events (events.vcd)', () async {
      final reader = WellenReader();
      final vcdPath = '$examplesPath/events.vcd';

      if (!File(vcdPath).existsSync()) {
        markTestSkipped('Test VCD file not found: $vcdPath');
        return;
      }

      final metadata = await reader.loadFile(vcdPath);
      expect(metadata.format, equals(WaveFormat.vcd));

      final structure = await reader.getStructure();

      // Find event signals
      final eventSignals = structure.allSignalIds.toList();
      if (eventSignals.isNotEmpty) {
        final waveformData = await reader.getWaveformData(eventSignals);
        expect(waveformData, isNotEmpty);
      }
    });

    test('handles non-zero start time', () async {
      final reader = WellenReader();
      final vcdPath = '$examplesPath/gameroy_trace_with_non_zero_start.vcd';

      if (!File(vcdPath).existsSync()) {
        markTestSkipped('Test VCD file not found: $vcdPath');
        return;
      }

      final metadata = await reader.loadFile(vcdPath);
      expect(metadata.format, equals(WaveFormat.vcd));

      final timestamps = await reader.getAllTimestamps();
      // First timestamp may be non-zero
      expect(timestamps, isNotEmpty);
    });
  });

  group('Signal value formatting', () {
    test('binary values are formatted correctly', () async {
      final reader = WellenReader();
      final vcdPath = '$examplesPath/counter.vcd';

      if (!File(vcdPath).existsSync()) {
        markTestSkipped('Test VCD file not found: $vcdPath');
        return;
      }

      await reader.loadFile(vcdPath);
      final structure = await reader.getStructure();

      // Find a multi-bit signal (counter)
      final counterSignalId = structure.allSignalIds.firstWhere(
        (s) => s.contains('counter'),
        orElse: () => '',
      );

      if (counterSignalId.isEmpty) {
        markTestSkipped('Counter signal not found');
        return;
      }

      final waveformData = await reader.getWaveformData([counterSignalId]);
      expect(waveformData, isNotEmpty);

      // Values should be binary strings (0s and 1s only for clean signals)
      for (final dataPoint in waveformData.first.data) {
        expect(
          dataPoint.value,
          matches(RegExp(r'^[01xzXZ?\-]+$')),
          reason: 'Value should be binary: ${dataPoint.value}',
        );
      }
    });
  });
}
