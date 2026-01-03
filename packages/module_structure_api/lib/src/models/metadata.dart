// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// metadata.dart
// An entity that describes the metadata of a module structure.
//
// 2024 January 29
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'wave_format.dart';

/// A class that represents the metadata of a module structure.
///
/// It contains source, timescale, date, and time range information.
class MetaData {
  /// The source of the metadata.
  String source;

  /// The timescale of the metadata (e.g., "1ns", "100ps").
  String timescale;

  /// The timescale factor (e.g., 1, 10, 100).
  ///
  /// This is optional and populated when loading from waveform files.
  int? timescaleFactor;

  /// The date of the metadata.
  String date;

  /// The version string (if available).
  ///
  /// This is optional and populated when loading from waveform files.
  String? version;

  /// The file format.
  ///
  /// This is optional and populated when loading from waveform files.
  WaveFormat? format;

  /// The start time of the waveform in timescale units.
  int startTime;

  /// The end time of the waveform in timescale units.
  int endTime;

  /// Creates a new instance of [MetaData].
  ///
  /// Requires [source], [timescale], and [date] as parameters.
  /// [startTime] and [endTime] default to 0 if not provided.
  /// [timescaleFactor], [version], and [format] are optional.
  MetaData({
    required this.source,
    required this.timescale,
    required this.date,
    this.startTime = 0,
    this.endTime = 0,
    this.timescaleFactor,
    this.version,
    this.format,
  });

  /// Converts the [MetaData] instance into a JSON Map.
  Map<String, dynamic> toJson() => {
        'source': source,
        'timescale': timescale,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        if (timescaleFactor != null) 'timescaleFactor': timescaleFactor,
        if (version != null) 'version': version,
        if (format != null) 'format': format!.name,
      };

  /// Creates a new instance of [MetaData] from a JSON Map.
  factory MetaData.fromJson(Map<String, dynamic> json) {
    return MetaData(
      source: json['source'],
      timescale: json['timescale'],
      date: json['date'],
      startTime: json['startTime'] ?? 0,
      endTime: json['endTime'] ?? 0,
      timescaleFactor: json['timescaleFactor'],
      version: json['version'],
      format:
          json['format'] != null ? WaveFormat.fromString(json['format']) : null,
    );
  }

  factory MetaData.empty() {
    return MetaData(
        source: '', timescale: '', date: '', startTime: 0, endTime: 0);
  }
}
