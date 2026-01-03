// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// main.dart
// The main entry point for ROHD Wave Viewer.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'dart:io';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:rohd_wave_viewer/app.dart';
import 'package:module_structure_repository/module_structure_repository.dart';
import 'package:module_structure_api/module_structure_api.dart';
import 'package:rohd_wellen/rohd_wellen.dart';

import 'mock_module_structure_api.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  setGlobal(IdeTheme, getIdeTheme());

  // Create the appropriate ModuleStructureApi based on command-line arguments
  ModuleStructureApi moduleStructureApi;

  if (args.isNotEmpty) {
    // First argument is assumed to be a waveform file path
    final filePath = args[0];
    final file = File(filePath);

    if (!file.existsSync()) {
      stderr.writeln('Error: File not found: $filePath');
      stderr.writeln('Usage: rohd_wave_viewer [path/to/waveform.vcd]');
      exit(1);
    }

    // Loading waveform from: $filePath
    final wellenApi = WellenModuleStructureApi();

    try {
      await wellenApi.loadFile(filePath);
      moduleStructureApi = wellenApi;
      // Waveform loaded successfully
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
        // Loading waveform from environment variable ROHD_WAVE_VCD: $envPath
        final wellenApi = WellenModuleStructureApi();
        try {
          await wellenApi.loadFile(envPath);
          moduleStructureApi = wellenApi;
          // Waveform loaded successfully (env)
        } catch (e) {
          stderr.writeln('Error loading waveform from env: $e');
          exit(1);
        }
      } else {
        // ROHD_WAVE_VCD set but file not found: $envPath
        // No waveform file specified, using mock data
        moduleStructureApi = MockModuleStructureApi();
      }
    } else {
      // No arguments and no env var - use mock data
      // No waveform file specified, using mock data
      // Usage: rohd_wave_viewer [path/to/waveform.vcd]
      moduleStructureApi = MockModuleStructureApi();
    }
  }

  runApp(
    App(
      moduleStructureRepository: ModuleStructureRepository(
        moduleStructureApi: moduleStructureApi,
      ),
    ),
  );
}
