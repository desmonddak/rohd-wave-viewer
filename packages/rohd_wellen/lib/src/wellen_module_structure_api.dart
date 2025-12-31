// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// wellen_module_structure_api.dart
// Implementation of ModuleStructureApi using Wellen library
//
// 2024 December 30
// Author: Max Korbel <max.korbel@intel.com>

import 'package:module_structure_api/module_structure_api.dart';
import 'package:rohd_wellen/src/rust/api.dart' as rust;
import 'package:rohd_wellen/src/rust/frb_generated.dart';

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
  static Future<void> init() async {
    if (!_initialized) {
      await RustLib.init();
      _initialized = true;
    }
  }

  /// Loads a waveform file from the given path.
  ///
  /// This must be called before any other methods.
  /// Supports VCD, FST, and GHW formats.
  Future<void> loadFile(String filePath) async {
    await init();
    final meta = await rust.loadWaveform(filePath: filePath);
    // Log metadata returned from Rust for debugging
    print(
        'Wellen loadFile metadata: source=${meta.source} timescale=${meta.timescale} start=${meta.startTime} end=${meta.endTime} format=${meta.format}');
    _cachedStructure = await rust.getWaveformStructure();
    print(
        'Wellen loaded structure: modules=${_cachedStructure?.modules.length ?? 0} allSignalIds=${_cachedStructure?.allSignalIds.length ?? 0}');
    _isLoaded = true;
  }

  /// Loads a waveform from bytes.
  ///
  /// This is useful for web environments or when the file is already in memory.
  /// [fileName] is optional and used for format detection hints.
  Future<void> loadBytes(List<int> bytes, {String? fileName}) async {
    await init();
    // TODO: Uncomment when load_waveform_from_bytes is available in generated code
    // await rust.loadWaveformFromBytes(bytes: bytes, fileName: fileName);
    // For now, this is not implemented - use loadFile instead
    throw UnimplementedError(
      'loadBytes is not yet implemented. Use loadFile() for now.',
    );
    // _cachedStructure = await rust.getWaveformStructure();
    // _isLoaded = true;
  }

  @override
  Future<ModuleStructure> getModuleStructure() async {
    if (!_isLoaded || _cachedStructure == null) {
      throw StateError('No waveform loaded. Call loadFile() first.');
    }

    // Get all signal data
    final allSignalIds = _cachedStructure!.allSignalIds;
    print(
        'Wellen getModuleStructure: requesting waveform data for ${allSignalIds.length} signals');
    final waveformDataList = await rust.getWaveformData(
      signalIds: allSignalIds,
    );
    print(
        'Wellen getModuleStructure: retrieved ${waveformDataList.length} waveform entries');

    return _convertToModuleStructure(_cachedStructure!, waveformDataList);
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

    final rustWaveformData = await rust.getWaveformData(
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
    for (final signalData in waveformData) {
      dataMap[signalData.signalId] = signalData.data
          .map((dp) => Data(time: dp.time.toInt(), value: dp.value))
          .toList();
    }

    // Convert metadata
    final metadata = MetaData(
      source: wellenStructure.metadata.source,
      timescale: wellenStructure.metadata.timescale,
      date: wellenStructure.metadata.date ?? '',
      startTime: wellenStructure.metadata.startTime.toInt(),
      endTime: wellenStructure.metadata.endTime.toInt(),
    );

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
              data: dataMap[signalInfo.id] ?? [],
            ))
        .toList();

    // Convert sub-modules recursively
    final subModules = moduleNode.subModules
        .map((subModule) => _convertModuleNode(subModule, dataMap))
        .toList();

    return Module(
      name: moduleNode.name,
      signals: signals,
      subModules: subModules,
    );
  }

  /// Converts Rust SignalWaveformData to viewer's WaveformData.
  WaveformData _convertWaveformData(rust.SignalWaveformData rustData) {
    final data = rustData.data
        .map((dp) => Data(time: dp.time.toInt(), value: dp.value))
        .toList();

    return WaveformData(signalId: rustData.signalId, data: data);
  }
}
