// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// rohd_module_panel.dart
// The ROHD module panel.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:rohd_wave_viewer/src/const/locales.dart';
import 'package:rohd_wave_viewer/src/modules/rohd_module/bloc/rohd_module_bloc.dart';
import 'package:module_structure_api/module_structure_api.dart';
import 'package:rohd_wave_viewer/src/modules/signal/bloc/signal_bloc.dart';

class RohdModulePanel extends StatefulWidget {
  const RohdModulePanel({super.key});

  @override
  State<RohdModulePanel> createState() => _RohdModulePanelState();
}

class _RohdModulePanelState extends State<RohdModulePanel> {
  bool _initAttempted = false;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    // Try to initialize the bloc if waveform is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryInitializeBloc();
    });
  }

  void _tryInitializeBloc() {
    if (_initAttempted) return;
    
    final bloc = context.read<RohdModuleBloc>();
    // Only initialize if we're still in Loading state (not yet initialized)
    if (bloc.state is Loading) {
      debugPrint('[RohdModulePanel] Attempting to initialize bloc');
      _initAttempted = true;
      bloc.add(RohdModuleInit());
    }
  }

  void _retryInitializeBloc() {
    _retryCount++;
    debugPrint('[RohdModulePanel] Retrying bloc initialization (attempt $_retryCount)');
    final bloc = context.read<RohdModuleBloc>();
    bloc.add(RohdModuleInit());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RohdModuleBloc, RohdModuleState>(
      listener: (context, state) {
        // If initialization failed, schedule a retry
        if (state is Error && _retryCount < 3) {
          debugPrint('[RohdModulePanel] Init failed, scheduling retry');
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _retryInitializeBloc();
            }
          });
        }
      },
      child: BlocBuilder<RohdModuleBloc, RohdModuleState>(
        builder: (context, state) {
          if (state is Loading) {
            // Try initializing if not attempted yet
            if (!_initAttempted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _tryInitializeBloc();
              });
            }
            return const Text('');
          } else if (state is Rendered) {
            return ModuleTree(moduleStructure: state.moduleStructure);
          } else if (state is Error) {
            return const Text(bugReport);
          } else if (state is ModuleSelected) {
            // Trigger the SignalBloc
            context.read<SignalBloc>().add(SignalUpdateEvent(state.singleModule));
            return ModuleTree(moduleStructure: state.moduleStructure);
          } else {
            return Container(); // Add a default return for safety
          }
        },
      ),
    );
  }
}

class ModuleTree extends StatelessWidget {
  final ModuleStructure moduleStructure;

  const ModuleTree({super.key, required this.moduleStructure});

  @override
  Widget build(BuildContext context) {
    final bodyHeight = MediaQuery.of(context).size.height / 2 - 80;
    final treeController = TreeController<Module>(
      roots: moduleStructure.modules,
      childrenProvider: (Module module) => module.subModules,
    );

    // TreeView have unbounded height
    return SizedBox(
      height: bodyHeight,
      child: TreeView<Module>(
        treeController: treeController,
        nodeBuilder: (BuildContext context, TreeEntry<Module> entry) {
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                context
                    .read<RohdModuleBloc>()
                    .add(RohdModuleSelect(moduleStructure, entry.node));
              },
              child: TreeIndentation(
                entry: entry,
                child: Row(
                  children: [
                    ExpandIcon(
                      key: GlobalObjectKey(entry.node),
                      isExpanded: entry.isExpanded,
                      onPressed: (_) =>
                          treeController.toggleExpansion(entry.node),
                    ),
                    Flexible(
                      child: Text(entry.node.name),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
