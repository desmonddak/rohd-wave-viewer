// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// module_structure_api.dart
// An abstract class that defines the API for module structure.
//
// 2024 January 29
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:module_structure_api/module_structure_api.dart';

/// An abstract class that defines the API for module structure.
///
/// It contains methods to get the module structure and manage waveform data.
abstract class ModuleStructureApi {
  /// Creates a new instance of [ModuleStructureApi].
  const ModuleStructureApi();

  /// Retrieves the module structure including signals with their waveform data.
  ///
  /// This is the original method that returns the complete structure with data.
  /// Returns a [Future] that completes with the [ModuleStructure].
  Future<ModuleStructure> getModuleStructure();

  /// Retrieves the module and signal structure without waveform data.
  ///
  /// This method returns only the hierarchical structure of modules and signals,
  /// without any waveform data. Use this for initial loading of the structure,
  /// then call [getWaveformData] or [streamWaveformData] to load data separately.
  ///
  /// Returns a [Future] that completes with the [ModuleStructure] containing
  /// signals with empty data lists.
  Future<ModuleStructure> getModuleStructureOnly() async {
    // Default implementation: get full structure and strip data
    final fullStructure = await getModuleStructure();
    return _stripWaveformData(fullStructure);
  }

  /// Retrieves waveform data for specific signals.
  ///
  /// [signalIds] is a list of signal IDs for which to retrieve data.
  /// [startTime] and [endTime] optionally specify a time range for the data.
  ///
  /// Returns a [Future] that completes with a list of [WaveformData] objects.
  Future<List<WaveformData>> getWaveformData({
    required List<String> signalIds,
    int? startTime,
    int? endTime,
  }) async {
    // Default implementation: get full structure and extract data
    final fullStructure = await getModuleStructure();
    final signalIdSet = signalIds.toSet();
    final waveformDataList = <WaveformData>[];

    void extractFromModules(List<Module> modules) {
      for (final module in modules) {
        for (final signal in module.signals) {
          if (signalIdSet.contains(signal.id)) {
            var filteredData = signal.data;
            if (startTime != null || endTime != null) {
              filteredData = signal.data.where((d) {
                if (startTime != null && d.time < startTime) return false;
                if (endTime != null && d.time > endTime) return false;
                return true;
              }).toList();
            }
            waveformDataList.add(WaveformData(
              signalId: signal.id,
              data: filteredData,
            ));
          }
        }
        extractFromModules(module.subModules);
      }
    }

    extractFromModules(fullStructure.modules);
    return waveformDataList;
  }

  /// Streams waveform data incrementally for specific signals.
  ///
  /// [signalIds] is a list of signal IDs for which to stream data.
  /// [startTime] optionally specifies the starting time for the data stream.
  ///
  /// Returns a [Stream] of [WaveformData] objects that can be used to
  /// incrementally update the waveform display.
  Stream<WaveformData> streamWaveformData({
    required List<String> signalIds,
    int? startTime,
  }) async* {
    // Default implementation: get all data at once and yield
    final waveformDataList = await getWaveformData(
      signalIds: signalIds,
      startTime: startTime,
    );
    for (final waveformData in waveformDataList) {
      yield waveformData;
    }
  }

  /// Helper method to strip waveform data from a module structure.
  ModuleStructure _stripWaveformData(ModuleStructure structure) {
    return ModuleStructure(
      metadata: structure.metadata,
      modules: _stripModulesData(structure.modules),
    );
  }

  /// Helper method to strip waveform data from modules recursively.
  List<Module> _stripModulesData(List<Module> modules) {
    return modules.map((module) {
      return Module(
        name: module.name,
        subModules: _stripModulesData(module.subModules),
        signals: module.signals
            .map((signal) => Signal.fromSignalInfo(signal.toSignalInfo()))
            .toList(),
      );
    }).toList();
  }
}
