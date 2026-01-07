// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// main_io.dart
// Native platform (IO) initialization for ROHD Wave Viewer.

// 2026 January 03
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';
import 'package:module_structure_api/module_structure_api.dart';
import 'package:rohd_wellen/rohd_wellen.dart';
import 'mock_module_structure_api.dart';

/// Initialize ModuleStructureApi for native platforms (Linux, macOS, Windows)
Future<ModuleStructureApi> initializeModuleStructureApi(
    List<String> args) async {
  if (args.isNotEmpty) {
    // First argument is assumed to be a waveform file path
    final filePath = args[0];
    final file = File(filePath);

    if (!file.existsSync()) {
      stderr.writeln('Error: File not found: $filePath');
      stderr.writeln('Usage: rohd_wave_viewer [path/to/waveform.vcd]');
      exit(1);
    }

    final wellenApi = WellenModuleStructureApi();

    try {
      await wellenApi.loadFile(filePath);
      return wellenApi;
    } catch (e) {
      stderr.writeln('Error loading waveform: $e');
      exit(1);
    }
  } else {
    // No CLI args — allow environment variable fallback for desktop debug runs
    final envPath = Platform.environment['ROHD_WAVE_VCD'];
    if (envPath != null && envPath.isNotEmpty) {
      final file = File(envPath);
      if (file.existsSync()) {
        final wellenApi = WellenModuleStructureApi();
        try {
          await wellenApi.loadFile(envPath);
          return wellenApi;
        } catch (e) {
          stderr.writeln('Error loading waveform from env: $e');
          exit(1);
        }
      }
    }
  }

  // No arguments and no env var - use mock data
  return MockModuleStructureApi();
}
