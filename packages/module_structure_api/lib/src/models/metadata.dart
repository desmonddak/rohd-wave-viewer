// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// metadata.dart
// An entity that describes the metadata of a module structure.
//
// 2024 January 29
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

/// A class that represents the metadata of a module structure.
///
/// It contains source, timescale, date, and time range information.
class MetaData {
  /// The source of the metadata.
  String source;

  /// The timescale of the metadata.
  String timescale;

  /// The date of the metadata.
  String date;

  /// The start time of the waveform in timescale units.
  int startTime;

  /// The end time of the waveform in timescale units.
  int endTime;

  /// Creates a new instance of [MetaData].
  ///
  /// Requires [source], [timescale], and [date] as parameters.
  /// [startTime] and [endTime] default to 0 if not provided.
  MetaData({
    required this.source,
    required this.timescale,
    required this.date,
    this.startTime = 0,
    this.endTime = 0,
  });

  /// Converts the [MetaData] instance into a JSON Map.
  Map<String, dynamic> toJson() => {
        'source': source,
        'timescale': timescale,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
      };

  /// Creates a new instance of [MetaData] from a JSON Map.
  factory MetaData.fromJson(Map<String, dynamic> json) {
    return MetaData(
      source: json['source'],
      timescale: json['timescale'],
      date: json['date'],
      startTime: json['startTime'] ?? 0,
      endTime: json['endTime'] ?? 0,
    );
  }

  factory MetaData.empty() {
    return MetaData(
        source: '', timescale: '', date: '', startTime: 0, endTime: 0);
  }
}
