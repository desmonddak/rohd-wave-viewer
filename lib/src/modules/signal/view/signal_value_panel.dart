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
import 'package:rohd_wave_viewer/src/modules/shared/widgets/widgets.dart';
import 'package:rohd_wave_viewer/src/modules/signal/bloc/signal_bloc.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/bloc/waveform_module_bloc.dart';
import 'package:rohd_wave_viewer/src/modules/rohd_module/bloc/rohd_module_bloc.dart'
    hide Error;

class SignalValuePanel extends StatelessWidget {
  final ScrollController? scrollController;

  const SignalValuePanel({super.key, this.scrollController});

  @override
  Widget build(BuildContext context) {
    // Rebuild when either the signal selection changes or the cursor updates
    return BlocBuilder<SignalBloc, SignalState>(
      builder: (signalCtx, signalState) {
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
                              containerBody: Text(''),
                            );
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
      },
    );
  }

  Widget updateSignalValue(BuildContext context, WaveformModuleState state) {
    final signalBloc = BlocProvider.of<SignalBloc>(context);
    final monitorSignalList = signalBloc.state.monitorSignalsList;

    final List<String> valueList = <String>[];

    for (final signal in monitorSignalList) {
      final scaleTime = state.timePs;
      final String val = signal.getValueByTime(scaleTime);
      // Also compute the last-before value using the same binary-search
      // approach used by the waveform painters to detect mismatches.
      String? computed;
      final data = signal.data;
      if (data.isEmpty) {
        computed = null;
      } else {
        int lo = 0;
        int hi = data.length - 1;
        int res = -1;
        while (lo <= hi) {
          final mid = (lo + hi) >> 1;
          if (data[mid].time <= scaleTime) {
            res = mid;
            lo = mid + 1;
          } else {
            hi = mid - 1;
          }
        }
        if (res != -1) computed = data[res].value;
      }

      // Log any differences between the two lookup methods to help debug
      // marker vs painter/value-panel inconsistencies.
      if (computed != null && val != computed) {
        throw StateError(
          'Value mismatch for ${signal.fullPath ?? signal.name} '
          'at timePs=$scaleTime: getValueByTime=$val, '
          'getValueAtOrBefore=$computed, dataLen=${data.length}',
        );
      }

      // Format numeric values as hexadecimal by default; keep 'x'/'z' as-is.
      String formatted = val;
      final lower = val.toLowerCase();
      if (!lower.contains('x') && !lower.contains('z')) {
        BigInt? parsed;
        // Support common value formats: 0x.. (hex), 0b.. (binary),
        // plain bitvector (e.g. 101010), or decimal fallback.
        if (lower.startsWith('0x')) {
          final digits = lower.substring(2);
          if (digits.isNotEmpty) parsed = BigInt.tryParse(digits, radix: 16);
        } else if (lower.startsWith('0b')) {
          final bits = lower.substring(2);
          if (bits.isNotEmpty) parsed = BigInt.tryParse(bits, radix: 2);
        } else if (RegExp(r'^[01]+$').hasMatch(lower) && lower.isNotEmpty) {
          // Plain bitvector (no 0b prefix) -> interpret as binary
          parsed = BigInt.tryParse(lower, radix: 2);
        } else {
          // Fallback to decimal parsing
          parsed = BigInt.tryParse(lower);
        }

        if (parsed != null) {
          // Use signal width (bits) if available to pad hex representation
          final width = signal.width ?? 0;
          final int hexDigits = (width <= 0) ? 0 : ((width + 3) ~/ 4);
          var hex = parsed.toRadixString(16).toUpperCase();
          formatted = '0x${hexDigits > 0 ? hex.padLeft(hexDigits, '0') : hex}';
        }
      }
      valueList.add(formatted);
    }

    return ListView.builder(
      controller: scrollController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: valueList.length + 1,
      itemBuilder: (context, index) {
        if (index == valueList.length) {
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

    // 2. Define the maximum scale value from module metadata (endTime)
    double maxScaleValue = 20.0;
    try {
      final rohdModuleState = BlocProvider.of<RohdModuleBloc>(context).state;
      final endTime = rohdModuleState.moduleStructure.metadata.endTime;
      if (endTime > 0) {
        maxScaleValue = endTime.toDouble();
      }
    } catch (e) {
      // Keep default maxScaleValue if RohdModuleBloc isn't available
    }

    // 3. Calculate the ratio
    double ratio = maxScaleValue / canvasWidth;

    // 4. Adjust the offset based on the ratio
    Offset scaledOffset = Offset(
      adjustedOffset.dx * ratio,
      adjustedOffset.dy * ratio,
    );

    return scaledOffset;
  }
}
