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
import 'package:rohd_wave_viewer/src/modules/signal/bloc/signal_bloc.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/bloc/waveform_module_bloc.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/view/widgets/timescale.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/view/widgets/waveform_background.dart';
import 'package:rohd_wave_viewer/src/const/const.dart';
import '../../../platform/platform.dart' as plat;
import 'dart:convert';

// Conditional import: use web implementation on web, no-op on native platforms

void _callJsForceRepaint() {
  try {
    plat.jsRohdForceRepaint();
  } catch (e) {
    debugPrint('[WaveformPanel] JS force repaint error: $e');
  }
}

class WaveformPanel extends StatefulWidget {
  final ScrollController? verticalScrollController;

  const WaveformPanel({super.key, this.verticalScrollController});

  @override
  State<WaveformPanel> createState() => _WaveformPanelState();
}

class _WaveformPanelState extends State<WaveformPanel>
    with SingleTickerProviderStateMixin {
  // Key to access the WaveformBackgroundState so we can force repaints
  final GlobalKey _backgroundKey = GlobalKey();
  double _zoomLevel = 1.0;
  double? _lastActualWidth;
  final ScrollController _horizontalScrollController = ScrollController();
  late final ScrollController _verticalScrollController;
  final FocusNode _focusNode = FocusNode();
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  double _trackedScrollOffset =
      0.0; // Track scroll offset for zoom calculations
  bool _scrollRebuildPending = false;

  // Panning state (reserved for future use)
  Offset? _lastPanPosition;
  bool _isMousePanning = false;

  // Guard against re-entrant navigation calls when key is held down
  bool _navigationInProgress = false;

  // Track the last navigation target time (for when BLoC updates are async)
  // Use null to indicate we haven't navigated yet
  int? _lastNavigationTargetTime;
  // When true, disable the default Scrollable pan gestures so custom
  // Ctrl+drag panning can take precedence. Toggled on pointer down when
  // Control key is held.
  bool _suppressScrollPhysics = false;

  // Counter to force multiple frame repaints after zoom (helps with embedded webviews)
  int _forceRepaintFrames = 0;

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

    // Listen for messages posted by the hosting page (index.html). We expect
    // messages with `{ type: 'shift_wheel', deltaY }` when the page detects a
    // Shift+wheel. This is a reliable fallback when Flutter's RawKeyboard state
    // is not reporting modifiers inside VS Code WebView.
    try {
      plat.addWindowMessageListener(_onWindowMessage);
    } catch (e) {
      // ignore on non-web platforms
    }
  }

  void _onWindowMessage(dynamic rawData) {
    try {
      if (rawData == null) return;

      Map<String, dynamic>? data;

      if (rawData is String) {
        try {
          data = json.decode(rawData) as Map<String, dynamic>?;
        } catch (_) {
          return;
        }
      } else if (rawData is Map) {
        data = Map<String, dynamic>.from(rawData);
      } else {
        // Unknown type - try to convert via toString/JSON
        try {
          final s = rawData.toString();
          data = json.decode(s) as Map<String, dynamic>?;
        } catch (_) {
          return;
        }
      }

      if (data == null) return;

      final source = data['source']?.toString();
      final mtype = data['type']?.toString();

      // Lightweight debug: log unexpected messages to help diagnose host noise
      if (source == null || mtype == null) {
        debugPrint(
            '[WaveformPanel] host message ignored (no source/type): ${data.runtimeType}');
        return;
      }

      if (source == 'rohd_wave_viewer' && mtype == 'shift_wheel') {
        // Extract deltaY and clientX from the Map
        num deltaY = 0;
        num? clientX;
        try {
          deltaY = (data['deltaY'] is num) ? data['deltaY'] as num : 0;
          clientX = (data['clientX'] is num) ? data['clientX'] as num : null;
        } catch (_) {}

        debugPrint(
            '[WaveformPanel] shift_wheel received deltaY=$deltaY clientX=$clientX');

        // Immediately call JS force repaint before processing
        _callJsForceRepaint();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          // Ensure focus is restored - focus can be lost when modifier keys are used
          if (!_focusNode.hasFocus) {
            _focusNode.requestFocus();
          }

          final RenderBox box = context.findRenderObject() as RenderBox;
          final focalX = (clientX != null)
              ? box.globalToLocal(Offset(clientX.toDouble(), 0)).dx
              : box.size.width / 2.0;
          if (deltaY > 0) {
            _zoomWithPreservedPosition(1.0 / 1.5, focalViewportX: focalX);
          } else if (deltaY < 0) {
            _zoomWithPreservedPosition(1.5, focalViewportX: focalX);
          }

          // Force repaint after zoom
          _callJsForceRepaint();
        });
      } else {
        // ignore other message types
      }
    } catch (e) {
      // ignore parsing errors
    }
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
    try {
      plat.removeWindowMessageListener(_onWindowMessage);
    } catch (_) {}
    super.dispose();
  }

  void _zoomIn() {
    _zoomWithPreservedPosition(1.5);
  }

  void _zoomOut() {
    _zoomWithPreservedPosition(1.0 / 1.5);
  }

  /// Force multiple frame updates to ensure the compositor presents the frame.
  /// This is necessary in embedded webviews where single frame requests may be deferred.
  void _forceMultipleFrameUpdates([int frames = 5]) {
    // Immediately call the JS force repaint before scheduling frames
    _callJsForceRepaint();
    _forceRepaintFrames = frames;
    _scheduleNextForceFrame();
  }

  void _scheduleNextForceFrame() {
    if (_forceRepaintFrames <= 0 || !mounted) return;
    _forceRepaintFrames--;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {}); // Trigger a rebuild
      // Call JS force repaint on each frame
      _callJsForceRepaint();
      try {
        final bgState = _backgroundKey.currentState as dynamic;
        bgState?.forceRepaint?.call();
      } catch (_) {}
      _scheduleNextForceFrame();
    });
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
          // Use animateTo with very short duration instead of jumpTo
          // This triggers the animation frame cycle which helps with WebView repaint
          _horizontalScrollController.animateTo(
            finalNewOffset,
            duration: const Duration(milliseconds: 1),
            curve: Curves.linear,
          );
          // Force multiple frame updates to ensure repaint in embedded webviews
          _forceMultipleFrameUpdates();
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
        // Use animateTo with very short duration instead of jumpTo
        // This triggers the animation frame cycle which helps with WebView repaint
        _horizontalScrollController.animateTo(
          finalNewOffset,
          duration: const Duration(milliseconds: 1),
          curve: Curves.linear,
        );
        // Force multiple frame updates to ensure repaint in embedded webviews
        _forceMultipleFrameUpdates();
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
    _horizontalScrollController.animateTo(
      (offset - panStep)
          .clamp(0.0, _horizontalScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
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

  /// Navigate to the next or previous data point in the focused signal.
  /// Scrolls horizontally to center the data point and sets the marker to that time.
  /// Re-entrant calls are ignored to prevent hang when key is held down repeatedly.
  void _navigateToNextDataPoint({required bool isNext}) {
    // Prevent re-entrant calls during the same event processing (key repeat)
    if (_navigationInProgress) return;

    try {
      _navigationInProgress = true;

      final signalState = context.read<SignalBloc>().state;
      final focusedSignal = signalState.focusedSignal;

      if (focusedSignal == null || focusedSignal.data.isEmpty) {
        _navigationInProgress = false;
        return;
      }

      // Use the last navigation target time if available (BLoC updates are async),
      // otherwise read from the current BLoC state
      final currentMarkerTime = _lastNavigationTargetTime ??
          context.read<WaveformModuleBloc>().state.timePs;

      // Get the next or previous data point index from current marker time
      final nextIndex = isNext
          ? focusedSignal.getNextDataPointIndex(currentMarkerTime)
          : focusedSignal.getPreviousDataPointIndex(currentMarkerTime);

      if (nextIndex == -1) {
        _navigationInProgress = false;
        return; // No next/previous data point
      }

      final nextData = focusedSignal.data[nextIndex];
      final nextTime = nextData.time;

      // Track the target time locally since BLoC updates are async
      _lastNavigationTargetTime = nextTime;

      // 1. Update the marker to the new data point time
      context.read<WaveformModuleBloc>().add(WaveformModuleOnTap(nextTime));

      // 2. Scroll horizontally to center the data point in the viewport
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToCenterDataPoint(nextTime);
          _focusNode.requestFocus();
        }
      });

      // Clear flag immediately so next press can proceed
      // (The BLoC update happens asynchronously, so by the time the user
      // presses the key again, the marker will have been updated)
      _navigationInProgress = false;
    } catch (e) {
      _navigationInProgress = false;
    }
  }

  /// Scrolls horizontally to center a data point at the given time in the viewport.
  void _scrollToCenterDataPoint(int timePs) {
    if (!_horizontalScrollController.hasClients) return;

    // Get waveform parameters from RohdModuleBloc
    final rohdState = context.read<RohdModuleBloc>().state;
    final endTime = rohdState.moduleStructure.metadata.endTime;
    final timescale = endTime > 0 ? endTime : 20;

    // timescale and timePs used below

    // Use ABSOLUTE time mapping (same as cursor drawing and waveform painters):
    // contentX = leftOffset + (time / timescale) * drawingContentWidth
    // where drawingContentWidth = contentWidth - leftOffset - rightPadding
    //       contentWidth = screenWidth * zoomLevel
    //
    // To center the marker in the viewport:
    // viewportX = contentX - scrollOffset
    // We want viewportX = screenWidth / 2
    // Therefore: scrollOffset = contentX - screenWidth / 2

    // Use the actual viewport width from LayoutBuilder, not MediaQuery
    // MediaQuery includes the full screen, but the actual scrollable area may be narrower
    final double screenWidth =
        _lastActualWidth ?? MediaQuery.of(context).size.width;
    final double contentWidth = screenWidth * _zoomLevel;
    const double leftOffset = 32.0; // waveformLeftOffset
    const double rightPadding = 32.0;
    final double drawingContentWidth = contentWidth - leftOffset - rightPadding;

    // Calculate content X position using absolute mapping
    final double contentX = leftOffset +
        (timePs.toDouble() / timescale.toDouble()) * drawingContentWidth;

    // Calculate scroll offset to center the marker at screenWidth / 2
    final double desiredScrollOffset = contentX - (screenWidth / 2.0);

    final double maxScrollExtent =
        _horizontalScrollController.position.maxScrollExtent;
    final clampedOffset = desiredScrollOffset.clamp(
      0.0,
      maxScrollExtent,
    );

    _horizontalScrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    // Key events handled without verbose logging
    if (event is KeyDownEvent) {
      _pressedKeys.add(event.logicalKey);

      // Check if a signal is focused for data-point navigation
      final signalState = context.read<SignalBloc>().state;
      final isFocused = signalState.focusedSignal != null;
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (isFocused) {
          _navigateToNextDataPoint(isNext: false);
        } else {
          _panLeft();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (isFocused) {
          _navigateToNextDataPoint(isNext: true);
        } else {
          _panRight();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _scrollUp();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _scrollDown();
      } else if ((_pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
              _pressedKeys.contains(LogicalKeyboardKey.shiftRight)) &&
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // Shift+Up = zoom in
        _zoomIn();
      } else if ((_pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
              _pressedKeys.contains(LogicalKeyboardKey.shiftRight)) &&
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
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(event.logicalKey);
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
      // If Shift is held: zoom (existing behavior). Otherwise, use
      // mouse wheel to pan horizontally (scroll up -> pan left, scroll down -> pan right).
      final bool shiftPressed = _isShiftPressed();

      final scrollDelta = event.scrollDelta.dy;

      // Debug logging to confirm events reach Flutter
      try {
        debugPrint(
            '[WaveformPanel] PointerScrollEvent deltaY=$scrollDelta shift=$shiftPressed');
      } catch (_) {}

      // Determine mouse position relative to viewport (used for zoom focal point)
      final RenderBox box = context.findRenderObject() as RenderBox;
      final local = box.globalToLocal(event.position);
      final focalX = local.dx; // viewport-local X

      if (shiftPressed) {
        // Shift+wheel = zoom in/out
        if (scrollDelta > 0) {
          _zoomWithPreservedPosition(1.0 / 1.5, focalViewportX: focalX);
        } else if (scrollDelta < 0) {
          _zoomWithPreservedPosition(1.5, focalViewportX: focalX);
        }
      } else {
        // Wheel without Shift -> horizontal pan. Use a pan fraction so
        // the amount is intuitive regardless of viewport size.
        try {
          if (!_horizontalScrollController.hasClients) return;
          final double viewportWidth = _lastActualWidth ?? box.size.width;
          // Pan by 10% of viewport width per wheel notch; direction: up -> left
          final double panStep = viewportWidth * 0.10;
          final double currentOffset = _horizontalScrollController.offset;
          final double maxExtent =
              _horizontalScrollController.position.maxScrollExtent;

          // PointerScrollEvent dy is typically positive when scrolling down
          final bool scrollDown = scrollDelta > 0;
          final double newOffset =
              (currentOffset + (scrollDown ? panStep : -panStep))
                  .clamp(0.0, maxExtent);
          _horizontalScrollController.jumpTo(newOffset);
          // Update tracked offset as well
          _trackedScrollOffset = newOffset;
        } catch (e) {
          // ignore
        }
      }
    }
  }

  /// Returns true if either Shift key is currently pressed according to
  /// the platform keyboard state. This is more reliable for pointer event
  /// handling than local KeyDown/KeyUp tracking which can miss events.
  bool _isShiftPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final bool rawHas = keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
    if (rawHas) return true;

    // Fallback: consult JS tracker if available (useful inside VS Code WebView
    // where modifier key events may sometimes be intercepted by the host).
    try {
      return plat.isShiftDownFromJs();
    } catch (e) {
      return false;
    }
  }

  /// Returns true if either Control key is currently pressed.
  /// Used for Ctrl+drag panning.
  bool _isCtrlPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);
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
                          // Capture pointer signals (wheel) but defer other pointer
                          // events to child so widgets like the Scrollbar can receive
                          // pointer down/drag events.
                          behavior: HitTestBehavior.deferToChild,
                          onPointerSignal: (event) {
                            _handleScroll(event, context);
                          },
                          onPointerDown: (event) {
                            // When the user presses down while holding Ctrl, suppress
                            // the default scroll physics so our custom onPan handlers
                            // can manage panning. We check the current keyboard
                            // state directly to be resilient to missed key events.
                            final bool ctrlPressed = _isCtrlPressed();
                            if (ctrlPressed && !_suppressScrollPhysics) {
                              setState(() {
                                _suppressScrollPhysics = true;
                              });
                            }
                          },
                          onPointerUp: (event) {
                            if (_suppressScrollPhysics) {
                              setState(() {
                                _suppressScrollPhysics = false;
                              });
                            }
                          },
                          child: ScrollConfiguration(
                            behavior: _buildCustomScrollBehavior(context),
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
                                  // Allow normal scroll physics (so the scrollbar is draggable)
                                  // unless we're intentionally suppressing them for Ctrl+drag
                                  // custom panning.
                                  physics: _suppressScrollPhysics
                                      ? const NeverScrollableScrollPhysics()
                                      : const ClampingScrollPhysics(),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.deferToChild,
                                    onTap: () {
                                      // Request focus when tapped so keyboard events work
                                      _focusNode.requestFocus();
                                    },
                                    onPanStart: (details) {
                                      _focusNode.requestFocus();
                                      // Only start mouse panning when Control key is held.
                                      final bool ctrlPressed = _isCtrlPressed();
                                      if (ctrlPressed) {
                                        setState(() {
                                          _isMousePanning = true;
                                          _lastPanPosition =
                                              details.globalPosition;
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
                                      if (_verticalScrollController
                                          .hasClients) {
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
                                    child: SizedBox(
                                      width: zoomedWidth,
                                      height: screenHeight -
                                          50, // Subtract timescale height
                                      child: WaveformBackground(
                                        // Key uses actual width only so the background State
                                        // is preserved when `_zoomLevel` changes.
                                        key: _backgroundKey,
                                        timescale: timescale,
                                        verticalScrollController:
                                            _verticalScrollController,
                                        zoomLevel: _zoomLevel,
                                        horizontalScrollController:
                                            _horizontalScrollController,
                                        screenWidth: actualWidth,
                                        isCtrlPressed: _isCtrlPressed,
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
