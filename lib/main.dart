// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// main.dart
// The main entry point for ROHD Wave Viewer.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
// Use a platform wrapper for setUrlStrategy so native builds don't import web-only libraries
import 'src/platform/url_strategy_io.dart'
    if (dart.library.js_interop) 'src/platform/url_strategy_web.dart'
    as url_strategy;
import 'package:rohd_wave_viewer/app.dart';
import 'package:module_structure_repository/module_structure_repository.dart';
import 'package:module_structure_api/module_structure_api.dart';

import 'mock_module_structure_api.dart';

// Conditional import for dart:io (only available on non-web platforms)
import 'main_io.dart' if (dart.library.js_interop) 'main_web.dart' as platform;

void main(List<String> args) async {
  // Disable URL strategies on web to avoid replaceState errors in webviews
  if (kIsWeb) {
    url_strategy.setUrlStrategySafe(null);
  }

  WidgetsFlutterBinding.ensureInitialized();
  setGlobal(IdeTheme, getIdeTheme());

  // Create the appropriate ModuleStructureApi based on platform
  ModuleStructureApi moduleStructureApi;

  if (kIsWeb) {
    // On web, start with mock data - the extension will send VCD contents via postMessage
    moduleStructureApi = MockModuleStructureApi();
  } else {
    // On native platforms, use the platform-specific initialization
    moduleStructureApi = await platform.initializeModuleStructureApi(args);
  }

  runApp(
    App(
      moduleStructureRepository: ModuleStructureRepository(
        moduleStructureApi: moduleStructureApi,
      ),
    ),
  );
}
