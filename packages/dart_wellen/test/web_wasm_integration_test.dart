@TestOn('browser')
// Web/WASM integration tests for Wellen via WellenModuleStructureApi

import 'package:test/test.dart';
import 'package:dart_wellen/dart_wellen.dart';
import 'package:dart_wellen/src/external_library_io.dart'
    if (dart.library.js_interop) 'package:dart_wellen/src/external_library_web.dart'
    as platform;

String get fixturesBasePath {
  // When tests run in the browser via the test runner, files under package root
  // are served relative to the test directory. We expose test/fixtures via
  // package-relative path using the test server's file serving.
  return '/packages/rohd_wave_viewer/test/fixtures';
}

void main() {
  setUpAll(() async {
    // Ensure the wasm JS is loaded by the test HTML runner - the test server
    // will serve web/pkg at /packages/rohd_wave_viewer/web/pkg when "pub run test" is used.
    try {
      await platform.waitForWasmInit();
    } catch (_) {
      // wasm_bindgen not available yet; try loading the script
      await platform.loadWasmScript(
          '/packages/rohd_wave_viewer/web/pkg/wellen_bridge.js');
    }
    // Initialize the Wellen WASM bindings
    await WellenModuleStructureApi.init();
  });

  test('WASM load simple_counter.vcd via loadBytes', () async {
    final url = '$fixturesBasePath/simple_counter.vcd';
    final bytes = await platform.fetchBytes(url);
    final api = WellenModuleStructureApi();
    await api.loadBytes(bytes.toList(), fileName: 'simple_counter.vcd');

    final structure = await api.getModuleStructure();
    expect(structure.modules, isNotEmpty);
    expect(structure.allSignalIds, isNotEmpty);
  });

  test('WASM load xz_transitions.vcd via loadBytes', () async {
    final url = '$fixturesBasePath/xz_transitions.vcd';
    final bytes = await platform.fetchBytes(url);
    final api = WellenModuleStructureApi();
    await api.loadBytes(bytes.toList(), fileName: 'xz_transitions.vcd');

    final structure = await api.getModuleStructureOnly();
    expect(structure.modules, isNotEmpty);
    expect(structure.allSignalIds, isNotEmpty);
  });
}
