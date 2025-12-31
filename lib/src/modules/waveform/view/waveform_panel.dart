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
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rohd_wave_viewer/src/modules/rohd_module/bloc/rohd_module_bloc.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/view/widgets/waveform_background.dart';

class WaveformPanel extends StatefulWidget {
  const WaveformPanel({super.key});

  @override
  State<WaveformPanel> createState() => _WaveformPanelState();
}

class _WaveformPanelState extends State<WaveformPanel> {
  double _zoomLevel = 1.0;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  // Panning state
  bool _isPanning = false;
  Offset? _lastPanPosition;

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel * 1.5).clamp(0.1, 100.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel / 1.5).clamp(0.1, 100.0);
    });
  }

  void _resetZoom() {
    setState(() {
      _zoomLevel = 1.0;
    });
  }

  void _panLeft() {
    final offset = _scrollController.offset;
    final screenWidth = MediaQuery.of(context).size.width;
    final panStep = screenWidth * 0.1; // Pan 10% of screen width
    _scrollController.animateTo(
      (offset - panStep).clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _panRight() {
    final offset = _scrollController.offset;
    final screenWidth = MediaQuery.of(context).size.width;
    final panStep = screenWidth * 0.1;
    _scrollController.animateTo(
      (offset + panStep).clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _panLeft();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _panRight();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return BlocBuilder<RohdModuleBloc, RohdModuleState>(
        builder: (context, state) {
      // Get time range from metadata, default to 20 if not available
      final endTime = state.moduleStructure.metadata.endTime;
      final timescale = endTime > 0 ? endTime : 20;

      // Calculate zoomed width
      final zoomedWidth = screenWidth * _zoomLevel;

      return Stack(
        children: [
          KeyboardListener(
            focusNode: _focusNode,
            onKeyEvent: _handleKeyEvent,
            autofocus: true,
            child: GestureDetector(
              onPanStart: (details) {
                setState(() {
                  _isPanning = true;
                  _lastPanPosition = details.globalPosition;
                });
              },
              onPanUpdate: (details) {
                if (_isPanning && _lastPanPosition != null) {
                  final delta = _lastPanPosition!.dx - details.globalPosition.dx;
                  final newOffset = (_scrollController.offset + delta).clamp(
                    0.0,
                    _scrollController.position.maxScrollExtent,
                  );
                  _scrollController.jumpTo(newOffset);
                  _lastPanPosition = details.globalPosition;
                }
              },
              onPanEnd: (details) {
                setState(() {
                  _isPanning = false;
                  _lastPanPosition = null;
                });
              },
              child: Theme(
                data: Theme.of(context).copyWith(
                  scrollbarTheme: ScrollbarThemeData(
                    thumbColor: WidgetStateProperty.all(Colors.white),
                  ),
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: zoomedWidth,
                      height: height,
                      child: WaveformBackground(
                        timescale: timescale,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Zoom and Pan controls overlay
          Positioned(
            top: 10,
            right: 10,
            child: Card(
              color: Colors.black.withOpacity(0.7),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Zoom controls
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.zoom_out, color: Colors.white),
                          onPressed: _zoomOut,
                          tooltip: 'Zoom Out',
                        ),
                        Text(
                          '${(_zoomLevel * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(Icons.zoom_in, color: Colors.white),
                          onPressed: _zoomIn,
                          tooltip: 'Zoom In',
                        ),
                        IconButton(
                          icon: const Icon(Icons.restart_alt, color: Colors.white),
                          onPressed: _resetZoom,
                          tooltip: 'Reset Zoom',
                        ),
                      ],
                    ),
                    const Divider(color: Colors.grey, height: 1),
                    // Pan controls
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: _panLeft,
                          tooltip: 'Pan Left (←)',
                        ),
                        const Text(
                          'Pan',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward, color: Colors.white),
                          onPressed: _panRight,
                          tooltip: 'Pan Right (→)',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
