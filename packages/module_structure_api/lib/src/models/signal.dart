// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// signal.dart
// An entity that describes a signal and its data.
//
// 2024 January 29
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:module_structure_api/module_structure_api.dart';
import 'package:module_structure_api/src/models/data.dart';
import 'package:module_structure_api/src/models/signal_info.dart';
import 'package:module_structure_api/src/models/waveform_data.dart';

/// A class that represents a signal.
///
/// It contains a name, a type, and a list of data.
/// This class combines both the signal structure and waveform data.
class Signal {
  /// The unique identifier of the signal.
  String id;

  /// The name of the signal.
  String name;

  /// The type of the signal.
  String type;

  /// The bit width of the signal, if applicable.
  int? width;

  /// The list of data in the signal.
  List<Data> data;

  /// Creates a new instance of [Signal].
  ///
  /// Requires [name], [type], and [data] as parameters.
  /// [id] defaults to [name] if not provided.
  /// [width] is optional.
  Signal({
    String? id,
    required this.name,
    required this.type,
    required this.data,
    this.width,
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
        'data': data.map((e) => e.toJson()).toList(),
      };

  /// Converts the [Signal] to a [SignalInfo] for structure-only representation.
  SignalInfo toSignalInfo() => SignalInfo(
        id: id,
        name: name,
        type: type,
        width: width,
      );

  /// Creates a [Signal] from a [SignalInfo] with empty data.
  factory Signal.fromSignalInfo(SignalInfo info) {
    return Signal(
      id: info.id,
      name: info.name,
      type: info.type,
      width: info.width,
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
}
