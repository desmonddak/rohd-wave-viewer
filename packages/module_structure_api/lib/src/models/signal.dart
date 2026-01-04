// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// signal.dart
// An entity that describes a signal and its data.
//
// 2024 January 29
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:module_structure_api/module_structure_api.dart';

/// A class that represents a signal.
///
/// It contains a name, a type, and a list of data.
/// This class combines both the signal structure and waveform data.
class Signal {
  /// The unique identifier of the signal.
  String id;

  /// The name of the signal.
  String name;

  /// The full hierarchical path (e.g., "top.counter.clk").
  ///
  /// This is optional and populated when loading from waveform files.
  String? fullPath;

  /// The type of the signal.
  String type;

  /// The bit width of the signal, if applicable.
  int? width;

  /// ID of the scope (module) containing this signal.
  ///
  /// This is optional and populated when loading from waveform files.
  int? scopeId;

  /// The list of data in the signal.
  List<Data> data;

  /// Creates a new instance of [Signal].
  ///
  /// Requires [name], [type], and [data] as parameters.
  /// [id] defaults to [name] if not provided.
  /// [width], [fullPath], and [scopeId] are optional.
  Signal({
    String? id,
    required this.name,
    required this.type,
    required this.data,
    this.width,
    this.fullPath,
    this.scopeId,
  }) : id = id ?? name;

  /// Converts the [Signal] instance into a JSON Map.
  ///
  /// The [Data] instances are also converted into their
  /// respective JSON representation.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        if (width != null) 'width': width,
        if (fullPath != null) 'fullPath': fullPath,
        if (scopeId != null) 'scopeId': scopeId,
        'data': data.map((e) => e.toJson()).toList(),
      };

  /// Converts the [Signal] to a [SignalInfo] for structure-only representation.
  SignalInfo toSignalInfo() => SignalInfo(
        id: id,
        name: name,
        type: type,
        width: width,
        fullPath: fullPath,
        scopeId: scopeId,
      );

  /// Creates a [Signal] from a [SignalInfo] with empty data.
  factory Signal.fromSignalInfo(SignalInfo info) {
    return Signal(
      id: info.id,
      name: info.name,
      type: info.type,
      width: info.width,
      fullPath: info.fullPath,
      scopeId: info.scopeId,
      data: [],
    );
  }

  /// Creates a new instance of [Signal] from a JSON Map.
  ///
  /// The [Data] instances are created from their respective
  /// JSON representation.
  factory Signal.fromJson(Map<String, dynamic> json) {
    return Signal(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      width: json['width'],
      fullPath: json['fullPath'],
      scopeId: json['scopeId'],
      data:
          (json['data'] as List?)?.map((e) => Data.fromJson(e)).toList() ?? [],
    );
  }

  factory Signal.empty() {
    return Signal(name: '', type: '', data: []);
  }

  /// Appends waveform data to this signal.
  ///
  /// The new data points will be added to the end of the existing data list.
  /// If [sortByTime] is true, the data will be sorted by time after appending.
  void appendData(List<Data> newData, {bool sortByTime = false}) {
    data.addAll(newData);
    if (sortByTime) {
      data.sort((a, b) => a.time.compareTo(b.time));
    }
  }

  /// Appends waveform data from a [WaveformData] object.
  ///
  /// The new data points will be added to the end of the existing data list.
  /// If [sortByTime] is true, the data will be sorted by time after appending.
  void appendWaveformData(WaveformData waveformData,
      {bool sortByTime = false}) {
    appendData(waveformData.data, sortByTime: sortByTime);
  }

  /// Clears all waveform data from this signal.
  void clearData() {
    data.clear();
  }

  @override
  String toString() {
    return '$name-$type';
  }

  String getValueByTime(int time) {
    int low = 0;
    int high = data.length - 1;
    Data? closestBefore;

    while (low <= high) {
      int mid = low + (high - low) ~/ 2;
      Data midData = data[mid];

      if (midData.time == time) {
        return midData.value; // Exact match found, return immediately
      } else if (midData.time < time) {
        closestBefore =
            midData; // Potential closest match, keep searching right
        low = mid + 1;
      } else {
        high = mid - 1; // Search left
      }
    }

    // After the loop, check if we found a closest match
    if (closestBefore != null) {
      return closestBefore.value;
    } else {
      // This will be reached if the list is empty or no suitable value was found
      // TODO: this should be floating instead?
      return data.first.value;
    }
  }

  /// Finds the index of the data point at or after the given time using binary search.
  /// Returns -1 if no data point is at or after the given time.
  /// O(log n) complexity, safe for large waveforms.
  int getNextDataPointIndexAfter(int time) {
    if (data.isEmpty) return -1;

    int low = 0;
    int high = data.length - 1;
    int resultIndex = -1;

    while (low <= high) {
      int mid = low + (high - low) ~/ 2;
      Data midData = data[mid];

      if (midData.time >= time) {
        resultIndex = mid;
        high = mid - 1; // Continue searching left for the first match
      } else {
        low = mid + 1; // Search right
      }
    }

    return resultIndex;
  }

  /// Finds the index of the data point at or before the given time using binary search.
  /// Returns -1 if no data point is at or before the given time.
  /// O(log n) complexity, safe for large waveforms.
  int getPreviousDataPointIndexBefore(int time) {
    if (data.isEmpty) return -1;

    int low = 0;
    int high = data.length - 1;
    int resultIndex = -1;

    while (low <= high) {
      int mid = low + (high - low) ~/ 2;
      Data midData = data[mid];

      if (midData.time <= time) {
        resultIndex = mid;
        low = mid + 1; // Continue searching right for the last match
      } else {
        high = mid - 1; // Search left
      }
    }

    return resultIndex;
  }

  /// Gets the next data point index from the current time.
  /// If there is a data point at exactly the current time, returns the next one.
  /// Returns -1 if there is no next data point.
  int getNextDataPointIndex(int currentTime) {
    int idx = getNextDataPointIndexAfter(currentTime);
    if (idx != -1 && data[idx].time == currentTime && idx + 1 < data.length) {
      return idx + 1;
    }
    return idx != -1 && idx < data.length ? idx : -1;
  }

  /// Gets the previous data point index from the current time.
  /// If there is a data point at exactly the current time, returns the previous one.
  /// Returns -1 if there is no previous data point.
  int getPreviousDataPointIndex(int currentTime) {
    int idx = getPreviousDataPointIndexBefore(currentTime);
    if (idx != -1 && data[idx].time == currentTime) {
      // If we're at a data point, return the previous one (or -1 if there isn't one)
      return idx > 0 ? idx - 1 : -1;
    }
    return idx >= 0 ? idx : -1;
  }
}
