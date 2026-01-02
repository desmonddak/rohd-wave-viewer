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
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rohd_wave_viewer/src/modules/rohd_module/bloc/rohd_module_bloc.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/view/widgets/timescale.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/view/widgets/waveform_background.dart';

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

  // Panning state
  bool _isPanningHorizontal = false;
  bool _isPanningVertical = false;
  Offset? _lastPanPosition;

  @override
  void initState() {
    super.initState();
    _verticalScrollController =
        widget.verticalScrollController ?? ScrollController();
    // Add listener to update timescale when scrolling
    _horizontalScrollController.addListener(_onHorizontalScroll);
    // Keep focus listener silent in production
    _focusNode.addListener(() {});
  }

  void _onHorizontalScroll() {
    // Trigger rebuild to update timescale with new scroll position
    // No verbose logging during horizontal scroll
    setState(() {});
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

  void _zoomWithPreservedPosition(double factor) {
    // Get current scroll fraction before zooming
    double scrollFraction = 0.0;
    if (_horizontalScrollController.hasClients) {
      final maxExtent = _horizontalScrollController.position.maxScrollExtent;
      if (maxExtent > 0) {
        scrollFraction = _horizontalScrollController.offset / maxExtent;
      }
    }

    setState(() {
      final oldZoom = _zoomLevel;
      _zoomLevel = (_zoomLevel * factor).clamp(1.0, 100000.0);

      // After setState, schedule scroll position restoration
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreScrollFraction(scrollFraction);
      });
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

  void _resetZoom() {
    setState(() {
      _zoomLevel = 1.0;
    });
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
      }
    }
  }

  void _scrollUp() {
    // scrollUp invoked
    try {
      if (_verticalScrollController.hasClients) {
        final scrollStep = 40.0; // One signal row
        // Handle multiple scroll positions (controller is shared across panels)
        for (final position in _verticalScrollController.positions) {
          final offset = position.pixels;
          final maxExtent = position.maxScrollExtent;
          final newOffset = (offset - scrollStep).clamp(0.0, maxExtent);
          position.jumpTo(newOffset);
        }
      }
    } catch (e) {
      if (kDebugMode) print('>>> _scrollUp ERROR: $e');
    }
  }

  void _scrollDown() {
    // scrollDown invoked
    try {
      if (_verticalScrollController.hasClients) {
        final scrollStep = 40.0; // One signal row
        // Handle multiple scroll positions (controller is shared across panels)
        for (final position in _verticalScrollController.positions) {
          final offset = position.pixels;
          final maxExtent = position.maxScrollExtent;
          final newOffset = (offset + scrollStep).clamp(0.0, maxExtent);
          position.jumpTo(newOffset);
        }
      } else {}
    } catch (e) {
      if (kDebugMode) print('>>> _scrollDown ERROR: $e');
    }
  }

  void _handleScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Mouse scroll = zoom only, prevent default scrolling behavior
      final scrollDelta = event.scrollDelta.dy;
      if (scrollDelta > 0) {
        _zoomIn(); // Scroll down = zoom in
      } else if (scrollDelta < 0) {
        _zoomOut(); // Scroll up = zoom out
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

              // Calculate start time based on scroll position
              final scrollOffset = _horizontalScrollController.hasClients
                  ? _horizontalScrollController.offset
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
                            if (event is PointerScrollEvent) {
                              _handleScroll(event);
                            }
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
                                setState(() {
                                  _isPanningHorizontal = true;
                                  _isPanningVertical = true;
                                  _lastPanPosition = details.globalPosition;
                                });
                              },
                              onPanUpdate: (details) {
                                if (_lastPanPosition != null) {
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

                                  // Handle vertical scrolling - iterate over all positions since controller is shared
                                  if (_verticalScrollController.hasClients) {
                                    for (final position
                                        in _verticalScrollController
                                            .positions) {
                                      final newVerticalOffset =
                                          (position.pixels + deltaY).clamp(
                                        0.0,
                                        position.maxScrollExtent,
                                      );
                                      // Vertical pan not logged
                                      position.jumpTo(newVerticalOffset);
                                    }
                                  }

                                  _lastPanPosition = details.globalPosition;
                                }
                              },
                              onPanEnd: (details) {
                                setState(() {
                                  _isPanningHorizontal = false;
                                  _isPanningVertical = false;
                                  _lastPanPosition = null;
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
                                  thumbVisibility: true,
                                  controller: _horizontalScrollController,
                                  child: SingleChildScrollView(
                                    controller: _horizontalScrollController,
                                    scrollDirection: Axis.horizontal,
                                    physics:
                                        const NeverScrollableScrollPhysics(), // Prevent pointer signal scrolling
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

// Custom physics that allows programmatic scrolling but blocks user input
class _ControllerOnlyScrollPhysics extends ClampingScrollPhysics {
  const _ControllerOnlyScrollPhysics({super.parent});

  @override
  _ControllerOnlyScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _ControllerOnlyScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    // Block all user-initiated scrolling (mouse wheel, drag on scrollbar, etc)
    return false;
  }
}
