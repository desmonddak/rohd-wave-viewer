// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// wellen_reader_simple_test.dart
// Simplified tests for WellenReader using test fixtures
//
// 2026 January 09
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';
import 'package:test/test.dart';
import 'package:dart_wellen/dart_wellen.dart';

/// Path to test fixture files
String get fixturesPath {
  // The fixture files are in the project root under test/fixtures
  return 'test/fixtures';
}

void main() {
  setUpAll(() async {
    // Initialize the Rust FFI library before running any tests
    await WellenReader.init();
  });

  group('WellenReader VCD parsing with fixtures', () {
    test('loads simple_counter.vcd and reads hierarchy', () async {
      final reader = WellenReader();
      final vcdPath = '$fixturesPath/simple_counter.vcd';

      // Skip if file doesn't exist
      if (!File(vcdPath).existsSync()) {
        markTestSkipped('Test VCD file not found: $vcdPath');
        return;
      }

      final metadata = await reader.loadFile(vcdPath);

      // Verify metadata
      expect(metadata.format, equals(WaveFormat.vcd));
      expect(metadata.timescale, isNotEmpty);

      // Get structure
      final structure = await reader.getStructure();

      // Verify we have modules
      expect(structure.modules, isNotEmpty);

      // Check for expected module 'counter'
      final counterModule = structure.modules.firstWhere(
        (m) => m.name == 'counter',
        orElse: () => throw StateError('Module counter not found'),
      );
      expect(counterModule.name, equals('counter'));

      // Check for expected signals
      expect(structure.allSignalIds, isNotEmpty);
      expect(
        structure.allSignalIds.any((s) => s.contains('clk')),
        isTrue,
        reason: 'Should have a clk signal',
      );
    });

    test('loads simple_counter.vcd and reads waveform data', () async {
      final reader = WellenReader();
      final vcdPath = '$fixturesPath/simple_counter.vcd';

      if (!File(vcdPath).existsSync()) {
        markTestSkipped('Test VCD file not found: $vcdPath');
        return;
      }

      await reader.loadFile(vcdPath);
      final structure = await reader.getStructure();

      // Find the clk signal
      final clkSignalId = structure.allSignalIds.firstWhere(
        (s) => s.contains('clk'),
        orElse: () => throw StateError('clk signal not found'),
      );

      // Load waveform data
      final waveformData = await reader.getWaveformData([clkSignalId]);

      expect(waveformData, isNotEmpty);
      expect(waveformData.first.signalId, equals(clkSignalId));
      expect(waveformData.first.data, isNotEmpty);
    });

    test('loads xz_transitions.vcd with X and Z values', () async {
      final reader = WellenReader();
      final vcdPath = '$fixturesPath/xz_transitions.vcd';

      if (!File(vcdPath).existsSync()) {
        markTestSkipped('Test VCD file not found: $vcdPath');
        return;
      }

      final metadata = await reader.loadFile(vcdPath);
      expect(metadata.format, equals(WaveFormat.vcd));

      final structure = await reader.getStructure();
      expect(structure.modules, isNotEmpty);

      // This file specifically has X and Z transitions
      final testModule = structure.modules.firstWhere(
        (m) => m.name == 'test',
        orElse: () => throw StateError('Module test not found'),
      );
      expect(testModule.name, equals('test'));

      // Load waveform data to verify X/Z handling
      final waveformData = await reader.getWaveformData(structure.allSignalIds);
      expect(waveformData, isNotEmpty);
    });
  });

  group('WellenReader lifecycle', () {
    test('can load and close file', () async {
      final reader = WellenReader();
      final vcdPath = '$fixturesPath/simple_counter.vcd';

      if (!File(vcdPath).existsSync()) {
        markTestSkipped('Test VCD file not found: $vcdPath');
        return;
      }

      await reader.loadFile(vcdPath);
      final structure = await reader.getStructure();
      expect(structure.modules, isNotEmpty);

      // Should be able to close without error
      await reader.close();
    });
  });
}
