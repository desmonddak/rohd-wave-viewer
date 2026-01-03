// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// waveform_background.dart
// The waveform background widget.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rohd_wave_viewer/src/const/const.dart';
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
  final bool Function()? isCtrlPressed;

  const WaveformBackground({
    super.key,
    required this.timescale,
    this.verticalScrollController,
    required this.zoomLevel,
    required this.horizontalScrollController,
    required this.screenWidth,
    this.isCtrlPressed,
  });

  @override
  State<WaveformBackground> createState() => _WaveformBackgroundState();
}

class _WaveformBackgroundState extends State<WaveformBackground> {
  double _trackedScrollOffset = 0.0;
  bool _scrollRebuildPending = false;
  int _lastSignalCount = 0;

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
    // Update tracked offset and schedule at most one rebuild per frame
    if (widget.horizontalScrollController.hasClients) {
      _trackedScrollOffset = widget.horizontalScrollController.offset;
    }
    if (_scrollRebuildPending) return;
    _scrollRebuildPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
      _scrollRebuildPending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use actual rendered width (content width) to avoid race conditions when resizing
          final contentWidth =
              constraints.maxWidth; // full zoomed content width
          final viewportWidth = widget.screenWidth; // visible viewport width
          // Removed verbose debug logging for production build
          final scrollOffset = widget.horizontalScrollController.hasClients
              ? widget.horizontalScrollController.offset
              : 0.0;

          // Use the same mapping as WaveformPanel:
          // visibleTimeRange = totalTime / zoomLevel
          // visibleStartTime computed from scroll fraction over maxScrollExtent
          final visibleTimeRange =
              widget.timescale.toDouble() / widget.zoomLevel;
          final maxScrollExtent =
              (contentWidth - viewportWidth).clamp(0.0, double.infinity);
          final scrollFraction =
              (maxScrollExtent > 0) ? (scrollOffset / maxScrollExtent) : 0.0;
          final maxStartTime = widget.timescale.toDouble() - visibleTimeRange;
          final visibleStartTime = scrollFraction * maxStartTime;
          // Removed verbose debug logging for production

          // Compute drawing region accounting for symmetric left/right padding
          // Use a constant unscaled left offset (screen pixels) so the margin
          // does not change when zooming.
          const double baseLeftOffset = waveformLeftOffset;
          const double leftOffset = baseLeftOffset;
          const double rightPadding = baseLeftOffset;
          // Drawing width for the visible viewport (used by painters)
          final double viewportDrawingWidth =
              (viewportWidth - leftOffset - rightPadding)
                  .clamp(0.0, double.infinity);

          return Column(
            children: [
              // Scrollable waveforms (timescale is now in WaveformPanel)
              Expanded(
                child: Stack(
                  children: [
                    // Waveforms and gesture handlers first (drawn first, behind)
                    BlocBuilder<SignalBloc, SignalState>(
                        builder: (content, state) {
                      // Keep build lighter: avoid verbose debug printing

                      // When signal count changes, schedule a scroll controller
                      // layout recalculation to update maxScrollExtent for the new content height.
                      if (state is SignalLoaded &&
                          state.monitorSignalsList.length != _lastSignalCount) {
                        _lastSignalCount = state.monitorSignalsList.length;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted &&
                              widget.verticalScrollController?.hasClients ==
                                  true) {
                            // Post-frame callback ensures layout has settled before we
                            // try to access scroll metrics. The scroll extent should now
                            // reflect the new ListView height.
                          }
                        });
                      }

                      return switch (state) {
                        SignalLoading() => const SizedBox.shrink(),
                        SignalLoaded() => Listener(
                          // Use PointerDown to detect Control modifier reliably without
                          // querying HardwareKeyboard.instance which can assert on some platforms.
                            onPointerDown: (PointerDownEvent event) {
                            // Only react to primary button presses (primary button bit = 0x01)
                            if ((event.buttons & 0x01) == 0) return;

                            // Prefer caller-provided Ctrl check. If not provided, assume not pressed.
                            final bool ctrlPressed = widget.isCtrlPressed?.call() ?? false;
                            if (ctrlPressed) return;

                            final localPos = event.localPosition;

                            // Map viewport-local X into the visible drawing region by subtracting the fixed left offset,
                            // then scale into the visible time range. The PointerDown event localPosition is in the
                            // coordinate space of the ListView item (content coordinates).
                            final double contentX = localPos.dx;
                            final double contentDrawingLeft = _trackedScrollOffset + leftOffset;
                            final double rel = ((contentX - contentDrawingLeft) /
                                viewportDrawingWidth)
                              .clamp(0.0, 1.0);
                            final int timeAtTap = (visibleStartTime + rel * visibleTimeRange).toInt();

                            // Send only marker time to BLoC
                            context.read<WaveformModuleBloc>().add(WaveformModuleOnTap(timeAtTap));
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
                                    // Use the full content width (zoomed width) so each
                                    // waveform row spans the entire scrollable area.
                                    // Painters still draw only the visible range using
                                    // the passed `viewportWidth`/`visibleStartTime`.
                                    final actualWidth = contentWidth;
                                    // Removed layout debug logging
                                    // Pass the visible time slice to the painter
                                    // (visibleStartTime/visibleTimeRange). The
                                    // row width is the full content width so the
                                    // widget can be scrolled; painters compute
                                    // pixel positions using the viewport mapping
                                    // and the provided scrollOffset to place
                                    // their visible drawing into the content.
                                    return drawWaveform(
                                        context,
                                        sig.data,
                                        sig.type == 'hex'
                                            ? SignalType.hexadecimal
                                            : SignalType.binary,
                                        actualWidth,
                                        visibleStartTime.toInt(),
                                        visibleTimeRange.toInt(),
                                        leftOffset,
                                        visibleStartTime,
                                        viewportWidth,
                                        scrollOffset);
                                  },
                                ),
                              ),
                            ),
                          ),
                      };
                    }),
                    // Marker/Cursor last (drawn last, on top)
                    // `Positioned` must be a direct child of the `Stack` so place it
                    // here and wrap its child with `IgnorePointer` so taps pass
                    // through to the GestureDetector below.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: BlocBuilder<WaveformModuleBloc,
                            WaveformModuleState>(
                          builder: (context, state) {
                            // Compute cursor X in content coordinates from state.timePs
                            double cursorContentX = leftOffset;

                            final int t = state.timePs;

                            if (visibleTimeRange > 0 && t > 0) {
                              // Map marker time to content X using the same formula as waveform painters:
                              // contentX = scrollOffset + leftOffset + ((time - visibleStartTime) / visibleTimeRange) * viewportDrawingWidth
                              // This positions the cursor in content coordinates, matching the waveform painters.
                              cursorContentX = _trackedScrollOffset +
                                  leftOffset +
                                  ((t.toDouble() - visibleStartTime) /
                                          visibleTimeRange) *
                                      viewportDrawingWidth;
                            }

                            // cursorContentX is in content coordinates (matches waveform painters)
                            // The visible area in content coords is: scrollOffset+leftOffset to scrollOffset+leftOffset+viewportDrawingWidth
                            double cursorFinalX = cursorContentX;

                            // Determine visible content bounds (content coordinates)
                            final double visibleLeft =
                                _trackedScrollOffset + leftOffset;
                            final double visibleRight = _trackedScrollOffset +
                                leftOffset +
                                viewportDrawingWidth;

                            // If cursor is off-screen (outside visible content), do not draw it.
                            if (cursorFinalX < visibleLeft ||
                                cursorFinalX > visibleRight) {
                              return const SizedBox.shrink();
                            }

                            // Y position: marker Y is stored separately and fixed
                            // For now use a fixed Y position in the center
                            const double cursorViewportY = 100.0;
                            final cursorOffset =
                                Offset(cursorFinalX, cursorViewportY);
                            return CursorWidget(cursorOffset);
                          },
                        ),
                      ),
                    ),
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

    // Return raw local offset (viewport coordinates) so callers can map
    // to content/time consistently. Do not apply padding adjustments here.
    return localOffset;
  }

  Widget drawWaveform(
      BuildContext context,
      List<Data> data,
      SignalType sigType,
      double width,
      int startTime,
      int visibleTimeRange,
      double leftOffset,
      double visibleStartTime,
      double viewportWidth,
      double scrollOffset) {
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
          height: signalRowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: CustomPaint(
              size: Size.infinite,
              isComplex: true,
              willChange: true,
              // Use the full timescale (widget.timescale) as the painter's
              // finalTime. The canvas width already reflects zoom via
              // the parent SizedBox, so passing visibleTimeRange here
              // caused a squared zoom effect (zoom^2). Using the full
              // timescale makes pixels-per-time scale linearly with zoom.
              // Pass the scaled left offset to the painter so it uses
              // the correct offset under zoom (prevents double-shift).
              // Use absolute mapping: finalTime = full timescale,
              // startTime = 0. Scrolling is handled by the
              // Horizontal ScrollView, which clips the large canvas.
              painter: sigType == SignalType.hexadecimal
                  ? WaveformHexaValue(
                      data, visibleTimeRange.toInt(), visibleStartTime.toInt(),
                      leftOffset: leftOffset,
                      viewportWidth: viewportWidth,
                      scrollOffset: scrollOffset)
                  : WaveformBinary(
                      data, visibleTimeRange.toInt(), visibleStartTime.toInt(),
                      leftOffset: leftOffset,
                      viewportWidth: viewportWidth,
                      scrollOffset: scrollOffset),
            ),
          ),
        );
      },
    );
  }
}
