// Integration tests for ModuleStructureRepository using WellenModuleStructureApi
// Ensures integration with dart_wellen (VCD, FST, GHW)

import 'dart:io';
import 'package:test/test.dart';
import 'package:module_structure_repository/module_structure_repository.dart';
import 'package:dart_wellen/dart_wellen.dart';

String get fixturesPath {
  // The fixture files are in the project root under test/fixtures
  // From the test runner, we use the current working directory which should be the project root
  return 'test/fixtures';
}

void main() {
  setUpAll(() async {
    // Initialize Wellen FFI
    await WellenModuleStructureApi.init();
  });

  test('ModuleStructureRepository can load VCD (simple_counter.vcd)', () async {
    final api = WellenModuleStructureApi();
    final repo =
        ModuleStructureRepository(moduleStructureApi: api, apiReady: null);

    final filePath = '$fixturesPath/simple_counter.vcd';
    if (!File(filePath).existsSync()) {
      markTestSkipped('VCD example not found: $filePath');
      return;
    }

    await api.loadFile(filePath);
    final structure = await repo.getModuleStructure();
    expect(structure.modules, isNotEmpty);
    expect(structure.allSignalIds, isNotEmpty);
  });

  test('ModuleStructureRepository can load FST (vhdl3.fst)', () async {
    final api = WellenModuleStructureApi();
    final repo =
        ModuleStructureRepository(moduleStructureApi: api, apiReady: null);

    final filePath = '$fixturesPath/vhdl3.fst';
    if (!File(filePath).existsSync()) {
      markTestSkipped('FST example not found: $filePath');
      return;
    }

    await api.loadFile(filePath);
    final structure = await repo.getModuleStructureOnly();
    expect(structure.modules, isNotEmpty);
    expect(structure.allSignalIds, isNotEmpty);
  });

  test('ModuleStructureRepository can load GHW (vhdlfixed.ghw)', () async {
    final api = WellenModuleStructureApi();
    final repo =
        ModuleStructureRepository(moduleStructureApi: api, apiReady: null);

    final filePath = '$fixturesPath/vhdlfixed.ghw';
    if (!File(filePath).existsSync()) {
      markTestSkipped('GHW example not found: $filePath');
      return;
    }

    await api.loadFile(filePath);
    final structure = await repo.getModuleStructureOnly();
    expect(structure.modules, isNotEmpty);
    expect(structure.allSignalIds, isNotEmpty);
  });
}
