// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// signal_data.dart
// Waveform data for signals.

/// A single data point (value change) in a waveform.
class DataPoint {
  /// The simulation time of this value change.
  final int time;

  /// The value as a string (binary, hex, or other representation).
  final String value;

  /// Creates a new [DataPoint].
  const DataPoint({
    required this.time,
    required this.value,
  });

  /// Creates a [DataPoint] from a JSON map.
  factory DataPoint.fromJson(Map<String, dynamic> json) {
    return DataPoint(
      time: json['time'] as int,
      value: json['value'] as String,
    );
  }

  /// Converts this [DataPoint] to a JSON map.
  Map<String, dynamic> toJson() => {
        'time': time,
        'value': value,
      };

  @override
  String toString() => '@$time: $value';
}

/// Alias for backward compatibility.
typedef ValueChange = DataPoint;

/// Waveform data for a single signal.
class SignalData {
  /// The signal ID this data belongs to.
  final String signalId;

  /// The list of data points (value changes) over time.
  final List<DataPoint> data;

  /// Creates a new [SignalData].
  const SignalData({
    required this.signalId,
    required this.data,
  });

  /// Creates a [SignalData] with `changes` parameter for backward compatibility.
  factory SignalData.withChanges({
    required String signalId,
    required List<DataPoint> changes,
  }) {
    return SignalData(signalId: signalId, data: changes);
  }

  /// Creates a [SignalData] from a JSON map.
  factory SignalData.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] ?? json['changes'];
    return SignalData(
      signalId: json['signalId'] as String,
      data: (dataList as List)
          .map((e) => DataPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Converts this [SignalData] to a JSON map.
  Map<String, dynamic> toJson() => {
        'signalId': signalId,
        'data': data.map((e) => e.toJson()).toList(),
      };

  /// Alias for [data] for backward compatibility.
  List<DataPoint> get changes => data;

  /// Returns the number of data points.
  int get length => data.length;

  /// Returns true if there are no data points.
  bool get isEmpty => data.isEmpty;

  /// Returns true if there are data points.
  bool get isNotEmpty => data.isNotEmpty;

  /// Returns the first time, or null if empty.
  int? get startTime => isEmpty ? null : data.first.time;

  /// Returns the last time, or null if empty.
  int? get endTime => isEmpty ? null : data.last.time;

  /// Get the value at a specific time using binary search.
  ///
  /// Returns the value that was active at [time], or null if no value
  /// was set before [time].
  String? getValueAt(int time) {
    if (isEmpty) return null;

    int low = 0;
    int high = data.length - 1;
    DataPoint? result;

    while (low <= high) {
      final mid = low + (high - low) ~/ 2;
      final point = data[mid];

      if (point.time == time) {
        return point.value;
      } else if (point.time < time) {
        result = point;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return result?.value;
  }

  @override
  String toString() => 'SignalData($signalId, ${data.length} data points)';
}
