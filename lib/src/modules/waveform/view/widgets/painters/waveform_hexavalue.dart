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

class WaveformHexaValue extends Waveform {
  WaveformHexaValue(super.waveform, super.finalTime);

  @override
  void paint(Canvas canvas, Size size) {
    const space = 3;

    final topPath = Path();
    final bottomPath = Path();

    final xPathTop = Path();
    final xPathBottom = Path();

    final zPathTop = Path();
    final zPathBottom = Path();

    final int widthPx = size.width.ceil();
    String? prevSignal;

    for (int px = 0; px < widthPx; px++) {
      final int timeAtPx = ((px / size.width) * finalTime).round();
      final value =
          getValueAtOrBeforeTime(waveform, timeAtPx) ?? prevSignal ?? '0';

      final double x = px.toDouble();
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
