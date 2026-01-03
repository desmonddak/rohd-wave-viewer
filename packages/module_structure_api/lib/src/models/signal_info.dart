// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// signal_info.dart
// An entity that describes the structure of a signal without waveform data.
//
// 2024 December 30
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

/// A class that represents the structural information of a signal.
///
/// It contains a name, a type, and an optional unique identifier.
/// This class is used for representing the signal hierarchy without
/// the waveform data, allowing for separation of structure and data.
class SignalInfo {
  /// The unique identifier of the signal.
  ///
  /// This can be used to reference the signal when appending waveform data.
  final String id;

  /// The name of the signal.
  final String name;

  /// The full hierarchical path (e.g., "top.counter.clk").
  ///
  /// This is optional and populated when loading from waveform files.
  final String? fullPath;

  /// The type of the signal (e.g., 'bin', 'hex', 'wire', 'reg', 'logic').
  final String type;

  /// The bit width of the signal, if applicable.
  final int? width;

  /// ID of the scope (module) containing this signal.
  ///
  /// This is optional and populated when loading from waveform files.
  final int? scopeId;

  /// Creates a new instance of [SignalInfo].
  ///
  /// Requires [id], [name], and [type] as parameters.
  /// [width], [fullPath], and [scopeId] are optional.
  SignalInfo({
    required this.id,
    required this.name,
    required this.type,
    this.width,
    this.fullPath,
    this.scopeId,
  });

  /// Converts the [SignalInfo] instance into a JSON Map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        if (width != null) 'width': width,
        if (fullPath != null) 'fullPath': fullPath,
        if (scopeId != null) 'scopeId': scopeId,
      };

  /// Creates a new instance of [SignalInfo] from a JSON Map.
  factory SignalInfo.fromJson(Map<String, dynamic> json) {
    return SignalInfo(
      id: json['id'] ?? json['name'], // Fall back to name if id not provided
      name: json['name'],
      type: json['type'],
      width: json['width'],
      fullPath: json['fullPath'],
      scopeId: json['scopeId'],
    );
  }

  factory SignalInfo.empty() {
    return SignalInfo(id: '', name: '', type: '');
  }

  @override
  String toString() => fullPath ?? '$name ($type)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignalInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          type == other.type;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ type.hashCode;
}
