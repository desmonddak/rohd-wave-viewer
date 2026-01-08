// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// timescale.dart
// The timescale widget for the waveform display.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:flutter/material.dart';
import 'package:rohd_wave_viewer/src/const/const.dart';

class TimescaleWidget extends StatelessWidget {
  final double zoomLevel;
  final double finalTime;
  final double startTime;
  final double viewportWidth; // Actual viewport width for painting
  final double leftOffset; // Left offset to align with waveforms
  final Color lineColor;

  const TimescaleWidget({
    super.key,
    required this.zoomLevel,
    required this.finalTime,
    required this.viewportWidth,
    this.startTime = 0.0,
    this.leftOffset =
        waveformLeftOffset, // Match SignalTabContainer horizontal padding
    this.lineColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    // Use viewport width for painting, not the constraint from parent
    return CustomPaint(
      size: Size(viewportWidth, 60),
      painter: TimescalePainter(
        timeScale: zoomLevel,
        finalTime: finalTime,
        startTime: startTime,
        leftOffset: leftOffset,
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

  /// The start time of the visible range
  final double startTime;

  /// Left offset to align with waveform content
  final double leftOffset;

  TimescalePainter({
    this.timeUnit = 'ps',
    required this.timeScale,
    required this.finalTime,
    this.startTime = 0.0,
    this.leftOffset = waveformLeftOffset,
  });

  // No temporary diagnostic logging.

  @override
  void paint(Canvas canvas, Size size) {
    // Timescale paint logging removed

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1;

    final majorTickPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3;

    const double initPosY = 28; // Center line lower to allow alternating labels
    const double majorTickHeight = 16.0;
    const double minorTickHeight = 9.0; // Medium minor ticks
    const double labelOffset = 20.0; // vertical offset for alternating labels

    // Reserve a right padding equal to leftOffset for visual cleanliness
    const double rightPadding = waveformLeftOffset;
    // Drawing area starts at leftOffset and ends before right padding
    final double drawWidth =
        (size.width - leftOffset - rightPadding).clamp(0.0, double.infinity);

    /// Draw the horizontal scale line (from leftOffset to end)
    // Draw the horizontal scale line from leftOffset to right boundary
    canvas.drawLine(
      Offset(leftOffset, initPosY),
      Offset(leftOffset + drawWidth, initPosY),
      paint,
    );

    // Target: ~10 major ticks on screen
    const int targetMajorTicks = 10;

    // Choose a "nice" major interval from the sequence {1,2,5} * 10^n
    // Do interval math in integer picoseconds to avoid floating rounding artifacts
    int chooseNiceIntervalPs(double rough) {
      // Integer-only "nice" chooser. Input `rough` is in picoseconds (may be fractional),
      // but we work with integer powers-of-ten and multipliers {1,2,5,10}.
      if (rough <= 0) return 1;
      // Convert rough to integer ps (ceil to avoid undersizing)
      int r = rough.ceil();

      // Determine power of ten base (pow10) as largest power of 10 <= r
      int pow10 = 1;
      while (pow10 * 10 <= r) {
        pow10 *= 10;
      }

      // Try multipliers 1,2,5,10 against pow10 to find the smallest >= r
      final int m1 = pow10 * 1;
      final int m2 = pow10 * 2;
      final int m5 = pow10 * 5;
      final int m10 = pow10 * 10;

      if (r <= m1) return m1;
      if (r <= m2) return m2;
      if (r <= m5) return m5;
      return m10;
    }

    // Work in integer picoseconds for tick generation
    final int startPs = startTime.round();
    final int finalTimePs = finalTime.round();
    final int endPs = startPs + finalTimePs;

    // Compute rough interval in picoseconds (work in integer ps)
    final double roughInterval = finalTimePs / targetMajorTicks;

    final int majorIntervalPs = chooseNiceIntervalPs(roughInterval);
    // Prefer a half-major minor subdivision (e.g., 100ns major -> 50ns minor)
    int minorIntervalPs = (majorIntervalPs ~/ 2);
    if (minorIntervalPs <= 0) {
      minorIntervalPs = (majorIntervalPs ~/ 10).clamp(1, majorIntervalPs);
    }
    // Expose as doubles for pixel mapping
    final double majorInterval = majorIntervalPs.toDouble();

    // Calculate how many major ticks we'll actually draw
    final int numMajorTicks = (finalTime / majorInterval).ceil() + 1;

    // Measure actual major label widths (more accurate than conservative estimate)
    const double minLabelSpacing =
        2.0; // Minimum gap between labels (reduced to avoid clipping)

    // Compute first major/minor tick in integer picoseconds (round up to next interval)
    final int firstMajorTickPs =
        ((startPs + majorIntervalPs - 1) ~/ majorIntervalPs) * majorIntervalPs;
    final int firstMinorTickPs =
        ((startPs + minorIntervalPs - 1) ~/ minorIntervalPs) * minorIntervalPs;

    // Gather major tick times (in picoseconds) and measure label widths to decide if majors fit
    final List<int> majorTimesPs = [];
    for (int t = firstMajorTickPs; t <= endPs; t += majorIntervalPs) {
      majorTimesPs.add(t);
    }
    // Extra diagnostics for small intervals (help reproduce 1ns/5ns anomaly)
    // (Additional verbose diagnostics removed)
    double maxMeasuredMajorWidth = 0.0;
    for (final t in majorTimesPs) {
      final int labelValue = t;
      final textPainter = TextPainter(
        text: TextSpan(
          text: _formatTimeLabel(labelValue),
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      if (textPainter.width > maxMeasuredMajorWidth) {
        maxMeasuredMajorWidth = textPainter.width;
      }
    }

    // Always prefer showing major labels; minors will collapse first when
    // space is tight.
    const bool showMajorLabels = true;

    // Measure minor label widths (conservative max) and decide if minors fit.
    double maxMeasuredMinorWidth = 0.0;
    // We'll sample up to 20 minor labels across the range using
    // integer picosecond ticks.
    const int minorSamples = 20;
    if (minorIntervalPs > 0 && numMajorTicks > 0) {
      int sampled = 0;
      for (int t = firstMinorTickPs;
          t <= endPs && sampled < minorSamples;
          t += minorIntervalPs) {
        final int labelValue = t;
        final textPainter = TextPainter(
          text: TextSpan(
            text: _formatTimeLabel(labelValue),
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 10,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        if (textPainter.width > maxMeasuredMinorWidth) {
          maxMeasuredMinorWidth = textPainter.width;
        }
        sampled++;
      }
    }

    // Precompute which major labels will actually be drawn (so minors can refer to them)
    final List<Map<String, dynamic>> drawnMajors = [];
    double precomputeLastMajorRight = -1e12;
    if (showMajorLabels) {
      // Iterate precomputed integer picosecond major times to avoid floating relics
      for (final t in majorTimesPs) {
        final double absoluteTime = t.toDouble();
        final double x =
            leftOffset + ((absoluteTime - startTime) / finalTime) * drawWidth;
        // Skip ticks that fall outside the drawing area (respect right padding)
        if (x < leftOffset || x > leftOffset + drawWidth) continue;
        final int labelValue = t;
        final String labelText = _formatTimeLabel(labelValue);
        final textPainter = TextPainter(
          text: TextSpan(
            text: labelText,
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        final labelLeft = x - textPainter.width / 2;
        final labelRight = x + textPainter.width / 2;
        if (labelLeft > precomputeLastMajorRight + minLabelSpacing) {
          // Force majors to be above the scale line
          drawnMajors.add({
            'x': x,
            'left': labelLeft,
            'right': labelRight,
            'above': true,
            'textPainter': textPainter,
          });
          precomputeLastMajorRight = labelRight;
        }
      }
      // Ensure first and last major labels are present for orientation
      if (majorTimesPs.isNotEmpty) {
        final int firstT = majorTimesPs.first;
        final int lastT = majorTimesPs.last;
        bool hasFirst = drawnMajors.any((m) =>
            (m['x'] as double) ==
            leftOffset + ((firstT - startTime) / finalTime) * drawWidth);
        bool hasLast = drawnMajors.any((m) =>
            (m['x'] as double) ==
            leftOffset + ((lastT - startTime) / finalTime) * drawWidth);
        if (!hasFirst) {
          final double x =
              leftOffset + ((firstT - startTime) / finalTime) * drawWidth;
          final int labelValue = firstT;
          final textPainter = TextPainter(
            text: TextSpan(
              text: _formatTimeLabel(labelValue),
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          final labelLeft = x - textPainter.width / 2;
          final labelRight = x + textPainter.width / 2;
          drawnMajors.insert(0, {
            'x': x,
            'left': labelLeft,
            'right': labelRight,
            'above': true,
            'textPainter': textPainter
          });
        }
        if (!hasLast) {
          final double x =
              leftOffset + ((lastT - startTime) / finalTime) * drawWidth;
          final int labelValue = lastT;
          final textPainter = TextPainter(
            text: TextSpan(
              text: _formatTimeLabel(labelValue),
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          final labelLeft = x - textPainter.width / 2;
          final labelRight = x + textPainter.width / 2;
          drawnMajors.add({
            'x': x,
            'left': labelLeft,
            'right': labelRight,
            'above': true,
            'textPainter': textPainter
          });
        }
      }
    }

    // Now gather minor ticks into a list (sorted) and draw them.
    final List<int> minorTimesPs = [];
    for (int t = firstMinorTickPs; t <= endPs; t += minorIntervalPs) {
      if ((t % majorIntervalPs) == 0) continue; // skip majors
      minorTimesPs.add(t);
    }
    minorTimesPs.sort();

    const lastMinorRight = -1e12;
    for (final absoluteTime in minorTimesPs) {
      final double x =
          leftOffset + ((absoluteTime - startTime) / finalTime) * drawWidth;
      if (x < leftOffset || x > leftOffset + drawWidth) continue;

      // Draw minor tick mark
      canvas.drawLine(
        Offset(x, initPosY),
        Offset(x, initPosY + minorTickHeight),
        paint,
      );

      final labelText = _formatTimeLabel(absoluteTime);
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Place all minor labels below the scale line
      const yOffset = initPosY + 6;
      final labelLeft = x - textPainter.width / 2;

      // Skip if overlaps previous minor
      if (!(labelLeft > lastMinorRight + minLabelSpacing)) {
        continue;
      }

      textPainter.paint(canvas, Offset(labelLeft, yOffset));
    }

    // Draw major ticks LAST (on top of minor ticks) using precomputed drawnMajors
    for (final m in drawnMajors) {
      final double x = m['x'] as double;
      // Draw major tick mark
      canvas.drawLine(
        Offset(x, initPosY),
        Offset(x, initPosY + majorTickHeight),
        majorTickPaint,
      );
      final textPainter = m['textPainter'] as TextPainter;
      final bool mAbove = m['above'] as bool;
      final double yOffset = mAbove ? (initPosY - labelOffset) : (initPosY + 6);
      textPainter.paint(canvas, Offset(m['left'] as double, yOffset));
    }
  }

  String _formatTimeLabel(int value) {
    // Convert ps to larger units when appropriate and format with decimals
    if (value == 0) return '0ps';
    double v = value.toDouble();
    String unit;
    double displayVal;
    if (v.abs() >= 1e9) {
      unit = 's';
      displayVal = v / 1e9;
    } else if (v.abs() >= 1e6) {
      unit = 'ms';
      displayVal = v / 1e6;
    } else if (v.abs() >= 1e3) {
      unit = 'ns';
      displayVal = v / 1e3;
    } else {
      unit = 'ps';
      displayVal = v;
    }

    String fmtNum(double x) {
      final double ax = x.abs();
      if (ax >= 100) {
        return x.toStringAsFixed(0);
      } else if (ax >= 10) {
        // Keep one decimal for 2-digit numbers, but strip only trailing zeros after decimal
        return x.toStringAsFixed(1).replaceAll(RegExp(r"(\.\d)0+\$"), r"\1");
      } else {
        // Keep two decimals for small numbers; strip only trailing zeros after decimal
        return x.toStringAsFixed(2).replaceAll(RegExp(r"(\.\d)0+\$"), r"\1");
      }
    }

    return '${fmtNum(displayVal)}$unit';
  }

  @override
  bool shouldRepaint(covariant TimescalePainter oldDelegate) {
    return oldDelegate.timeScale != timeScale ||
        oldDelegate.finalTime != finalTime ||
        oldDelegate.startTime != startTime ||
        oldDelegate.leftOffset != leftOffset;
  }
}
