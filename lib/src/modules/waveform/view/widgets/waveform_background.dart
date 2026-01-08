// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// waveform_background.dart
// The waveform background widget.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rohd_wave_viewer/src/const/const.dart';
import 'package:rohd_wave_viewer/src/modules/shared/widgets/widgets.dart';
import 'package:rohd_wave_viewer/src/modules/signal/bloc/signal_bloc.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/bloc/waveform_module_bloc.dart';
import 'cursor.dart';
import 'painters/painters.dart';
import 'package:module_structure_api/module_structure_api.dart';
import 'dart:async';

// Use platform-specific JS bindings: web implementation calls into JS,
// native implementation is a no-op.
import 'package:rohd_wave_viewer/src/platform/platform.dart' as plat;

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
  bool _scrollRebuildPending = false;
  int _lastSignalCount = 0;
  // Notifier used to trigger CustomPainter repaint when zoom/scroll changes
  final ValueNotifier<int> _repaintNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    // Listen to horizontal scroll changes to update timescale
    widget.horizontalScrollController.addListener(_onScroll);
    // Prime painters to ensure initial paint and to avoid cases where
    // the painter doesn't observe immediate subsequent repaint triggers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _repaintNotifier.value++;
    });
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
      // Notify painters to repaint on zoom or viewport change
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _repaintNotifier.value++;
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
    _repaintTimer?.cancel();
    widget.horizontalScrollController.removeListener(_onScroll);
    _repaintNotifier.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollRebuildPending) return;
    _scrollRebuildPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
      // Note: removed _repaintNotifier bump here since setState already triggers rebuild
      // and the painters will repaint due to scrollOffset parameter change.
      _scrollRebuildPending = false;
    });
  }

  Timer? _repaintTimer;

  /// Force a repaint from outside the widget (used by the parent panel during zoom)
  void forceRepaint() {
    if (!mounted) return;

    // Cancel any pending timer
    _repaintTimer?.cancel();

    // Use a short timer to force a couple of repaints (reduced from 10 to 3)
    // This keeps the compositor active in embedded webviews without spam
    int count = 0;
    _repaintTimer = Timer.periodic(const Duration(milliseconds: 32), (timer) {
      if (!mounted || count >= 3) {
        timer.cancel();
        return;
      }
      count++;
      _repaintNotifier.value++;
      setState(() {});
      SchedulerBinding.instance.scheduleFrame();
      _requestBrowserAnimationFrame();
      _callJsForceRepaint();
    });
  }

  void _callJsForceRepaint() {
    try {
      plat.jsRohdForceRepaint();
    } catch (e) {
      debugPrint('[WaveformBackground] JS force repaint error: $e');
    }
  }

  void _requestBrowserAnimationFrame() {
    try {
      plat.jsRequestAnimationFrame(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
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
                              state.monitorSignalsList.length !=
                                  _lastSignalCount) {
                            _lastSignalCount = state.monitorSignalsList.length;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted &&
                                  widget.verticalScrollController?.hasClients ==
                                      true) {
                                // Trigger a repaint when signal count changes
                                _repaintNotifier.value++;
                              }
                            });
                          }

                          if (state is! SignalLoaded) {
                            return const SizedBox.shrink();
                          }

                          // When we have loaded signals, render the list of waveforms.
                          return Listener(
                            // Use PointerDown to detect Control modifier reliably without
                            // querying HardwareKeyboard.instance which can assert on some platforms.
                            onPointerDown: (PointerDownEvent event) {
                              // Only react to primary button presses (primary button bit = 0x01)
                              if ((event.buttons & 0x01) == 0) return;

                              // Prefer caller-provided Ctrl check. If not provided, assume not pressed.
                              final bool ctrlPressed =
                                  widget.isCtrlPressed?.call() ?? false;
                              if (ctrlPressed) return;

                              final localPos = event.localPosition;

                              // Use ABSOLUTE time mapping (inverse of cursor drawing formula):
                              // Drawing: contentX = leftOffset + (time / timescale) * drawingContentWidth
                              // Picking: time = ((contentX - leftOffset) / drawingContentWidth) * timescale
                              final double drawingContentWidth =
                                  contentWidth - leftOffset - rightPadding;
                              if (drawingContentWidth <= 0 ||
                                  widget.timescale <= 0) {
                                return;
                              }

                              final double rel = ((localPos.dx - leftOffset) /
                                      drawingContentWidth)
                                  .clamp(0.0, 1.0);
                              final int timeAtTap =
                                  (rel * widget.timescale).toInt();

                              // Send only marker time to BLoC
                              context
                                  .read<WaveformModuleBloc>()
                                  .add(WaveformModuleOnTap(timeAtTap));
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
                                    final actualWidth = contentWidth;
                                    return drawWaveform(
                                      context,
                                      sig.data,
                                      (sig.type.toLowerCase() == 'bin' ||
                                              sig.type.toLowerCase() ==
                                                  'binary')
                                          ? SignalType.binary
                                          : SignalType.hexadecimal,
                                      actualWidth,
                                      visibleStartTime.toInt(),
                                      visibleTimeRange.toInt(),
                                      leftOffset,
                                      visibleStartTime,
                                      viewportWidth,
                                      scrollOffset,
                                      sig.width,
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // Marker/Cursor last (drawn last, on top)
                      // `Positioned` must be a direct child of the `Stack` so place it
                      // here and wrap its child with `IgnorePointer` so taps pass
                      // through to the GestureDetector below.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: BlocBuilder<WaveformModuleBloc,
                              WaveformModuleState>(
                            builder: (context, state) {
                              // Use ABSOLUTE time mapping - same as WaveformBinary/WaveformHexaValue painters:
                              // contentX = leftOffset + (time / timescale) * drawingContentWidth
                              // where drawingContentWidth = contentWidth - leftOffset - rightPadding
                              //
                              // This ensures the marker aligns exactly with the waveform transitions.
                              final int t = state.timePs;
                              if (t < 0 || widget.timescale <= 0) {
                                return const SizedBox.shrink();
                              }

                              final double drawingContentWidth =
                                  contentWidth - leftOffset - rightPadding;
                              final double cursorContentX = leftOffset +
                                  (t.toDouble() / widget.timescale.toDouble()) *
                                      drawingContentWidth;

                              // Check if cursor is within the content range
                              if (cursorContentX < 0 ||
                                  cursorContentX > contentWidth) {
                                return const SizedBox.shrink();
                              }

                              // Y position: marker Y is stored separately and fixed
                              // For now use a fixed Y position in the center
                              const double cursorViewportY = 100.0;
                              final cursorOffset =
                                  Offset(cursorContentX, cursorViewportY);
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
      double scrollOffset,
      int? signalWidth) {
    final painterWidth = width;
    // Removed debug logging for drawWaveform

    // Use LayoutBuilder inside the row to verify the actual constraints
    return LayoutBuilder(
      builder: (context, rowConstraints) {
        // Removed LayoutBuilder constraint debug logging
        return SizedBox(
          width: painterWidth,
          height: signalRowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ValueListenableBuilder<int>(
              valueListenable: _repaintNotifier,
              builder: (context, repaintKey, _) {
                return CustomPaint(
                  key: ValueKey('paint_$repaintKey'),
                  size: Size.infinite,
                  isComplex: true,
                  willChange: true,
                  // Use ABSOLUTE time mapping: pass timescale so painters map
                  // time 0 to leftOffset and time=timescale to width-rightPadding.
                  // The canvas width is contentWidth (zoomed), so waveforms scale correctly.
                  // ScrollView handles clipping to show the visible portion.
                                    // Prefer declared `signalWidth` when available: if a signal
                                    // is declared as 1-bit, use the binary painter regardless
                                    // of the textual type reported by the loader. This helps
                                    // ensure `clk`-like signals render as single-bit.
                                    painter: (signalWidth != null && signalWidth == 1)
                                      ? WaveformBinary(data, visibleTimeRange, startTime,
                                        signalWidth: signalWidth,
                                        leftOffset: leftOffset,
                                        viewportWidth: viewportWidth,
                                        scrollOffset: scrollOffset,
                                        timescale: widget.timescale,
                                        repaint: _repaintNotifier)
                                      : (sigType == SignalType.hexadecimal
                                        ? WaveformHexaValue(data, visibleTimeRange, startTime,
                                          signalWidth: signalWidth,
                                          leftOffset: leftOffset,
                                          viewportWidth: viewportWidth,
                                          scrollOffset: scrollOffset,
                                          timescale: widget.timescale,
                                          repaint: _repaintNotifier)
                                        : WaveformBinary(data, visibleTimeRange, startTime,
                                          signalWidth: signalWidth,
                                          leftOffset: leftOffset,
                                          viewportWidth: viewportWidth,
                                          scrollOffset: scrollOffset,
                                          timescale: widget.timescale,
                                          repaint: _repaintNotifier)),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
