// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// signal_info.dart
// Signal metadata without waveform data.

/// Information about a signal in the waveform hierarchy.
class SignalInfo {
  /// Unique identifier for the signal (typically the full hierarchical path).
  final String id;

  /// Short name of the signal.
  final String name;

  /// Full hierarchical path (e.g., "top.counter.clk").
  final String fullPath;

  /// Signal type (e.g., "wire", "reg", "logic").
  final String signalType;

  /// Bit width of the signal.
  final int bitWidth;

  /// ID of the scope (module) containing this signal.
  final int scopeId;

  /// Creates a new [SignalInfo].
  const SignalInfo({
    required this.id,
    required this.name,
    required this.fullPath,
    required this.signalType,
    required this.bitWidth,
    required this.scopeId,
  });

  /// Creates a [SignalInfo] from a JSON map.
  factory SignalInfo.fromJson(Map<String, dynamic> json) {
    return SignalInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      fullPath: json['fullPath'] as String,
      signalType: json['signalType'] as String,
      bitWidth: json['bitWidth'] as int,
      scopeId: json['scopeId'] as int,
    );
  }

  /// Converts this [SignalInfo] to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'fullPath': fullPath,
        'signalType': signalType,
        'bitWidth': bitWidth,
        'scopeId': scopeId,
      };

  @override
  String toString() => 'SignalInfo($fullPath, $signalType[$bitWidth])';
}
