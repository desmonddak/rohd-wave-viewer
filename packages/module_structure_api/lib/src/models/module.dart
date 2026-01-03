// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// module.dart
// An entity that describes a module and its submodules and signals.
//
// 2024 January 29
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:module_structure_api/src/models/signal.dart';

/// A class that represents a module.
///
/// It contains a name, a list of submodules, and a list of signals.
class Module {
  /// The name of the module.
  String name;

  /// The full hierarchical path (e.g., "top.counter").
  ///
  /// This is optional and populated when loading from waveform files.
  String? fullPath;

  /// The type of scope (e.g., "module", "task", "function").
  ///
  /// This is optional and populated when loading from waveform files.
  String? scopeType;

  /// The list of submodules in the module.
  List<Module> subModules;

  /// The list of signals in the module.
  List<Signal> signals;

  /// Creates a new instance of [Module].
  ///
  /// Requires [name], [subModules], and [signals] as parameters.
  /// [fullPath] and [scopeType] are optional.
  Module({
    required this.name,
    required this.subModules,
    required this.signals,
    this.fullPath,
    this.scopeType,
  });

  /// Converts the [Module] instance into a JSON Map.
  ///
  /// The [Module] and [Signal] instances are also converted into their
  /// respective JSON representation.
  Map<String, dynamic> toJson() => {
        'name': name,
        if (fullPath != null) 'fullPath': fullPath,
        if (scopeType != null) 'scopeType': scopeType,
        'subModules': subModules.map((e) => e.toJson()).toList(),
        'signals': signals.map((e) => e.toJson()).toList(),
      };

  /// Creates a new instance of [Module] from a JSON Map.
  ///
  /// The [Module] and [Signal] instances are created from their respective
  /// JSON representation.
  factory Module.fromJson(Map<String, dynamic> json) {
    var subModulesJson = json['subModules'] as List;
    var signalsJson = json['signals'] as List;

    return Module(
      name: json['name'],
      fullPath: json['fullPath'],
      scopeType: json['scopeType'],
      subModules: subModulesJson.map((e) => Module.fromJson(e)).toList(),
      signals: signalsJson.map((e) => Signal.fromJson(e)).toList(),
    );
  }

  /// Recursively get all signals in this module and its children.
  List<Signal> get allSignals {
    final result = <Signal>[];
    result.addAll(signals);
    for (final child in subModules) {
      result.addAll(child.allSignals);
    }
    return result;
  }

  /// Recursively get all signal IDs in this module and its children.
  List<String> get allSignalIds => allSignals.map((s) => s.id).toList();

  @override
  String toString() =>
      'Module($name, ${signals.length} signals, ${subModules.length} sub-modules)';
}
