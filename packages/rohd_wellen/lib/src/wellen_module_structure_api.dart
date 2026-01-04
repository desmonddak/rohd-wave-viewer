// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// wellen_module_structure_api.dart
// Implementation of ModuleStructureApi using Wellen library
//
// 2026 January 03
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:module_structure_api/module_structure_api.dart';
import 'package:rohd_wellen/src/rust/api.dart' as rust;
import 'package:rohd_wellen/src/rust/frb_generated.dart';
import 'package:rohd_wellen/src/external_library_io.dart'
    if (dart.library.js_interop) 'package:rohd_wellen/src/external_library_web.dart';

/// Implementation of [ModuleStructureApi] using the Wellen library.
///
/// This provides native waveform reading for VCD, FST, and GHW formats
/// through the Rust wellen library via FFI.
class WellenModuleStructureApi extends ModuleStructureApi {
  static bool _initialized = false;
  rust.WaveformStructure? _cachedStructure;
  bool _isLoaded = false;

  /// Initialize the Rust FFI library.
  ///
  /// This must be called once before using any WellenModuleStructureApi instances.
  /// On web, the WASM must already be loaded via wasm_bindgen() before calling this.
  static Future<void> init() async {
    if (!_initialized) {
      // On web, pass an ExternalLibrary to skip WASM loading (already done via wasm_bindgen).
      // On native, returns null to let flutter_rust_bridge load the library normally.
      await RustLib.init(
        externalLibrary: createPreloadedExternalLibrary(),
      );
      _initialized = true;
    }
  }

  /// Loads a waveform file from the given path.
  ///
  /// This must be called before any other methods.
  /// Supports VCD, FST, and GHW formats.
  Future<void> loadFile(String filePath) async {
    await init();
    // Ask the Rust library to load the waveform file first so internal
    // WAVEFORM_STATE is populated. The generated API exposes `loadWaveform`.
    rust.loadWaveform(filePath: filePath);

    // After loading, request the structure from Rust and cache it locally.
    _cachedStructure = rust.getWaveformStructure();
    // Debug logging removed
    _isLoaded = true;
  }

  double _computeTimescaleToPsFromMetadata(rust.WaveformStructure? structure) {
    if (structure == null) return 1.0;
    final tsStr = structure.metadata.timescale; // e.g. "1ps" or "1ns"
    final int tsFactor = structure.metadata.timescaleFactor;
    String unit = 'ps';
    final match = RegExp(r"\d+(.*)").firstMatch(tsStr);
    if (match != null) {
      unit = match.group(1) ?? 'ps';
    }
    double unitToPs;
    switch (unit) {
      case 's':
        unitToPs = 1e12;
        break;
      case 'ms':
        unitToPs = 1e9;
        break;
      case 'us':
        unitToPs = 1e6;
        break;
      case 'ns':
        unitToPs = 1e3;
        break;
      case 'ps':
        unitToPs = 1.0;
        break;
      case 'fs':
        unitToPs = 1e-3;
        break;
      case 'as':
        unitToPs = 1e-6;
        break;
      case 'zs':
        unitToPs = 1e-9;
        break;
      default:
        unitToPs = 1.0;
    }
    return tsFactor * unitToPs;
  }

  /// Loads a waveform from bytes.
  ///
  /// This is useful for web environments or when the file is already in memory.
  /// [fileName] is optional and used for format detection hints.
  Future<void> loadBytes(List<int> bytes, {String? fileName}) async {
    await init();
    rust.loadWaveformFromBytes(bytes: bytes, fileName: fileName);
    _cachedStructure = rust.getWaveformStructure();
    _isLoaded = true;
  }

  @override
  Future<ModuleStructure> getModuleStructure() async {
    if (!_isLoaded || _cachedStructure == null) {
      throw StateError('No waveform loaded. Call loadFile() first.');
    }

    // Return module structure (without waveform data). Waveform data is
    // intentionally loaded separately by the repository to avoid double-fetch
    // and to allow streaming/append semantics.
    return _convertToModuleStructure(_cachedStructure!, []);
  }

  @override
  Future<ModuleStructure> getModuleStructureOnly() async {
    if (!_isLoaded || _cachedStructure == null) {
      throw StateError('No waveform loaded. Call loadFile() first.');
    }

    return _convertToModuleStructure(_cachedStructure!, []);
  }

  @override
  Future<List<WaveformData>> getWaveformData({
    required List<String> signalIds,
    int? startTime,
    int? endTime,
  }) async {
    if (!_isLoaded) {
      throw StateError('No waveform loaded. Call loadFile() first.');
    }

    final rustWaveformData = rust.getWaveformData(
      signalIds: signalIds,
      startTime: startTime != null ? BigInt.from(startTime) : null,
      endTime: endTime != null ? BigInt.from(endTime) : null,
    );

    return rustWaveformData.map(_convertWaveformData).toList();
  }

  @override
  Stream<WaveformData> streamWaveformData({
    required List<String> signalIds,
    int? startTime,
  }) async* {
    // For now, get all data at once and yield
    // In the future, this could stream in chunks for large waveforms
    final waveformDataList = await getWaveformData(
      signalIds: signalIds,
      startTime: startTime,
    );

    for (final waveformData in waveformDataList) {
      yield waveformData;
    }
  }

  /// Converts Wellen's WaveformStructure to viewer's ModuleStructure.
  ModuleStructure _convertToModuleStructure(
    rust.WaveformStructure wellenStructure,
    List<rust.SignalWaveformData> waveformData,
  ) {
    // Build a map of signal ID to waveform data for quick lookup
    final dataMap = <String, List<Data>>{};
    // Compute timescale multiplier to convert native units -> picoseconds
    final double timescaleToPs =
        _computeTimescaleToPsFromMetadata(wellenStructure);
    for (final signalData in waveformData) {
      final list = signalData.data.map((dp) {
        final int tPs = (dp.time.toDouble() * timescaleToPs).round();
        return Data(time: tPs, value: dp.value);
      }).toList();
      // Ensure data is sorted ascending by time for painters and lookups
      list.sort((a, b) => a.time.compareTo(b.time));
      dataMap[signalData.signalId] = list;
    }

    // Convert metadata start/end to picoseconds as well
    final int startTimePs =
        (wellenStructure.metadata.startTime.toDouble() * timescaleToPs).round();
    final int endTimePs =
        (wellenStructure.metadata.endTime.toDouble() * timescaleToPs).round();
    final metadata = MetaData(
      source: wellenStructure.metadata.source,
      timescale: wellenStructure.metadata.timescale,
      date: wellenStructure.metadata.date ?? '',
      startTime: startTimePs,
      endTime: endTimePs,
      timescaleFactor: wellenStructure.metadata.timescaleFactor,
      version: wellenStructure.metadata.version,
      format: WaveFormat.fromString(wellenStructure.metadata.format),
    );

    // Debug printing removed for production builds.

    // Convert module tree
    final modules = wellenStructure.modules
        .map((moduleNode) => _convertModuleNode(moduleNode, dataMap))
        .toList();

    return ModuleStructure(metadata: metadata, modules: modules);
  }

  /// Recursively converts a ModuleNode to Module.
  Module _convertModuleNode(
    rust.ModuleNode moduleNode,
    Map<String, List<Data>> dataMap,
  ) {
    // Convert signals
    final signals = moduleNode.signals
        .map((signalInfo) => Signal(
              id: signalInfo.id,
              name: signalInfo.name,
              type: signalInfo.signalType,
              width: signalInfo.bitWidth.toInt(),
              fullPath: signalInfo.fullPath,
              scopeId: signalInfo.scopeId.toInt(),
              data: dataMap[signalInfo.id] ?? [],
            ))
        .toList();

    // Convert sub-modules recursively
    final subModules = moduleNode.subModules
        .map((subModule) => _convertModuleNode(subModule, dataMap))
        .toList();

    return Module(
      name: moduleNode.name,
      fullPath: moduleNode.fullPath,
      scopeType: moduleNode.scopeType,
      signals: signals,
      subModules: subModules,
    );
  }

  /// Converts Rust SignalWaveformData to viewer's WaveformData.
  WaveformData _convertWaveformData(rust.SignalWaveformData rustData) {
    // Convert rust-native timestamps to picoseconds using metadata
    final double timescaleToPs =
        _computeTimescaleToPsFromMetadata(_cachedStructure);
    final data = rustData.data.map((dp) {
      final int tPs = (dp.time.toDouble() * timescaleToPs).round();
      return Data(time: tPs, value: dp.value);
    }).toList();
    // Ensure data is sorted ascending by time
    data.sort((a, b) => a.time.compareTo(b.time));

    return WaveformData(signalId: rustData.signalId, data: data);
  }
}
