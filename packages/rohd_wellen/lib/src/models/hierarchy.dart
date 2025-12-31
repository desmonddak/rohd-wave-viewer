// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// hierarchy.dart
// Signal hierarchy (modules and signals).

import 'metadata.dart';
import 'signal_info.dart';

/// A module node in the signal hierarchy.
///
/// This represents a scope (module, function, task, etc.) and its contents.
class ModuleNode {
  /// The name of this module.
  final String name;

  /// The full hierarchical path.
  final String fullPath;

  /// The type of scope (e.g., "module", "task", "function").
  final String scopeType;

  /// Signals directly contained in this module.
  final List<SignalInfo> signals;

  /// Child modules (sub-modules).
  final List<ModuleNode> subModules;

  /// Creates a new [ModuleNode].
  const ModuleNode({
    required this.name,
    required this.fullPath,
    required this.scopeType,
    required this.signals,
    required this.subModules,
  });

  /// Creates a [ModuleNode] from a JSON map.
  factory ModuleNode.fromJson(Map<String, dynamic> json) {
    return ModuleNode(
      name: json['name'] as String,
      fullPath: json['fullPath'] as String,
      scopeType: json['scopeType'] as String,
      signals: (json['signals'] as List)
          .map((e) => SignalInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      subModules: (json['subModules'] as List)
          .map((e) => ModuleNode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Converts this [ModuleNode] to a JSON map.
  Map<String, dynamic> toJson() => {
        'name': name,
        'fullPath': fullPath,
        'scopeType': scopeType,
        'signals': signals.map((e) => e.toJson()).toList(),
        'subModules': subModules.map((e) => e.toJson()).toList(),
      };

  /// Recursively get all signals in this module and its children.
  List<SignalInfo> get allSignals {
    final result = <SignalInfo>[];
    result.addAll(signals);
    for (final child in subModules) {
      result.addAll(child.allSignals);
    }
    return result;
  }

  /// Recursively get all signal IDs in this module and its children.
  List<String> get allSignalIds => allSignals.map((s) => s.id).toList();

  @override
  String toString() => 'ModuleNode($fullPath, ${signals.length} signals, '
      '${subModules.length} sub-modules)';
}

/// Complete waveform structure including metadata and hierarchy.
class WaveformStructure {
  /// Metadata about the waveform.
  final WaveformMetadata metadata;

  /// Root modules (top-level scopes).
  final List<ModuleNode> modules;

  /// All signal IDs in the waveform.
  final List<String> allSignalIds;

  /// Creates a new [WaveformStructure].
  const WaveformStructure({
    required this.metadata,
    required this.modules,
    required this.allSignalIds,
  });

  /// Creates a [WaveformStructure] from a JSON map.
  factory WaveformStructure.fromJson(Map<String, dynamic> json) {
    return WaveformStructure(
      metadata:
          WaveformMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      modules: (json['modules'] as List)
          .map((e) => ModuleNode.fromJson(e as Map<String, dynamic>))
          .toList(),
      allSignalIds:
          (json['allSignalIds'] as List).map((e) => e as String).toList(),
    );
  }

  /// Converts this [WaveformStructure] to a JSON map.
  Map<String, dynamic> toJson() => {
        'metadata': metadata.toJson(),
        'modules': modules.map((e) => e.toJson()).toList(),
        'allSignalIds': allSignalIds,
      };

  @override
  String toString() => 'WaveformStructure(${modules.length} modules, '
      '${allSignalIds.length} signals)';
}

/// A scope (module) in the signal hierarchy.
///
/// @deprecated Use [ModuleNode] instead.
@Deprecated('Use ModuleNode instead')
typedef Scope = ModuleNode;

/// The complete signal hierarchy of a waveform.
class Hierarchy {
  /// Root scopes (top-level modules).
  final List<ModuleNode> roots;

  /// Creates a new [Hierarchy].
  const Hierarchy({required this.roots});

  /// Creates an empty [Hierarchy].
  const Hierarchy.empty() : roots = const [];

  /// Creates a [Hierarchy] from a JSON map.
  factory Hierarchy.fromJson(Map<String, dynamic> json) {
    return Hierarchy(
      roots: (json['roots'] as List)
          .map((e) => ModuleNode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Converts this [Hierarchy] to a JSON map.
  Map<String, dynamic> toJson() => {
        'roots': roots.map((e) => e.toJson()).toList(),
      };

  /// Get all signals in the hierarchy.
  List<SignalInfo> get allSignals {
    final result = <SignalInfo>[];
    for (final root in roots) {
      result.addAll(root.allSignals);
    }
    return result;
  }

  /// Get all signal IDs in the hierarchy.
  List<String> get allSignalIds => allSignals.map((s) => s.id).toList();

  /// Returns true if the hierarchy is empty.
  bool get isEmpty => roots.isEmpty;

  /// Returns true if the hierarchy is not empty.
  bool get isNotEmpty => roots.isNotEmpty;

  @override
  String toString() => 'Hierarchy(${roots.length} roots, '
      '${allSignals.length} total signals)';
}
