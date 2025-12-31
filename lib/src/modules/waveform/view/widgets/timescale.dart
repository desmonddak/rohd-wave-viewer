// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// timescale.dart
// The timescale widget for the waveform display.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:flutter/material.dart';

class TimescaleWidget extends StatelessWidget {
  final int zoomLevel;
  final int finalTime;
  final Color lineColor;

  const TimescaleWidget({
    super.key,
    required this.zoomLevel,
    required this.finalTime,
    this.lineColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    return CustomPaint(
      size: Size(width, 50), // this is the canvas to draw
      painter: TimescalePainter(
        timeScale: zoomLevel.toDouble(),
        finalTime: finalTime.toDouble(),
      ),
    );
  }
}

class TimescalePainter extends CustomPainter {
  /// The unit if the timescale, default to pico seconds
  final String timeUnit;

  /// The zoom level of the painter.
  final double timeScale;

  /// The final time of the simulation timescale. Interval of the time in
  /// between.
  final double finalTime;

  TimescalePainter({
    this.timeUnit = 'ps',
    required this.timeScale,
    required this.finalTime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1;

    // this one should be in the constant folder
    const double initPosY = 0;

    /// Draw the horizontal scale line
    canvas.drawLine(
      const Offset(0, initPosY),
      Offset(size.width, initPosY),
      paint,
    );

    // Use a reasonable number of major ticks to avoid extremely large loops
    const int majorTicks = 10;
    const int totalMinorTicks = 10;

    for (int k = 0; k <= majorTicks; k++) {
      final double x = (k / majorTicks) * size.width;
      final int labelValue = ((k * finalTime) / majorTicks).round();

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$labelValue$timeUnit',
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 12,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final offset = Offset(
        x - textPainter.width / 2,
        initPosY - 20,
      );
      textPainter.paint(canvas, offset);

      // Draw the major line.
      canvas.drawLine(Offset(x, initPosY), Offset(x, size.height), paint);

      // Draw minor ticks between this major tick and the next
      if (k < majorTicks) {
        final double nextX = ((k + 1) / majorTicks) * size.width;
        for (int m = 1; m < totalMinorTicks; m++) {
          final double mx = x + (m / totalMinorTicks) * (nextX - x);
          canvas.drawLine(
              Offset(mx, initPosY), Offset(mx, initPosY + 5), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant TimescalePainter oldDelegate) {
    return oldDelegate.timeScale != timeScale ||
        oldDelegate.finalTime != finalTime;
  }
}
