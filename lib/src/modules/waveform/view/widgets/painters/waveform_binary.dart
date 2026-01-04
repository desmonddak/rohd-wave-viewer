// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// waveform_binary.dart
// Paints the binary waveform.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:flutter/material.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/view/widgets/painters/waveform.dart';
import 'package:rohd_wave_viewer/src/const/layout.dart';
// module_structure_api types used via Waveform base; no direct imports needed here

class WaveformBinary extends Waveform {
  WaveformBinary(super.waveform, super.finalTime, super.startTime,
      {super.leftOffset = waveformLeftOffset,
      super.viewportWidth = 0.0,
      super.scrollOffset = 0.0,
      super.timescale = 0});

  @override
  void paint(Canvas canvas, Size size) {
    // Removed debug logging from paint
    // Log waveform data range
    // waveform metadata logging removed

    if (waveform.isEmpty || size.width <= 0) return;

    // Use the instance leftOffset (caller may pass a scaled offset)
    final double left = leftOffset;

    // Reserve a right padding equal to the left offset (symmetric)
    final double rightPadding = left;

    // Use ABSOLUTE time mapping: the canvas (size.width = contentWidth) represents the full timescale.
    // Time 0 maps to x = leftOffset
    // Time timescale maps to x = size.width - rightPadding
    // This ensures waveform positions are consistent regardless of zoom/scroll.
    final int effectiveTimescale = (timescale > 0) ? timescale : finalTime;
    if (effectiveTimescale <= 0) return;

    final double drawingWidth = size.width - left - rightPadding;
    final double pxPerTime = drawingWidth / effectiveTimescale;

    // Draw waveform by iterating through actual data transitions
    // This avoids sampling aliasing that occurs when pixel rate matches clock rate
    final binValPath = Path();
    final xValPath = Path();
    final zValPath = Path();

    double? prevX;
    double? prevY;

    // Find the starting value (value at or before time 0)
    String currentValue = getValueAtOrBeforeTime(waveform, 0) ?? '0';

    // Calculate Y position for a value
    double yForValue(String value) {
      if (value.toLowerCase().contains('x') ||
          value.toLowerCase().contains('z')) {
        return size.height / 2; // Middle for X/Z
      } else {
        try {
          return size.height * (1 - int.parse(value));
        } catch (e) {
          return size.height; // Bottom for parse errors
        }
      }
    }

    // Start from x=left with the initial value (aligns with timescale)
    double startX = left;
    double startY = yForValue(currentValue);
    binValPath.moveTo(startX, startY);
    prevX = startX;
    prevY = startY;

    // Iterate through ALL data points (absolute mapping means we draw the full waveform)
    for (final data in waveform) {
      // Skip points with negative time
      if (data.time < 0) continue;
      // Stop after timescale
      if (data.time > effectiveTimescale) break;

      // Calculate x position using absolute time mapping
      final double x = left + data.time * pxPerTime;
      final double y = yForValue(data.value);

      // Draw horizontal line from previous position to this x (at previous y level)
      if (prevX != null && prevY != null) {
        binValPath.lineTo(x, prevY);
      }

      // Draw vertical transition to new value
      binValPath.lineTo(x, y);

      prevX = x;
      prevY = y;
    }

    // Draw final horizontal line to the right edge of the drawing region
    if (prevY != null) {
      final double rightEdgeX = left + drawingWidth;
      binValPath.lineTo(rightEdgeX, prevY);
    }

    canvas.drawPath(binValPath, greenPaint);
    canvas.drawPath(xValPath, redPaint);
    canvas.drawPath(zValPath, orangePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
