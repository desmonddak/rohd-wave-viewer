// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// signal_value_panel.dart
// The signal value panel.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rohd_wave_viewer/src/const/const.dart';
import 'package:rohd_wave_viewer/src/modules/shared/widgets/panel_header.dart';
import 'package:rohd_wave_viewer/src/modules/shared/widgets/signal_tab_container.dart';
import 'package:rohd_wave_viewer/src/modules/signal/bloc/signal_bloc.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/bloc/waveform_module_bloc.dart';

class SignalValuePanel extends StatelessWidget {
  final ScrollController? scrollController;

  const SignalValuePanel({super.key, this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const PanelHeader(headerText: signalsValuePanelTitle),
        Expanded(
          child: Listener(
            onPointerSignal: (event) {
              // Block pointer signal events (mouse wheel)
            },
            child: BlocBuilder<WaveformModuleBloc, WaveformModuleState>(
              builder: (context, state) {
                return switch (state) {
                  InitialCursor() => ListView.builder(
                      controller: scrollController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 1,
                      itemBuilder: (context, index) {
                        return const SignalTabContainer(
                            containerBody: Text(''));
                      },
                    ),
                  UpdatedCursor() => updateSignalValue(context, state),
                  Error() => const Text(bugReport),
                };
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget updateSignalValue(BuildContext context, WaveformModuleState state) {
    final signalBloc = BlocProvider.of<SignalBloc>(context);
    final monitorSignalList = signalBloc.state.monitorSignalsList;

    final valueList = [];

    for (final signal in monitorSignalList) {
      final scaleTime = adjustPropotion(context, state.pos).dx.toInt();
      final val = signal.getValueByTime(scaleTime);
      valueList.add(val);
    }

    return ListView.builder(
      controller: scrollController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: monitorSignalList.length + 1,
      itemBuilder: (context, index) {
        if (index == monitorSignalList.length) {
          return const SignalTabContainer(containerBody: Text(''));
        }
        final value = valueList[index];
        return SignalTabContainer(containerBody: Text(value));
      },
    );
  }

  Offset adjustPropotion(BuildContext context, Offset adjustedOffset) {
    // 1. Get the width of the total canvas
    double canvasWidth = MediaQuery.of(context).size.width;

    // 2. Define the maximum scale value
    double maxScaleValue = 20.0;

    // 3. Calculate the ratio
    double ratio = maxScaleValue / canvasWidth;

    // 4. Adjust the offset based on the ratio
    Offset scaledOffset =
        Offset(adjustedOffset.dx * ratio, adjustedOffset.dy * ratio);

    return scaledOffset;
  }
}
