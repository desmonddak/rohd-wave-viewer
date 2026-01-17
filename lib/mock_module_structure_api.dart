// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// mock_module_structure_api.dart
// A mock implementation of the ModuleStructureApi class.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'dart:async';
import 'dart:convert';
import 'package:module_structure_api/module_structure_api.dart';

class MockModuleStructureApi extends ModuleStructureApi {
  /// Returns the module structure without waveform data.
  ///
  /// To get waveform data, use [getWaveformData] or [streamWaveformData].
  @override
  Future<ModuleStructure> getModuleStructure() {
    String jsonString = '''
  {
    "metadata": {
      "source": "Source1",
      "timescale": "1ns",
      "date": "2022-01-01"
    },
    "modules": [
      {
        "name": "Counter",
        "subModules": [
          {
            "name": "counter_sub_module",
            "subModules": [],
            "signals": [
              {
                "id": "counter_sub_module.SubSignal1",
                "name": "SubSignal1",
                "type": "hex",
                "data": []
              }
            ]
          }
        ],
        "signals": [
          {
            "id": "Counter.Signal1",
            "name": "Signal1",
            "type": "bin",
            "data": []
          },
          {
            "id": "Counter.Signal2",
            "name": "Signal2",
            "type": "bin",
            "data": []
          },
          {
            "id": "Counter.Signal3",
            "name": "Signal3",
            "type": "hex",
            "data": []
          },
          {
            "id": "Counter.Signal4",
            "name": "Signal4",
            "type": "bin",
            "data": []
          }
        ]
      }
    ]
  }
  ''';

    // Parse the JSON string into a Map.
    Map<String, dynamic> jsonMap = jsonDecode(jsonString);

    // Use the fromJson factory constructor to create a ModuleStructure object.
    return Future<ModuleStructure>.value(ModuleStructure.fromJson(jsonMap));
  }

  /// Mock waveform data storage.
  /// Format: signalId -> [[time, value], [time, value], ...]
  static final Map<String, List<List<dynamic>>> _waveformData = {
    'counter_sub_module.SubSignal1': [
      [1, '1'],
      [2, '0'],
      [3, 'ABCD102'],
      [4, '1'],
      [5, '1'],
    ],
    'Counter.Signal1': [
      [1, 'XXXXX'],
      [5, '1'],
      [12, 'ZZZZZ'],
      [18, '1'],
    ],
    'Counter.Signal2': [
      [1, '1'],
      [2, '0'],
      [4, '1'],
      [9, '1'],
      [10, '0'],
      [11, '1'],
      [12, '0'],
      [13, '1'],
    ],
    'Counter.Signal3': [
      [5, 'ZZZ'],
      [7, '1'],
      [9, 'XXX'],
      [14, '1'],
      [17, 'ZZ'],
    ],
    'Counter.Signal4': [
      [1, 'X'],
      [4, '1'],
      [7, 'Z'],
      [10, '0'],
      [13, 'X'],
      [16, '1'],
      [19, 'Z'],
    ],
  };

  /// Converts a [time, value] list to a [Data] object.
  static Data _toData(List<dynamic> pair) => Data(
        time: pair[0] as int,
        value: pair[1] as String,
      );

  /// Retrieves waveform data for specific signals.
  @override
  Future<List<WaveformData>> getWaveformData({
    required List<String> signalIds,
    int? startTime,
    int? endTime,
  }) async {
    final result = <WaveformData>[];

    for (final signalId in signalIds) {
      final dataList = _waveformData[signalId];
      if (dataList != null) {
        var filteredData = dataList.map(_toData).toList();

        if (startTime != null || endTime != null) {
          filteredData = filteredData.where((d) {
            if (startTime != null && d.time < startTime) return false;
            if (endTime != null && d.time > endTime) return false;
            return true;
          }).toList();
        }

        result.add(WaveformData(signalId: signalId, data: filteredData));
      }
    }

    return result;
  }

  /// Streams waveform data incrementally for specific signals.
  ///
  /// This demonstrates how data can be streamed in chunks for
  /// incremental loading.
  @override
  Stream<WaveformData> streamWaveformData({
    required List<String> signalIds,
    int? startTime,
  }) async* {
    for (final signalId in signalIds) {
      final dataList = _waveformData[signalId];
      if (dataList != null) {
        var allData = dataList.map(_toData).toList();

        if (startTime != null) {
          allData = allData.where((d) => d.time >= startTime).toList();
        }

        // Simulate streaming by yielding data in chunks
        const chunkSize = 2;
        for (var i = 0; i < allData.length; i += chunkSize) {
          final end =
              (i + chunkSize < allData.length) ? i + chunkSize : allData.length;
          final chunk = allData.sublist(i, end);

          yield WaveformData(signalId: signalId, data: chunk);

          // Simulate network delay
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }
    }
  }
}
