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
  WaveformHexaValue(super.waveform, super.finalTime, super.startTime,
      {super.signalWidth,
      super.leftOffset = waveformLeftOffset,
      super.viewportWidth = 0.0,
      super.scrollOffset = 0.0,
      super.timescale = 0,
      super.repaint});

  @override
  void paint(Canvas canvas, Size size) {
    // Removed paint debug logging
    // Use the instance leftOffset passed by the caller (may already be scaled)
    final double left = leftOffset;
    final double rightPadding = left;
    final double drawingWidth =
        (size.width - left - rightPadding).clamp(0.0, double.infinity);

    // Use ABSOLUTE time mapping: the canvas represents the full timescale.
    final int effectiveTimescale = (timescale > 0) ? timescale : finalTime;
    if (effectiveTimescale <= 0 || drawingWidth <= 0) return;

    const space = 3;

    // placeholders kept for compatibility; topPath/bottomPath not used in this painter
    // final topPath = Path();
    // final bottomPath = Path();

    final xPathTop = Path();
    final xPathBottom = Path();

    final zPathTop = Path();
    final zPathBottom = Path();

    // We draw within the inner drawing region (excluding left/right padding)
    // We'll render multi-bit (hex) values as two parallel green lines with
    // the textual value between them. On transitions the two lines cross so
    // the visual encoding switches sides while remaining parallel.
    final int widthPx = drawingWidth.ceil();

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

    String? prevValue;
    bool firstPoint = true;

    // side==true means greenTop corresponds to the visual top line for the
    // current value (left side of text); when crossing we flip this flag.
    bool side = true;

    final Path greenTop = Path();
    final Path greenBottom = Path();

    for (int px = 0; px < widthPx; px++) {
      final int timeAtPx = ((px / drawingWidth) * effectiveTimescale).round();
      final value =
          getValueAtOrBeforeTime(waveform, timeAtPx) ?? prevValue ?? '0';
      final double x = left + px.toDouble();

      final lower = value.toLowerCase();

      if (firstPoint) {
        if (lower.contains('x')) {
          xPathTop.moveTo(x - space, topY);
          xPathBottom.moveTo(x - space, bottomY);
        } else if (lower.contains('z')) {
          zPathTop.moveTo(x - space, topY);
          zPathBottom.moveTo(x - space, bottomY);
        } else {
          greenTop.moveTo(x - space, topY);
          greenBottom.moveTo(x - space, bottomY);
        }
        prevValue = value;
        firstPoint = false;
      }

      if (lower.contains('x')) {
        xPathTop.lineTo(x, topY);
        xPathBottom.lineTo(x, bottomY);
        prevValue = value;
        continue;
      } else if (lower.contains('z')) {
        zPathTop.lineTo(x, topY);
        zPathBottom.lineTo(x, bottomY);
        prevValue = value;
        continue;
      }

      if (value != prevValue) {
        // Center a symmetric crossing on transition time x.
        const double connector = 12.0;
        const double half = connector / 2.0;

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

        greenTop.lineTo(x + half + 1, side ? topY : bottomY);
        greenBottom.lineTo(x + half + 1, side ? bottomY : topY);
      } else {
        greenTop.lineTo(x, side ? topY : bottomY);
        greenBottom.lineTo(x, side ? bottomY : topY);
      }

      prevValue = value;
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
      final double available = ex - sx - 4.0; // small padding
      if (tp.width <= available) {
        final double textY = (topY + bottomY) / 2 - tp.height / 2;
        final double drawX = centerX - tp.width / 2;
        // Clip to drawing region
        if (drawX + tp.width >= left && drawX <= left + drawingWidth) {
          tp.paint(canvas,
              Offset(drawX.clamp(left, left + drawingWidth - tp.width), textY));
        }
      }
    }

    final double rightEdgeX = left + drawingWidth;
    greenTop.lineTo(rightEdgeX, side ? topY : bottomY);
    greenBottom.lineTo(rightEdgeX, side ? bottomY : topY);

    canvas.drawPath(greenTop, greenPaint);
    canvas.drawPath(greenBottom, greenPaint);

    canvas.drawPath(xPathTop, redPaint);
    canvas.drawPath(xPathBottom, redPaint);

    canvas.drawPath(zPathTop, orangePaint);
    canvas.drawPath(zPathBottom, orangePaint);
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
        oldDelegate.timescale != timescale;
  }
}
