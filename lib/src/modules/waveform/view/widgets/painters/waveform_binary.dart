// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// waveform_binary.dart
// Paints the binary waveform.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/view/widgets/painters/waveform.dart';

class WaveformBinary extends Waveform {
  WaveformBinary(super.waveform, super.finalTime, super.startTime);

  @override
  void paint(Canvas canvas, Size size) {
    // Removed debug logging from paint
    // Log waveform data range
    // waveform metadata logging removed

    if (waveform.isEmpty || size.width <= 0 || finalTime <= 0) return;

    // Match the 8-pixel left offset used by TimescalePainter for label positioning
    const double leftOffset = 8.0;

    // Calculate pixels per time unit for mapping time -> x position
    // Account for the left offset in the available drawing width
    final double drawingWidth = size.width - leftOffset;
    final double pxPerTime = drawingWidth / finalTime;

    // Draw waveform by iterating through actual data transitions
    // This avoids sampling aliasing that occurs when pixel rate matches clock rate
    final binValPath = Path();
    final xValPath = Path();
    final zValPath = Path();

    int transitionCount = 0;
    String? prevValue;
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

    // Start from x=leftOffset with the initial value (aligns with timescale)
    double startX = leftOffset;
    double startY = yForValue(currentValue);
    binValPath.moveTo(startX, startY);
    prevX = startX;
    prevY = startY;
    prevValue = currentValue;

    // Iterate through all data points that fall within our visible range
    final int endTime = startTime + finalTime;

    for (final data in waveform) {
      // Skip points before our visible range
      if (data.time < startTime) continue;
      // Stop after our visible range
      if (data.time > endTime) break;

      // Calculate x position for this transition (add leftOffset to align with timescale)
      final double x = leftOffset + (data.time - startTime) * pxPerTime;
      final double y = yForValue(data.value);

      // Draw horizontal line from previous position to this x (at previous y level)
      if (prevX != null && prevY != null) {
        binValPath.lineTo(x, prevY!);
      }

      // Draw vertical transition to new value
      binValPath.lineTo(x, y);

      if (prevValue != null && prevValue != data.value) {
        transitionCount++;
      }

      prevX = x;
      prevY = y;
      prevValue = data.value;
    }

    // Draw final horizontal line to end of canvas
    if (prevY != null) {
      binValPath.lineTo(size.width, prevY!);
    }

    canvas.drawPath(binValPath, greenPaint);
    canvas.drawPath(xValPath, redPaint);
    canvas.drawPath(zValPath, orangePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
