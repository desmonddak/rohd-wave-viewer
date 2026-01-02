// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// waveform_background.dart
// The waveform background widget.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rohd_wave_viewer/src/const/const.dart';
import 'package:rohd_wave_viewer/src/modules/shared/widgets/panel_header.dart';
import 'package:rohd_wave_viewer/src/modules/shared/widgets/signal_tab_container.dart';
import 'package:rohd_wave_viewer/src/modules/signal/bloc/signal_bloc.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/bloc/waveform_module_bloc.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/view/widgets/cursor.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/view/widgets/painters/waveform_hexavalue.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/view/widgets/painters/waveform_binary.dart';
import 'package:module_structure_api/module_structure_api.dart';

enum SignalType { binary, hexadecimal }

class WaveformBackground extends StatefulWidget {
  final int timescale;
  final ScrollController? verticalScrollController;
  final double zoomLevel;
  final ScrollController horizontalScrollController;
  final double screenWidth;

  const WaveformBackground({
    super.key,
    required this.timescale,
    this.verticalScrollController,
    required this.zoomLevel,
    required this.horizontalScrollController,
    required this.screenWidth,
  });

  @override
  State<WaveformBackground> createState() => _WaveformBackgroundState();
}

class _WaveformBackgroundState extends State<WaveformBackground> {
  @override
  void initState() {
    super.initState();
    // Listen to horizontal scroll changes to update timescale
    widget.horizontalScrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(WaveformBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If zoom level or screen width changed, trigger rebuild
    if (oldWidget.zoomLevel != widget.zoomLevel ||
        oldWidget.screenWidth != widget.screenWidth) {
      // Removed debug prints
      setState(() {
        // Trigger rebuild when zoom or screen size changes
      });
    }

    // If scroll controller changed, update listener
    if (oldWidget.horizontalScrollController !=
        widget.horizontalScrollController) {
      oldWidget.horizontalScrollController.removeListener(_onScroll);
      widget.horizontalScrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.horizontalScrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      // Trigger rebuild when scroll position changes
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use actual rendered width to avoid race conditions when resizing
          final layoutWidth = constraints.maxWidth;
          final zoomedWidth =
              layoutWidth; // parent SizedBox already sets full zoomed width
          // Log controller extents for debugging - use try/catch to avoid null issues
          double? controllerMax;
          double? controllerOffset;
          try {
            if (widget.horizontalScrollController.hasClients) {
              controllerMax =
                  widget.horizontalScrollController.position.maxScrollExtent;
              controllerOffset = widget.horizontalScrollController.offset;
            }
          } catch (e) {
            // Controller not yet attached
          }
          // Removed verbose debug logging for production build
          final scrollOffset = widget.horizontalScrollController.hasClients
              ? widget.horizontalScrollController.offset
              : 0.0;

          // Calculate what portion of the total time is visible
          final visibleStartRatio =
              (zoomedWidth > 0) ? (scrollOffset / zoomedWidth) : 0.0;
          final visibleEndRatio = (zoomedWidth > 0)
              ? ((scrollOffset + layoutWidth) / zoomedWidth)
              : 1.0;

          final visibleStartTime = widget.timescale * visibleStartRatio;
          final visibleEndTime = widget.timescale * visibleEndRatio;
          final visibleTimeRange = visibleEndTime - visibleStartTime;
          final visibleFraction = (visibleTimeRange / widget.timescale);
            // Removed verbose debug logging for production

          return Column(
            children: [
              // Scrollable waveforms (timescale is now in WaveformPanel)
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child:
                          BlocBuilder<WaveformModuleBloc, WaveformModuleState>(
                        builder: (context, state) {
                          return CursorWidget(state.pos);
                        },
                      ),
                    ),
                    BlocBuilder<SignalBloc, SignalState>(
                        builder: (content, state) {
                      // Keep build lighter: avoid verbose debug printing
                      return switch (state) {
                        SignalLoading() => const SizedBox.shrink(),
                        SignalLoaded() => GestureDetector(
                            onTapDown: (TapDownDetails tapDownDetails) {
                              final positionClicked =
                                  getPosition(content, tapDownDetails);
                              context
                                  .read<WaveformModuleBloc>()
                                  .add(WaveformModuleOnTap(positionClicked));
                            },
                            child: Listener(
                              // Block pointer signal events (mouse wheel) from scrolling
                              onPointerSignal: (event) {
                                // Do nothing - this blocks scroll events
                              },
                              child: ScrollConfiguration(
                                // Disable pointer signal (mouse wheel) scrolling on ListView
                                behavior:
                                    ScrollConfiguration.of(context).copyWith(
                                  scrollbars: true,
                                ),
                                child: ListView.builder(
                                  controller: widget.verticalScrollController,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount:
                                      state.monitorSignalsList.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index ==
                                        state.monitorSignalsList.length) {
                                      return const SignalTabContainer(
                                        containerBody: Text(''),
                                      );
                                    }
                                    final sig = state.monitorSignalsList[index];
                                    // Removed detailed waveform data logging
                                    // Use layoutWidth (actual rendered width) so painter matches scroll metrics
                                    final actualWidth = layoutWidth;
                                    // Removed layout debug logging
                                    return drawWaveform(
                                        context,
                                        sig.data,
                                        sig.type == 'hex'
                                            ? SignalType.hexadecimal
                                            : SignalType.binary,
                                        actualWidth,
                                        visibleStartTime.round(),
                                        visibleTimeRange.round());
                                  },
                                ),
                              ),
                            ),
                          ),
                      };
                    }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Offset adjustPropotion(BuildContext context, Offset adjustedOffset) {
    // 1. Get the width of the total canvas
    double canvasWidth = MediaQuery.of(context).size.width;

    // 2. Define the maximum scale value
    double maxScaleValue = widget.timescale.toDouble();

    // 3. Calculate the ratio
    double ratio = maxScaleValue / canvasWidth;

    // 4. Adjust the offset based on the ratio
    Offset scaledOffset =
        Offset(adjustedOffset.dx * ratio, adjustedOffset.dy * ratio);

    return scaledOffset;
  }

  Offset getPosition(BuildContext context, TapDownDetails details) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localOffset = box.globalToLocal(details.globalPosition);

    final adjustedOffset = Offset(
        localOffset.dx - waveformPadding, localOffset.dx - waveformPadding);

    // 1.Get the width of the total canvas
    // removed debug print

    // 2. divide by timescale
    return adjustedOffset;
  }

  Widget drawWaveform(BuildContext context, List<Data> data, SignalType sigType,
      double width, int startTime, int visibleTimeRange) {
    final painterWidth = width;
    // Removed debug logging for drawWaveform

    // Use LayoutBuilder inside the row to verify the actual constraints
    return LayoutBuilder(
      builder: (context, rowConstraints) {
        // Removed LayoutBuilder constraint debug logging
        return SizedBox(
          key: ValueKey(
              'waveform_row_${painterWidth}_${visibleTimeRange}_$startTime'),
          width: painterWidth,
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: CustomPaint(
              size: Size.infinite,
              isComplex: true,
              willChange: true,
              painter: sigType == SignalType.hexadecimal
                  ? WaveformHexaValue(data, visibleTimeRange, startTime)
                  : WaveformBinary(data, visibleTimeRange, startTime),
            ),
          ),
        );
      },
    );
  }
}
