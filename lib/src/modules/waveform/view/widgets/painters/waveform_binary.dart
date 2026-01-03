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
      super.scrollOffset = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    // Removed debug logging from paint
    // Log waveform data range
    // waveform metadata logging removed

    if (waveform.isEmpty || size.width <= 0 || finalTime <= 0) return;

    // Use the instance leftOffset (caller may pass a scaled offset)
    final double left = leftOffset;

    // Reserve a right padding equal to the left offset (symmetric)
    final double rightPadding = left;

    // Calculate pixels per time unit for mapping time -> x position.
    // Use the viewport width (visible area) to compute pxPerTime so the
    // painter's visible slice aligns exactly with the timescale. Then add
    // `scrollOffset` to translate positions into content coordinates.
    final double effectiveViewport =
        (viewportWidth > 0.0) ? viewportWidth : size.width;
    final double drawingWidth =
        (effectiveViewport - left - rightPadding).clamp(0.0, double.infinity);
    final double pxPerTime = drawingWidth / finalTime;

    // Draw waveform by iterating through actual data transitions
    // This avoids sampling aliasing that occurs when pixel rate matches clock rate
    final binValPath = Path();
    final xValPath = Path();
    final zValPath = Path();

    double? prevX;
    double? prevY;

    // Find the starting value (value at or before startTime)
    String currentValue = getValueAtOrBeforeTime(waveform, startTime) ?? '0';

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

    // Iterate through all data points that fall within our visible range
    final int endTime = startTime + finalTime;

    for (final data in waveform) {
      // Skip points before our visible range
      if (data.time < startTime) continue;
      // Stop after our visible range
      if (data.time > endTime) break;

      // Calculate x position for this transition (add leftOffset to align with timescale)
      final double x =
          scrollOffset + leftOffset + (data.time - startTime) * pxPerTime;
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
      final double rightEdgeX = scrollOffset + left + drawingWidth;
      binValPath.lineTo(rightEdgeX, prevY);
    }

    canvas.drawPath(binValPath, greenPaint);
    canvas.drawPath(xValPath, redPaint);
    canvas.drawPath(zValPath, orangePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
