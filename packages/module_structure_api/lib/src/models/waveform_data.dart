// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// waveform_data.dart
// An entity that represents waveform data for a signal.
//
// 2024 December 30
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:module_structure_api/src/models/data.dart';

/// A class that represents waveform data for a specific signal.
///
/// This class is used to transfer waveform data separately from the
/// signal structure, enabling incremental data loading and updates.
class WaveformData {
  /// The unique identifier of the signal this waveform data belongs to.
  final String signalId;

  /// The list of data points in the waveform.
  final List<Data> data;

  /// Creates a new instance of [WaveformData].
  ///
  /// Requires [signalId] and [data] as parameters.
  WaveformData({
    required this.signalId,
    required this.data,
  });

  /// Converts the [WaveformData] instance into a JSON Map.
  Map<String, dynamic> toJson() => {
        'signalId': signalId,
        'data': data.map((e) => e.toJson()).toList(),
      };

  /// Creates a new instance of [WaveformData] from a JSON Map.
  factory WaveformData.fromJson(Map<String, dynamic> json) {
    return WaveformData(
      signalId: json['signalId'],
      data: (json['data'] as List).map((e) => Data.fromJson(e)).toList(),
    );
  }

  factory WaveformData.empty(String signalId) {
    return WaveformData(signalId: signalId, data: []);
  }

  /// Returns the number of data points in the waveform.
  int get length => data.length;

  /// Returns true if the waveform has no data points.
  bool get isEmpty => data.isEmpty;

  /// Returns true if the waveform has data points.
  bool get isNotEmpty => data.isNotEmpty;

  /// Returns the time of the first data point, or null if empty.
  int? get startTime => data.isEmpty ? null : data.first.time;

  /// Returns the time of the last data point, or null if empty.
  int? get endTime => data.isEmpty ? null : data.last.time;

  @override
  String toString() => 'WaveformData($signalId, ${data.length} points)';
}
