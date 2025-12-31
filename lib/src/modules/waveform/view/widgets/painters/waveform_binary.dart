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

class WaveformBinary extends Waveform {
  WaveformBinary(super.waveform, super.finalTime);

  @override
  void paint(Canvas canvas, Size size) {
    final binValPath = Path();
    final xValPath = Path();
    final zValPath = Path();

    // Map pixel columns to time using finalTime
    final int widthPx = size.width.ceil();
    String? prevVal;

    for (int px = 0; px < widthPx; px++) {
      final int timeAtPx = ((px / size.width) * finalTime).round();
      final value =
          getValueAtOrBeforeTime(waveform, timeAtPx) ?? prevVal ?? '0';

      final double x = px.toDouble();
      double y;
      if (value.toLowerCase().contains('x') ||
          value.toLowerCase().contains('z')) {
        y = size.height;
      } else {
        y = size.height * (1 - int.parse(value));
      }

      if (px == 0) {
        binValPath.moveTo(x, y);
      } else {
        if (value.toLowerCase().contains('x')) {
          xValPath.lineTo(x, y);
        } else if (value.toLowerCase().contains('z')) {
          zValPath.lineTo(x, y);
        } else {
          binValPath.lineTo(x, y);
        }
      }

      prevVal = value;
    }

    canvas.drawPath(binValPath, greenPaint);
    canvas.drawPath(xValPath, redPaint);
    canvas.drawPath(zValPath, orangePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
