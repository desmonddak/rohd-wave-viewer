// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// waveform_hexavalue.dart
// Paints the waveform with hexadecimal values.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:flutter/material.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/view/widgets/painters/waveform.dart';
import 'package:rohd_wave_viewer/src/const/layout.dart';

class WaveformHexaValue extends Waveform {
  WaveformHexaValue(super.waveform, super.finalTime, super.startTime,
      {super.leftOffset = waveformLeftOffset,
      super.viewportWidth = 0.0,
      super.scrollOffset = 0.0,
      super.timescale = 0});

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

    final topPath = Path();
    final bottomPath = Path();

    final xPathTop = Path();
    final xPathBottom = Path();

    final zPathTop = Path();
    final zPathBottom = Path();

    // We draw within the inner drawing region (excluding left/right padding)
    final int widthPx = drawingWidth.ceil();
    String? prevSignal;

    for (int px = 0; px < widthPx; px++) {
      // Map pixel position to time using absolute mapping
      final int timeAtPx = ((px / drawingWidth) * effectiveTimescale).round();
      final value =
          getValueAtOrBeforeTime(waveform, timeAtPx) ?? prevSignal ?? '0';
      // Map px into actual content x by adding the left offset (no scrollOffset needed with absolute mapping)
      final double x = left + px.toDouble();
      const double posYTop = 0;
      final double posYBottom = size.height;

      // For simplicity draw solid regions based on value
      if (px == 0) {
        if (value.toLowerCase().contains('x')) {
          xPathTop.moveTo(x - space, posYTop);
          xPathBottom.moveTo(x - space, posYBottom);
        } else if (value.toLowerCase().contains('z')) {
          zPathTop.moveTo(x - space, posYTop);
          zPathBottom.moveTo(x - space, posYBottom);
        } else {
          topPath.moveTo(x - space, posYTop);
          bottomPath.moveTo(x - space, posYBottom);
        }
      }

      if (value.toLowerCase().contains('x')) {
        xPathTop.lineTo(x, posYTop);
        xPathBottom.lineTo(x, posYBottom);
      } else if (value.toLowerCase().contains('z')) {
        zPathTop.lineTo(x, posYTop);
        zPathBottom.lineTo(x, posYBottom);
      } else {
        topPath.lineTo(x, posYTop);
        bottomPath.lineTo(x, posYBottom);
      }

      prevSignal = value;
    }

    topPath.addPath(bottomPath, const Offset(0, 0));
    canvas.drawPath(topPath, greenPaint);

    canvas.drawPath(xPathTop, redPaint);
    canvas.drawPath(xPathBottom, redPaint);

    canvas.drawPath(zPathTop, orangePaint);
    canvas.drawPath(zPathBottom, orangePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
