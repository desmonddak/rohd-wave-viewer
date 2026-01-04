// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// selected_signal_panel.dart
// The selected signals panel.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:flutter/material.dart';
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
                      final isFocused = state.focusedSignal?.id == signal.id;

                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            // Toggle focus on this signal
                            if (isFocused) {
                              context
                                  .read<SignalBloc>()
                                  .add(SignalUnfocusEvent());
                            } else {
                              context
                                  .read<SignalBloc>()
                                  .add(SignalFocusEvent(signal));
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: isFocused
                                  ? Border.all(
                                      color: Colors.cyan,
                                      width: 2.0,
                                    )
                                  : null,
                              color: isFocused
                                  ? Colors.blue.withValues(alpha: 0.2)
                                  : Colors.transparent,
                            ),
                            child: SignalTabContainer(
                              showBorder: true,
                              containerBody: Row(
                                children: [
                                  Expanded(
                                    child: Text(signal.name),
                                  ),
                                  if (isFocused)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 8.0),
                                      child: Tooltip(
                                        message:
                                            'Click to deselect. Arrow keys navigate data points.',
                                        child: Icon(
                                          Icons.check_circle,
                                          color: Colors.cyan,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
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
