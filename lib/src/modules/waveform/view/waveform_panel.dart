// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// waveform_panel.dart
// The waveform panel.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// waveform_panel.dart
// The waveform panel.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rohd_wave_viewer/src/modules/rohd_module/bloc/rohd_module_bloc.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/view/widgets/timescale.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/view/widgets/waveform_background.dart';
import 'package:rohd_wave_viewer/src/const/const.dart';

class WaveformPanel extends StatefulWidget {
  final ScrollController? verticalScrollController;

  const WaveformPanel({super.key, this.verticalScrollController});

  @override
  State<WaveformPanel> createState() => _WaveformPanelState();
}

class _WaveformPanelState extends State<WaveformPanel> {
  double _zoomLevel = 1.0;
  double? _lastActualWidth;
  final ScrollController _horizontalScrollController = ScrollController();
  late final ScrollController _verticalScrollController;
  final FocusNode _focusNode = FocusNode();
  double _trackedScrollOffset =
      0.0; // Track scroll offset for zoom calculations
  bool _scrollRebuildPending = false;

  // Panning state (reserved for future use)
  Offset? _lastPanPosition;
  bool _isMousePanning = false;

  @override
  void initState() {
    super.initState();
    _verticalScrollController =
        widget.verticalScrollController ?? ScrollController();
    // Add listener to update timescale when scrolling
    _horizontalScrollController.addListener(_onHorizontalScroll);
    // Keep focus listener silent in production
    _focusNode.addListener(() {});
    // Ensure this panel receives keyboard focus when first shown so arrow
    // keys and other shortcuts work immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onHorizontalScroll() {
    // Update tracked scroll offset synchronously for zoom math and
    // schedule a single rebuild per frame to avoid excessive rebuilds
    if (_horizontalScrollController.hasClients) {
      _trackedScrollOffset = _horizontalScrollController.offset;
    }

    if (_scrollRebuildPending) return;
    _scrollRebuildPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
      _scrollRebuildPending = false;
    });
  }

  @override
  void dispose() {
    _horizontalScrollController.removeListener(_onHorizontalScroll);
    _horizontalScrollController.dispose();
    _focusNode.dispose();
    if (widget.verticalScrollController == null) {
      _verticalScrollController.dispose();
    }
    super.dispose();
  }

  void _zoomIn() {
    _zoomWithPreservedPosition(1.5);
  }

  void _zoomOut() {
    _zoomWithPreservedPosition(1.0 / 1.5);
  }

  void _zoomWithPreservedPosition(double factor, {double? focalViewportX}) {
    // Get current scroll fraction before zooming
    double scrollFraction = 0.0;
    if (_horizontalScrollController.hasClients) {
      final maxExtent = _horizontalScrollController.position.maxScrollExtent;
      if (maxExtent > 0) {
        scrollFraction = _horizontalScrollController.offset / maxExtent;
      }
    }

    // Compute old/current state for focal math before changing zoom
    final double oldZoom = _zoomLevel;
    // Use the tracked scroll offset (which is updated after each zoom)
    // rather than reading from the controller, since jumpTo() is asynchronous
    final double currentScrollOffset = _trackedScrollOffset;

    // If focalViewportX is not provided, we will preserve scroll fraction.
    // Otherwise, compute the content X under the focal point and adjust
    // the scroll offset after zoom so the same content pixel remains
    // under the same viewport X.
    final double? oldContentX = (focalViewportX != null)
        ? (currentScrollOffset + focalViewportX)
        : null;

    // Determine the new zoom level (clamped)
    final double intendedNewZoom = (oldZoom * factor);
    final double newZoom = intendedNewZoom.clamp(1.0, 100000.0);

    setState(() {
      _zoomLevel = newZoom;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // After layout settles, compute new offsets
      if (!_horizontalScrollController.hasClients) {
        // If controller not ready yet, retry next frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _restoreScrollFraction(scrollFraction);
        });
        return;
      }

      final double newMaxExtent =
          _horizontalScrollController.position.maxScrollExtent;

      // Shared variable for the offset we will jump to after zoom
      double finalNewOffset = 0.0;

      if (oldContentX == null) {
        // No focal point: preserve previous scroll fraction
        finalNewOffset =
            (scrollFraction * newMaxExtent).clamp(0.0, newMaxExtent);
        try {
          _trackedScrollOffset = finalNewOffset;
          _horizontalScrollController.jumpTo(finalNewOffset);
        } catch (_) {}
        return;
      }

      // With focal point: do focal-point zoom to keep the cursor at the same screen X
      // The marker's TIME stays constant (stored in BLoC), and its screen position
      // is derived automatically from the new visible time range.
      final double scale = (newZoom / oldZoom);
      const double left = waveformLeftOffset;

      // Compute drawing X relative to left offset and clamp to >= 0
      final double oldDrawingX =
          (oldContentX - left).clamp(0.0, double.infinity);
      final double newDrawingX = oldDrawingX * scale;
      final double newContentX = left + newDrawingX;

      // Focal-point zoom: keep the same content pixel under the same viewport X
      finalNewOffset =
          (newContentX - focalViewportX!).clamp(0.0, newMaxExtent).toDouble();

      try {
        _trackedScrollOffset = finalNewOffset;
        _horizontalScrollController.jumpTo(finalNewOffset);
      } catch (_) {}
    });
  }

  void _restoreScrollFraction(double scrollFraction, {int retries = 10}) {
    if (_horizontalScrollController.hasClients) {
      final newMaxExtent = _horizontalScrollController.position.maxScrollExtent;
      final newOffset =
          (scrollFraction * newMaxExtent).clamp(0.0, newMaxExtent);
      // Silent restore
      if (newMaxExtent > 0 || retries <= 0) {
        try {
          _horizontalScrollController.jumpTo(newOffset);
        } catch (e) {
          // ignore
        }
      } else {
        // Wait a frame and retry (gives layout time to settle)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _restoreScrollFraction(scrollFraction, retries: retries - 1);
        });
      }
    } else if (retries > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreScrollFraction(scrollFraction, retries: retries - 1);
      });
    }
  }

  void _panLeft() {
    final offset = _horizontalScrollController.offset;
    final screenWidth = MediaQuery.of(context).size.width;
    final panStep = screenWidth * 0.1; // Pan 10% of screen width
    _horizontalScrollController
        .animateTo(
      (offset - panStep)
          .clamp(0.0, _horizontalScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    )
        .then((_) {
      // Re-request focus after animation completes
      _focusNode.requestFocus();
    });
  }

  void _panRight() {
    final offset = _horizontalScrollController.offset;
    final screenWidth = MediaQuery.of(context).size.width;
    final panStep = screenWidth * 0.1;
    _horizontalScrollController.animateTo(
      (offset + panStep)
          .clamp(0.0, _horizontalScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    // Key events handled without verbose logging
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _panLeft();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _panRight();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _scrollUp();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _scrollDown();
      } else if ((HardwareKeyboard.instance.logicalKeysPressed
                  .contains(LogicalKeyboardKey.shiftLeft) ||
              HardwareKeyboard.instance.logicalKeysPressed
                  .contains(LogicalKeyboardKey.shiftRight)) &&
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // Shift+Up = zoom in
        _zoomIn();
      } else if ((HardwareKeyboard.instance.logicalKeysPressed
                  .contains(LogicalKeyboardKey.shiftLeft) ||
              HardwareKeyboard.instance.logicalKeysPressed
                  .contains(LogicalKeyboardKey.shiftRight)) &&
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        // Shift+Down = zoom out
        _zoomOut();
      } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
        // 'F' key = fit waveform to viewport (reset zoom and scroll to 0)
        setState(() {
          _zoomLevel = 1.0;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _horizontalScrollController.jumpTo(0.0);
          } catch (_) {}
        });
      }
    }
  }

  void _scrollUp() {
    // scrollUp invoked
    try {
      if (_verticalScrollController.hasClients) {
        const scrollStep = signalRowHeight; // One signal row
        final offset = _verticalScrollController.offset;
        final maxExtent = _verticalScrollController.position.maxScrollExtent;
        final newOffset = (offset - scrollStep).clamp(0.0, maxExtent);
        _verticalScrollController.jumpTo(newOffset);
      }
    } catch (e) {
      // ignore errors silently in scrollUp
    }
  }

  void _scrollDown() {
    // scrollDown invoked
    try {
      if (_verticalScrollController.hasClients) {
        const scrollStep = signalRowHeight; // One signal row
        final offset = _verticalScrollController.offset;
        final maxExtent = _verticalScrollController.position.maxScrollExtent;
        final newOffset = (offset + scrollStep).clamp(0.0, maxExtent);
        _verticalScrollController.jumpTo(newOffset);
      }
    } catch (e) {
      // ignore errors silently in scrollDown
    }
  }

  void _handleScroll(PointerSignalEvent event, BuildContext context) {
    if (event is PointerScrollEvent) {
      // Only zoom when Control key is held
      final bool ctrlPressed = HardwareKeyboard.instance.logicalKeysPressed
              .contains(LogicalKeyboardKey.controlLeft) ||
          HardwareKeyboard.instance.logicalKeysPressed
              .contains(LogicalKeyboardKey.controlRight);
      if (!ctrlPressed) return;

      final scrollDelta = event.scrollDelta.dy;
      // Determine mouse position relative to viewport
      final RenderBox box = context.findRenderObject() as RenderBox;
      final local = box.globalToLocal(event.position);
      final focalX = local.dx; // viewport-local X

      if (scrollDelta > 0) {
        // Scroll down = zoom out
        _zoomWithPreservedPosition(1.0 / 1.5, focalViewportX: focalX);
      } else if (scrollDelta < 0) {
        // Scroll up = zoom in
        _zoomWithPreservedPosition(1.5, focalViewportX: focalX);
      }
    }
  }

  // Custom scroll behavior that disables mouse wheel scrolling
  ScrollBehavior _buildCustomScrollBehavior(BuildContext context) {
    return _NoMouseWheelScrollBehavior();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return BlocBuilder<RohdModuleBloc, RohdModuleState>(
        builder: (context, state) {
      // Get time range from metadata, default to 20 if not available
      final endTime = state.moduleStructure.metadata.endTime;
      final timescale = endTime > 0 ? endTime : 20;

      return Focus(
        autofocus: true,
        child: KeyboardListener(
          focusNode: _focusNode,
          onKeyEvent: _handleKeyEvent,
          // Use LayoutBuilder to get actual widget width, not full screen width
          child: LayoutBuilder(
            builder: (context, constraints) {
              final actualWidth = constraints.maxWidth;
              // Preserve scroll fraction when the available width changes (window resize)
              final zoomedWidth = actualWidth * _zoomLevel;
              // Do not emit verbose debug logs in production
              if (_lastActualWidth == null) {
                _lastActualWidth = actualWidth;
              } else if (_lastActualWidth != actualWidth) {
                final oldActual = _lastActualWidth!;
                final oldZoomedWidth = oldActual * _zoomLevel;
                final oldMaxScrollExtent =
                    (oldZoomedWidth - oldActual).clamp(0.0, double.infinity);
                final double scrollFraction = (oldMaxScrollExtent > 0 &&
                        _horizontalScrollController.hasClients)
                    ? (_horizontalScrollController.offset / oldMaxScrollExtent)
                    : 0.0;
                // Resize event handled silently
                _lastActualWidth = actualWidth;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _restoreScrollFraction(scrollFraction);
                });
              }

              // Calculate visible time range for timescale
              // When zoomed, the visible range is always timescale / zoomLevel
              final visibleTimeRange = timescale.toDouble() / _zoomLevel;

              // Calculate start time based on scroll position. Prefer the
              // tracked scroll offset updated by the throttled listener to
              // avoid tight coupling to controller reads during fast pans.
              final scrollOffset = _horizontalScrollController.hasClients
                  ? _trackedScrollOffset
                  : 0.0;
              final maxScrollExtent = zoomedWidth - actualWidth;
              final scrollFraction =
                  maxScrollExtent > 0 ? scrollOffset / maxScrollExtent : 0.0;
              final maxStartTime = timescale.toDouble() - visibleTimeRange;
              final visibleStartTime = scrollFraction * maxStartTime;

              // Suppress verbose waveform panel logging

              return Column(
                children: [
                  // Fixed timescale header - does NOT scroll
                  SizedBox(
                    height: 50,
                    width: actualWidth,
                    child: TimescaleWidget(
                      zoomLevel: _zoomLevel,
                      finalTime: visibleTimeRange,
                      startTime: visibleStartTime,
                      viewportWidth: actualWidth,
                    ),
                  ),
                  // Scrollable content below
                  Expanded(
                    child: Stack(
                      children: [
                        Listener(
                          // Capture scroll events for zoom only, but allow other events through
                          behavior: HitTestBehavior.translucent,
                          onPointerSignal: (event) {
                            _handleScroll(event, context);
                          },
                          child: ScrollConfiguration(
                            behavior: _buildCustomScrollBehavior(context),
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () {
                                // Request focus when tapped so keyboard events work
                                _focusNode.requestFocus();
                              },
                              onPanStart: (details) {
                                _focusNode
                                    .requestFocus(); // Also request focus on pan
                                // Only start mouse panning when Control key is held.
                                final keys = HardwareKeyboard
                                    .instance.logicalKeysPressed;
                                final bool ctrlPressed = keys.contains(
                                        LogicalKeyboardKey.controlLeft) ||
                                    keys.contains(
                                        LogicalKeyboardKey.controlRight);
                                if (ctrlPressed) {
                                  setState(() {
                                    _isMousePanning = true;
                                    _lastPanPosition = details.globalPosition;
                                  });
                                }
                              },
                              onPanUpdate: (details) {
                                if (!_isMousePanning ||
                                    _lastPanPosition == null) {
                                  return; // Ignore pan updates when not in mouse-panning mode
                                }

                                final deltaX = _lastPanPosition!.dx -
                                    details.globalPosition.dx;
                                final deltaY = _lastPanPosition!.dy -
                                    details.globalPosition.dy;

                                // Pan updates are not logged

                                // Handle horizontal panning
                                final newHorizontalOffset =
                                    (_horizontalScrollController.offset +
                                            deltaX)
                                        .clamp(
                                  0.0,
                                  _horizontalScrollController
                                      .position.maxScrollExtent,
                                );
                                _horizontalScrollController
                                    .jumpTo(newHorizontalOffset);

                                // Handle vertical scrolling with this panel's own controller
                                if (_verticalScrollController.hasClients) {
                                  final newVerticalOffset =
                                      (_verticalScrollController.offset +
                                              deltaY)
                                          .clamp(
                                    0.0,
                                    _verticalScrollController
                                        .position.maxScrollExtent,
                                  );
                                  _verticalScrollController
                                      .jumpTo(newVerticalOffset);
                                }

                                _lastPanPosition = details.globalPosition;
                              },
                              onPanEnd: (details) {
                                setState(() {
                                  _lastPanPosition = null;
                                  _isMousePanning = false;
                                });
                              },
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  scrollbarTheme: ScrollbarThemeData(
                                    thumbColor:
                                        WidgetStateProperty.all(Colors.white),
                                  ),
                                ),
                                child: Scrollbar(
                                  interactive: true,
                                  thumbVisibility: true,
                                  controller: _horizontalScrollController,
                                  child: SingleChildScrollView(
                                    controller: _horizontalScrollController,
                                    scrollDirection: Axis.horizontal,
                                    // Use NeverScrollableScrollPhysics to disable the built-in pan/drag
                                    // scrolling. We handle all panning via custom onPan handlers that
                                    // require Control key, so we don't want SingleChildScrollView's
                                    // default gesture handling to interfere.
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    child: SizedBox(
                                      width: zoomedWidth,
                                      height: screenHeight -
                                          50, // Subtract timescale height
                                      child: WaveformBackground(
                                        // Key forces rebuild when zoom or screen width changes
                                        key: ValueKey(
                                            'waveform_${actualWidth}_$_zoomLevel'),
                                        timescale: timescale,
                                        verticalScrollController:
                                            _verticalScrollController,
                                        zoomLevel: _zoomLevel,
                                        horizontalScrollController:
                                            _horizontalScrollController,
                                        screenWidth: actualWidth,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
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
    });
  }
}

// Custom scroll behavior that disables mouse wheel but allows drag
class _NoMouseWheelScrollBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}
