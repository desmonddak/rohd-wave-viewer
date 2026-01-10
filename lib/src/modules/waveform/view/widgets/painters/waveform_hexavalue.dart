// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// waveform_hexavalue.dart
// Paints the waveform with hexadecimal values.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:flutter/material.dart';
import 'waveform.dart' show Waveform;
import 'package:rohd_wave_viewer/src/const/const.dart';

class WaveformHexaValue extends Waveform {
  WaveformHexaValue(
    super.waveform,
    super.finalTime,
    super.startTime, {
    super.signalWidth,
    super.leftOffset = waveformLeftOffset,
    super.viewportWidth = 0.0,
    super.scrollOffset = 0.0,
    super.timescale = 0,
    this.useBezierCrossings = true,
    super.repaint,
  });

  final bool useBezierCrossings;

  @override
  void paint(Canvas canvas, Size size) {
    // Removed paint debug logging
    // Use the instance leftOffset passed by the caller (may already be scaled)
    final double left = leftOffset;
    final double rightPadding = left;
    final double drawingWidth = (size.width - left - rightPadding).clamp(
      0.0,
      double.infinity,
    );

    // Use ABSOLUTE time mapping: the canvas represents the full timescale.
    final int effectiveTimescale = (timescale > 0) ? timescale : finalTime;
    if (effectiveTimescale <= 0 || drawingWidth <= 0) return;

    // We draw within the inner drawing region (excluding left/right padding)
    // We'll render multi-bit (hex) values as two parallel green lines with
    // the textual value between them. On transitions the two lines cross so
    // the visual encoding switches sides while remaining parallel.

    final double pxPerTime = drawingWidth / effectiveTimescale;

    // Map binary/multi-bit values to exact Y positions so rails match 0/1 positions
    double yForBinary(String value) {
      try {
        return size.height * (1 - int.parse(value));
      } catch (e) {
        // Non-scalar values map to top by default to keep rails symmetric.
        return 0.0;
      }
    }

    final double topY = yForBinary('1');
    final double bottomY = yForBinary('0');

    final Path greenTop = Path();
    final Path greenBottom = Path();

    // Adaptive connector width based on current zoom (px per time)
    const double baseConnectorPx = 12.0;
    const double minConnectorPx = 4.0;
    final double connector = (baseConnectorPx * pxPerTime).clamp(
      minConnectorPx,
      baseConnectorPx,
    );
    final double half = connector / 2.0;

    // Build value-change segments [start, end) across the visible timescale.
    final List<_HexSegment> segments = [];
    String currentValue = getValueAtOrBeforeTime(waveform, 0) ?? '0';
    int lastTime = 0;
    for (final data in waveform) {
      if (data.time < 0) continue;
      if (data.time > effectiveTimescale) break;
      if (data.value == currentValue) continue;
      segments.add(
        _HexSegment(start: lastTime, end: data.time, value: currentValue),
      );
      lastTime = data.time;
      currentValue = data.value;
    }
    if (lastTime < effectiveTimescale) {
      segments.add(
        _HexSegment(
          start: lastTime,
          end: effectiveTimescale,
          value: currentValue,
        ),
      );
    }

    if (segments.isEmpty) return;

    final double centerY = (topY + bottomY) / 2;
    bool side = true; // flips at each segment boundary

    void drawSegment(_HexSegment s, Paint paint) {
      final double startX = left + s.start * pxPerTime;
      final double endX = left + s.end * pxPerTime;
      if (endX <= startX) return;

      final double segLen = endX - startX;
      final double ramp = (segLen / 2).clamp(0.0, half);
      final double cp = ramp / 2.0;

      final double topRail = side ? topY : bottomY;
      final double bottomRail = side ? bottomY : topY;

      final Path topPath = Path();
      final Path bottomPath = Path();

      // Top half
      topPath.moveTo(startX, centerY);
      if (useBezierCrossings && ramp > 0) {
        topPath.cubicTo(
          startX + cp,
          centerY,
          startX + ramp - cp,
          topRail,
          startX + ramp,
          topRail,
        );
      } else {
        topPath.lineTo(startX + ramp, topRail);
      }
      topPath.lineTo(endX - ramp, topRail);
      if (useBezierCrossings && ramp > 0) {
        topPath.cubicTo(
          endX - ramp + cp,
          topRail,
          endX - cp,
          centerY,
          endX,
          centerY,
        );
      } else {
        topPath.lineTo(endX, centerY);
      }

      // Bottom half
      bottomPath.moveTo(startX, centerY);
      if (useBezierCrossings && ramp > 0) {
        bottomPath.cubicTo(
          startX + cp,
          centerY,
          startX + ramp - cp,
          bottomRail,
          startX + ramp,
          bottomRail,
        );
      } else {
        bottomPath.lineTo(startX + ramp, bottomRail);
      }
      bottomPath.lineTo(endX - ramp, bottomRail);
      if (useBezierCrossings && ramp > 0) {
        bottomPath.cubicTo(
          endX - ramp + cp,
          bottomRail,
          endX - cp,
          centerY,
          endX,
          centerY,
        );
      } else {
        bottomPath.lineTo(endX, centerY);
      }

      canvas.drawPath(topPath, paint);
      canvas.drawPath(bottomPath, paint);
    }

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final lower = seg.value.toLowerCase();
      Paint segPaint = greenPaint;
      if (lower.contains('x')) {
        segPaint = redPaint;
      } else if (lower.contains('z')) {
        segPaint = yellowPaint;
      }
      drawSegment(seg, segPaint);
      if (i < segments.length - 1) side = !side;
    }

    // After constructing paths, paint centered labels for each stable interval
    // Build intervals from waveform transitions (clamped to [0, effectiveTimescale])
    const textStyle = TextStyle(color: Colors.green, fontSize: 12);
    final intervals = <Map<String, dynamic>>[];
    // starting time
    int curStart = 0;
    String curVal = getValueAtOrBeforeTime(waveform, 0) ?? '0';
    for (final d in waveform) {
      if (d.time < 0) continue;
      if (d.time > effectiveTimescale) break;
      final int t = d.time;
      // interval is [curStart, t)
      if (t > curStart) {
        intervals.add({'start': curStart, 'end': t, 'value': curVal});
      }
      curStart = t;
      curVal = d.value;
    }
    // last interval to end
    if (curStart < effectiveTimescale) {
      intervals.add({
        'start': curStart,
        'end': effectiveTimescale,
        'value': curVal,
      });
    }

    for (final it in intervals) {
      final int s = it['start'];
      final int e = it['end'];
      final String v = it['value'];
      if (s >= e) continue;
      final String label = formatValueAsHexLabel(v);
      final double sx = left + s * (drawingWidth / effectiveTimescale);
      final double ex = left + e * (drawingWidth / effectiveTimescale);
      final double centerX = (sx + ex) / 2.0;
      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      final double available = ex - sx - 4.0; // small padding
      if (tp.width <= available) {
        final double textY = (topY + bottomY) / 2 - tp.height / 2;
        final double drawX = centerX - tp.width / 2;
        // Clip to drawing region
        if (drawX + tp.width >= left && drawX <= left + drawingWidth) {
          tp.paint(
            canvas,
            Offset(drawX.clamp(left, left + drawingWidth - tp.width), textY),
          );
        }
      }
    }

    canvas.drawPath(greenTop, greenPaint);
    canvas.drawPath(greenBottom, greenPaint);
  }

  @override
  bool shouldRepaint(covariant WaveformHexaValue oldDelegate) {
    // Repaint if any rendering parameters have changed
    return oldDelegate.waveform != waveform ||
        oldDelegate.finalTime != finalTime ||
        oldDelegate.startTime != startTime ||
        oldDelegate.leftOffset != leftOffset ||
        oldDelegate.viewportWidth != viewportWidth ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.timescale != timescale ||
        oldDelegate.useBezierCrossings != useBezierCrossings;
  }
}

class _HexSegment {
  const _HexSegment({
    required this.start,
    required this.end,
    required this.value,
  });
  final int start;
  final int end;
  final String value;
}
