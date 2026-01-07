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
      super.timescale = 0,
      super.repaint});

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

    // Detect if this signal contains multi-bit (non-binary) values.
    bool hasMultiValue = false;
    for (final d in waveform) {
      final v = d.value.toLowerCase();
      if (v.contains('x') || v.contains('z')) continue;
      final parsed = int.tryParse(d.value);
      if (parsed == null) continue;
      if (parsed != 0 && parsed != 1) {
        hasMultiValue = true;
        break;
      }
    }

    // If no multi-values found, keep the old binary drawing behavior
    if (!hasMultiValue) {
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
      return;
    }

    // Multi-value rendering: two parallel rails crossing at transitions
    final Path greenTop = Path();
    final Path greenBottom = Path();
    final Path xValPath = Path();
    final Path zValPath = Path();

    // Map binary values to exact Y positions so rails match 0/1 positions
    double yForBinary(String value) {
      if (value.toLowerCase().contains('x') ||
          value.toLowerCase().contains('z')) {
        return size.height / 2;
      }
      try {
        return size.height * (1 - int.parse(value));
      } catch (e) {
        return size.height;
      }
    }

    final double topY = yForBinary('1');
    final double bottomY = yForBinary('0');

    // Start at left with initial value at or before time 0
    String currentValue = getValueAtOrBeforeTime(waveform, 0) ?? '0';
    bool side = true; // top rail initially corresponds to the 'high' position

    greenTop.moveTo(left, topY);
    greenBottom.moveTo(left, bottomY);

    // Iterate through transitions building rails; we assume waveform is ordered
    for (final data in waveform) {
      if (data.time < 0) continue;
      if (data.time > effectiveTimescale) break;

      final double x = left + data.time * pxPerTime;
      final lower = data.value.toLowerCase();

      if (lower.contains('x')) {
        xValPath.moveTo(x, size.height / 2);
        xValPath.lineTo(x, size.height / 2);
        currentValue = data.value;
        continue;
      }
      if (lower.contains('z')) {
        zValPath.moveTo(x, size.height / 2);
        zValPath.lineTo(x, size.height / 2);
        currentValue = data.value;
        continue;
      }

      if (data.value != currentValue) {
        // Center a symmetric crossing on transition time x.
        const double connector = 12.0; // total width of crossing in pixels
        const double half = connector / 2.0;

        // horizontal to start of crossing
        greenTop.lineTo(x - half, side ? topY : bottomY);
        greenBottom.lineTo(x - half, side ? bottomY : topY);

        // diagonal across to other rail ending at x + half
        // Use a cubic Bezier for a smooth crossing centered at x
        const cpOffset = half / 2.0;
        final p0Top = Offset(x - half, side ? topY : bottomY);
        final p1Top = Offset(x - half + cpOffset, side ? topY : bottomY);
        final p2Top = Offset(x + half - cpOffset, side ? bottomY : topY);
        final p3Top = Offset(x + half, side ? bottomY : topY);

        final p0Bottom = Offset(x - half, side ? bottomY : topY);
        final p1Bottom = Offset(x - half + cpOffset, side ? bottomY : topY);
        final p2Bottom = Offset(x + half - cpOffset, side ? topY : bottomY);
        final p3Bottom = Offset(x + half, side ? topY : bottomY);

        final topPathSegment = Path()
          ..moveTo(p0Top.dx, p0Top.dy)
          ..cubicTo(p1Top.dx, p1Top.dy, p2Top.dx, p2Top.dy, p3Top.dx, p3Top.dy);
        greenTop.addPath(topPathSegment, Offset.zero);

        final bottomPathSegment = Path()
          ..moveTo(p0Bottom.dx, p0Bottom.dy)
          ..cubicTo(p1Bottom.dx, p1Bottom.dy, p2Bottom.dx, p2Bottom.dy,
              p3Bottom.dx, p3Bottom.dy);
        greenBottom.addPath(bottomPathSegment, Offset.zero);

        side = !side;

        // continue slightly after crossing to stabilize the line
        greenTop.lineTo(x + half + 1, side ? topY : bottomY);
        greenBottom.lineTo(x + half + 1, side ? bottomY : topY);
      } else {
        greenTop.lineTo(x, side ? topY : bottomY);
        greenBottom.lineTo(x, side ? bottomY : topY);
      }

      currentValue = data.value;
    }

    // finish to right edge
    final double rightEdgeX = left + drawingWidth;
    greenTop.lineTo(rightEdgeX, side ? topY : bottomY);
    greenBottom.lineTo(rightEdgeX, side ? bottomY : topY);

    canvas.drawPath(greenTop, greenPaint);
    canvas.drawPath(greenBottom, greenPaint);
    canvas.drawPath(xValPath, redPaint);
    canvas.drawPath(zValPath, orangePaint);

    // Paint centered labels for stable intervals similar to hexavalue painter
    const textStyle = TextStyle(color: Colors.green, fontSize: 12);
    final intervals = <Map<String, dynamic>>[];
    int curStart = 0;
    String curVal = getValueAtOrBeforeTime(waveform, 0) ?? '0';
    for (final d in waveform) {
      if (d.time < 0) continue;
      if (d.time > effectiveTimescale) break;
      final int t = d.time;
      if (t > curStart) {
        intervals.add({'start': curStart, 'end': t, 'value': curVal});
      }
      curStart = t;
      curVal = d.value;
    }
    if (curStart < effectiveTimescale) {
      intervals
          .add({'start': curStart, 'end': effectiveTimescale, 'value': curVal});
    }

    for (final it in intervals) {
      final int s = it['start'];
      final int e = it['end'];
      final String v = it['value'];
      if (s >= e) continue;
      final double sx = left + s * (drawingWidth / effectiveTimescale);
      final double ex = left + e * (drawingWidth / effectiveTimescale);
      final double centerX = (sx + ex) / 2.0;
      final tp = TextPainter(
          text: TextSpan(text: '0x$v', style: textStyle),
          textDirection: TextDirection.ltr);
      tp.layout();
      final double available = ex - sx - 4.0;
      if (tp.width <= available) {
        final double textY = (topY + bottomY) / 2 - tp.height / 2;
        final double drawX = centerX - tp.width / 2;
        if (drawX + tp.width >= left && drawX <= left + drawingWidth) {
          tp.paint(canvas,
              Offset(drawX.clamp(left, left + drawingWidth - tp.width), textY));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant WaveformBinary oldDelegate) {
    // Repaint if any rendering parameters have changed
    return oldDelegate.waveform != waveform ||
        oldDelegate.finalTime != finalTime ||
        oldDelegate.startTime != startTime ||
        oldDelegate.leftOffset != leftOffset ||
        oldDelegate.viewportWidth != viewportWidth ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.timescale != timescale;
  }
}
