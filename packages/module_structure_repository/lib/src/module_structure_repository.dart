// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// module_structure_repository.dart
// Domain layer that manages the retrieval of module structures.
//
// 2024 January 29
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:module_structure_api/module_structure_api.dart';

/// A class that manages the retrieval of module structures.
///
/// It uses an instance of [ModuleStructureApi] to retrieve the data.
class ModuleStructureRepository {
  Module? _selectedModule;

  Module? get selectedModule => _selectedModule;

  /// The [ModuleStructureApi] instance used to retrieve the data.
  final ModuleStructureApi _moduleStructureApi;

  /// A cache of signals by their IDs for quick lookup when appending data.
  final Map<String, Signal> _signalCache = {};

  /// Creates a new instance of [ModuleStructureRepository].
  ///
  /// Requires [moduleStructureApi] as a parameter.
  ModuleStructureRepository({
    required ModuleStructureApi moduleStructureApi,
  }) : _moduleStructureApi = moduleStructureApi;

  void selectModule(Module module) {
    _selectedModule = module;
  }

  /// Retrieves the complete module structure including waveform data.
  ///
  /// Returns a [Future] that completes with the [ModuleStructure].
  Future<ModuleStructure> getModuleStructure() async {
    final structure = await _moduleStructureApi.getModuleStructure();
    _buildSignalCache(structure.modules);
    return structure;
  }

  /// Retrieves the module structure without waveform data.
  ///
  /// This is useful for initial loading of the signal hierarchy,
  /// allowing waveform data to be loaded incrementally afterwards.
  ///
  /// Returns a [Future] that completes with the [ModuleStructure].
  Future<ModuleStructure> getModuleStructureOnly() async {
    final structure = await _moduleStructureApi.getModuleStructureOnly();
    _buildSignalCache(structure.modules);
    return structure;
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
  }) =>
      _moduleStructureApi.getWaveformData(
        signalIds: signalIds,
        startTime: startTime,
        endTime: endTime,
      );

  /// Loads waveform data for specific signals and appends it to the cached signals.
  ///
  /// [signalIds] is a list of signal IDs for which to load data.
  /// [startTime] and [endTime] optionally specify a time range for the data.
  /// [sortByTime] if true, sorts the data by time after appending.
  ///
  /// Returns a [Future] that completes with the list of [WaveformData] loaded.
  Future<List<WaveformData>> loadAndAppendWaveformData({
    required List<String> signalIds,
    int? startTime,
    int? endTime,
    bool sortByTime = false,
  }) async {
    final waveformDataList = await getWaveformData(
      signalIds: signalIds,
      startTime: startTime,
      endTime: endTime,
    );

    for (final waveformData in waveformDataList) {
      final signal = _signalCache[waveformData.signalId];
      if (signal != null) {
        signal.appendWaveformData(waveformData, sortByTime: sortByTime);
      }
    }

    return waveformDataList;
  }

  /// Streams waveform data incrementally for specific signals.
  ///
  /// [signalIds] is a list of signal IDs for which to stream data.
  /// [startTime] optionally specifies the starting time for the data stream.
  /// [appendToSignals] if true, automatically appends streamed data to cached signals.
  ///
  /// Returns a [Stream] of [WaveformData] objects.
  Stream<WaveformData> streamWaveformData({
    required List<String> signalIds,
    int? startTime,
    bool appendToSignals = true,
  }) async* {
    await for (final waveformData in _moduleStructureApi.streamWaveformData(
      signalIds: signalIds,
      startTime: startTime,
    )) {
      if (appendToSignals) {
        final signal = _signalCache[waveformData.signalId];
        signal?.appendWaveformData(waveformData);
      }
      yield waveformData;
    }
  }

  /// Appends waveform data to a specific signal.
  ///
  /// [signalId] is the ID of the signal to append data to.
  /// [data] is the list of data points to append.
  /// [sortByTime] if true, sorts the data by time after appending.
  ///
  /// Returns true if the signal was found and data was appended.
  bool appendDataToSignal(
    String signalId,
    List<Data> data, {
    bool sortByTime = false,
  }) {
    final signal = _signalCache[signalId];
    if (signal != null) {
      signal.appendData(data, sortByTime: sortByTime);
      return true;
    }
    return false;
  }

  /// Clears waveform data from a specific signal.
  ///
  /// [signalId] is the ID of the signal to clear data from.
  ///
  /// Returns true if the signal was found and data was cleared.
  bool clearSignalData(String signalId) {
    final signal = _signalCache[signalId];
    if (signal != null) {
      signal.clearData();
      return true;
    }
    return false;
  }

  /// Clears all waveform data from all cached signals.
  void clearAllSignalData() {
    for (final signal in _signalCache.values) {
      signal.clearData();
    }
  }

  /// Gets a signal by its ID from the cache.
  Signal? getSignalById(String signalId) => _signalCache[signalId];

  /// Gets all cached signal IDs.
  List<String> get cachedSignalIds => _signalCache.keys.toList();

  List<Signal> getSignalsBySelectedModule(Module module) => module.signals;

  /// Builds the signal cache from the module structure.
  void _buildSignalCache(List<Module> modules) {
    for (final module in modules) {
      for (final signal in module.signals) {
        _signalCache[signal.id] = signal;
      }
      _buildSignalCache(module.subModules);
    }
  }
}
