// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// selected_signal_panel.dart
// The selected signals panel.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rohd_wave_viewer/src/const/locales.dart';
import 'package:rohd_wave_viewer/src/modules/shared/widgets/signal_tab_container.dart';
import 'package:rohd_wave_viewer/src/modules/signal/bloc/signal_bloc.dart';
import 'package:rohd_wave_viewer/src/modules/shared/widgets/panel_header.dart';

class SelectedSignalsPanel extends StatelessWidget {
  final ScrollController? scrollController;

  const SelectedSignalsPanel({super.key, this.scrollController});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SignalBloc, SignalState>(builder: (content, state) {
      return Column(
        children: [
          const PanelHeader(headerText: selectedSignalsPanelTitle),
          Expanded(
            child: Listener(
              onPointerSignal: (event) {
                // Block pointer signal events (mouse wheel)
              },
              child: switch (state) {
                SignalLoading() => const SizedBox.shrink(),
                SignalLoaded() => ListView.builder(
                    controller: scrollController,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.monitorSignalsList.length + 1,
                    itemBuilder: (context, index) {
                      if (index == state.monitorSignalsList.length) {
                        return const SignalTabContainer(
                            containerBody: Text(''));
                      }
                      final signal = state.monitorSignalsList[index];
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          child: SignalTabContainer(
                            showBorder: true,
                            containerBody: Text(signal.name),
                          ),
                        ),
                      );
                    },
                  ),
              },
            ),
          ),
        ],
      );
    });
  }
}
