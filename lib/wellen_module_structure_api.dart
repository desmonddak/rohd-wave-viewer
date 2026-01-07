// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// wellen_module_structure_api.dart
// Implementation of ModuleStructureApi using the wellen Rust library via FFI.
//
// 2024 December 30

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:module_structure_api/module_structure_api.dart';
import 'src/platform/platform.dart' as plat;
import 'src/generated/api.dart' as rust;
import 'src/rust/wellen_helpers.dart' as helpers;

class WellenModuleStructureApi extends ModuleStructureApi {
  String? _loadedFilePath;
  rust.WaveformStructure? _cachedStructure;
  List<String> _allSignalIds = [];

  Future<void> loadFile(String filePath) async {
    final bytes = await plat.readFileBytes(filePath);
    await rust.loadWaveformFromBytes(bytes: bytes, fileName: filePath);
    _loadedFilePath = filePath;
    _cachedStructure = await rust.getWaveformStructure();
    _allSignalIds = _cachedStructure?.allSignalIds ?? [];

    try {
      if (_allSignalIds.isNotEmpty) {
        final sampleSignal = _allSignalIds.first;
        final data = await helpers.getWaveformDataDebug(
          signalIds: [sampleSignal],
        );
        if (data.isNotEmpty && data.first.data.isNotEmpty) {
          final values = data.first.data.take(8).map((p) => p.value).toList();
          debugPrint(
            '[FRB_DEBUG] First signal: $sampleSignal first_values=$values',
          );
        } else {
          debugPrint('[FRB_DEBUG] No waveform data points for $sampleSignal');
        }
      }
    } catch (e, st) {
      debugPrint('[FRB_DEBUG] Error fetching debug waveform data: $e $st');
    }
  }

  @override
  Future<ModuleStructure> getModuleStructure() async {
    if (_cachedStructure == null) {
      return ModuleStructure.empty();
    }
    return _convertToModuleStructure(_cachedStructure!);
  }

  ModuleStructure _convertToModuleStructure(rust.WaveformStructure rustStruct) {
    return ModuleStructure(
      metadata: MetaData(
        source: rustStruct.metadata.source,
        timescale: rustStruct.metadata.timescale,
        date: rustStruct.metadata.date ?? '',
      ),
      modules: rustStruct.modules.map(_convertModuleNode).toList(),
    );
  }

  Module _convertModuleNode(rust.ModuleNode rustNode) {
    return Module(
      name: rustNode.name,
      subModules: rustNode.subModules.map(_convertModuleNode).toList(),
      signals: rustNode.signals.map(_convertSignalInfo).toList(),
    );
  }

  Signal _convertSignalInfo(rust.SignalInfo rustInfo) {
    return Signal(
      id: rustInfo.id,
      name: rustInfo.name,
      type: rustInfo.signalType,
      width: rustInfo.bitWidth,
      data: [],
      fullPath: rustInfo.fullPath,
      scopeId: rustInfo.scopeId.toInt(),
    );
  }

  @override
  Future<List<WaveformData>> getWaveformData({
    required List<String> signalIds,
    int? startTime,
    int? endTime,
  }) async {
    final rustData = await rust.getWaveformData(
      signalIds: signalIds,
      startTime: startTime != null ? BigInt.from(startTime) : null,
      endTime: endTime != null ? BigInt.from(endTime) : null,
    );

    return rustData.map((rd) {
      return WaveformData(
        signalId: rd.signalId,
        data: rd.data
            .map((dp) => Data(time: dp.time.toInt(), value: dp.value))
            .toList(),
      );
    }).toList();
  }

  @override
  Stream<WaveformData> streamWaveformData({
    required List<String> signalIds,
    int? startTime,
  }) async* {
    final allData = await getWaveformData(
      signalIds: signalIds,
      startTime: startTime,
    );
    for (final item in allData) {
      yield item;
    }
  }

  List<String> get allSignalIds => _allSignalIds;
  bool get isLoaded => _loadedFilePath != null;
  String? get loadedFilePath => _loadedFilePath;

  void unload() {
    rust.unloadWaveform();
    _loadedFilePath = null;
    _cachedStructure = null;
    _allSignalIds = [];
  }
}
