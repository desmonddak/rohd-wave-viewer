// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// main_web.dart
// Web-specific entry point for ROHD Wave Viewer (VS Code extension embedding).
// This version does NOT use dart:io and receives VCD content via postMessage.
// Uses wellen Rust library via flutter_rust_bridge WASM bindings.
//
// 2024 December

// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';
import 'src/platform/platform.dart' as plat;
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:rohd_wave_viewer/app.dart';
import 'package:module_structure_repository/module_structure_repository.dart';
import 'package:rohd_wellen/rohd_wellen.dart';

// platform facade imported once above

/// Web-compatible wrapper that initializes WellenModuleStructureApi with bytes.
class WebWellenApi {
  final WellenModuleStructureApi _api = WellenModuleStructureApi();
  bool _isLoaded = false;
  final _loadCompleter = Completer<void>();

  /// Returns the underlying API after loading is complete.
  WellenModuleStructureApi get api => _api;

  /// Wait for the waveform to be loaded.
  Future<void> get loaded => _loadCompleter.future;

  /// Load VCD content from bytes received via postMessage.
  Future<void> loadFromVcdContent(String vcdContent) async {
    try {
      debugPrint(
          '[WebWellen] Loading VCD content (${vcdContent.length} chars)');
      final bytes = utf8.encode(vcdContent);
      await _api.loadBytes(bytes, fileName: 'webview.vcd');
      _isLoaded = true;
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.complete();
      }
      debugPrint('[WebWellen] VCD loaded successfully');
    } catch (e, stackTrace) {
      debugPrint('[WebWellen] Error loading VCD: $e');
      debugPrint('[WebWellen] Stack trace: $stackTrace');
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.completeError(e);
      }
    }
  }

  bool get isLoaded => _isLoaded;
}

void main() async {
  // Disable URL strategies to avoid replaceState errors in VS Code webviews
  setUrlStrategy(null);

  WidgetsFlutterBinding.ensureInitialized();
  setGlobal(IdeTheme, getIdeTheme());

  // Initialize the wellen Rust library (WASM bindings)
  debugPrint('[WebMain] Initializing WellenModuleStructureApi...');
  try {
    await WellenModuleStructureApi.init();
    debugPrint('[WebMain] WellenModuleStructureApi initialized successfully');
    // Track whether WASM initialized. Expose a JS-global `wasmInitOk` so the
    // host (extension) can detect success. Use `js_util.setProperty` which
    // is a no-op when JS interop isn't available.
    try {
      plat.setProperty(plat.globalThis, 'wasmInitOk', true);
    } catch (_) {}
  } catch (e, stackTrace) {
    debugPrint('[WebMain] ERROR initializing WellenModuleStructureApi: $e');
    debugPrint('[WebMain] Stack trace: $stackTrace');
    try {
      plat.setProperty(plat.globalThis, 'wasmInitOk', false);
    } catch (_) {}
  }

  // Create web-compatible API wrapper
  final webApi = WebWellenApi();

  // Set up listener for VCD content from host (VS Code extension)
  try {
    final rohdEmbed = plat.rohdEmbed;
    if (rohdEmbed != null) {
      try {
        // Bind a Dart callback to the JS onMessage handler using allowInterop
        final onMessage = plat.getProperty(rohdEmbed, 'onMessage');
        if (onMessage != null) {
          plat.callMethod(rohdEmbed, 'onMessage', [
            plat.allowInterop((dynamic data) {
              try {
                String? type;
                String? text;
                try {
                  final dartified = plat.dartify(data);
                  if (dartified is Map) {
                    type = dartified['type']?.toString();
                    text = dartified['text']?.toString();
                  }
                } catch (_) {
                  // Fallback parsing for string payloads
                  if (data is String) {
                    try {
                      final parsed = json.decode(data);
                      if (parsed is Map) {
                        type = parsed['type']?.toString();
                        text = parsed['text']?.toString();
                      }
                    } catch (_) {}
                  }
                }

                debugPrint('[WebMain] Received message type: $type');
                if (type == 'vcdContents' && text != null) {
                  debugPrint(
                      '[WebMain] Loading VCD content (${text.length} chars)');
                  webApi.loadFromVcdContent(text);
                }
              } catch (e) {
                debugPrint('[WebMain] Error handling message: $e');
                }
              })
          ]);
        }
      } catch (e) {
        debugPrint('[WebMain] rohdEmbed.onMessage setup failed: $e');
      }
    }
  } catch (e) {
    debugPrint('[WebMain] checking rohdEmbed failed: $e');
  }

  // Signal to host that we're ready
  // If `wasmInitOk` is available in the JS interop environment, include it
  // in the readiness signal; otherwise omit the field.
  // Include the `wasm` boolean if present on the global object.
    try {
    final wasmFlag = plat.getProperty(plat.globalThis, 'wasmInitOk');
    if (wasmFlag != null) {
      plat.signalEmbedReady({'platform': 'web', 'version': '1.0.0', 'wasm': wasmFlag});
    } else {
      plat.signalEmbedReady({'platform': 'web', 'version': '1.0.0'});
    }
  } catch (_) {
    plat.signalEmbedReady({'platform': 'web', 'version': '1.0.0'});
  }

  runApp(
    App(
      moduleStructureRepository: ModuleStructureRepository(
        moduleStructureApi: webApi.api,
        apiReady: webApi.loaded,
      ),
    ),
  );
}

/// Stub function for conditional import from main.dart
/// On web, this returns a mock API since initialization happens via main() above.
Future<dynamic> initializeModuleStructureApi(List<String> args) async {
  // This is a stub - on web, main.dart uses kIsWeb check and returns MockModuleStructureApi
  throw UnsupportedError('Use kIsWeb check in main.dart instead');
}
