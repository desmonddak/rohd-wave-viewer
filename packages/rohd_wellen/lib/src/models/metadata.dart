// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// metadata.dart
// Waveform file metadata.

import 'wave_format.dart';

/// Metadata about a waveform file.
class WaveformMetadata {
  /// The source file path.
  final String source;

  /// The timescale string (e.g., "1ns", "100ps").
  final String timescale;

  /// The timescale factor (e.g., 1, 10, 100).
  final int timescaleFactor;

  /// The date the waveform was created (if available).
  final String? date;

  /// The version string (if available).
  final String? version;

  /// The file format.
  final WaveFormat format;

  /// Creates a new [WaveformMetadata].
  const WaveformMetadata({
    required this.source,
    required this.timescale,
    required this.timescaleFactor,
    this.date,
    this.version,
    required this.format,
  });

  /// Creates a [WaveformMetadata] from a JSON map.
  factory WaveformMetadata.fromJson(Map<String, dynamic> json) {
    return WaveformMetadata(
      source: json['source'] as String,
      timescale: json['timescale'] as String,
      timescaleFactor: json['timescaleFactor'] as int,
      date: json['date'] as String?,
      version: json['version'] as String?,
      format: WaveFormat.values.firstWhere(
        (f) => f.name == json['format'],
        orElse: () => WaveFormat.vcd,
      ),
    );
  }

  /// Converts this [WaveformMetadata] to a JSON map.
  Map<String, dynamic> toJson() => {
        'source': source,
        'timescale': timescale,
        'timescaleFactor': timescaleFactor,
        if (date != null) 'date': date,
        if (version != null) 'version': version,
        'format': format.name,
      };

  @override
  String toString() => 'WaveformMetadata($source, $timescale, ${format.name})';
}
