// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// waveform.dart
// Abstract class for waveform painters.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:flutter/material.dart';
import 'package:module_structure_api/module_structure_api.dart';
import 'package:rohd_wave_viewer/src/const/const.dart';

abstract class Waveform extends CustomPainter {
  final greenPaint = Paint()
    ..color = Colors.green
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final redPaint = Paint()
    ..color = Colors.red
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final yellowPaint = Paint()
    ..color = Colors.yellow
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  final List<Data> waveform;
  final int
  finalTime; // Visible time range (kept for compatibility, but use timescale for mapping)
  final int startTime; // Visible start time (kept for compatibility)
  final int? signalWidth; // optional declared width for the signal
  final double leftOffset; // Left offset to align with timescale
  final double viewportWidth; // visible viewport width in pixels
  final double scrollOffset; // horizontal scroll offset in pixels
  final int timescale; // Full timescale for absolute time mapping

  Waveform(
    this.waveform,
    this.finalTime,
    this.startTime, {
    this.signalWidth,
    this.leftOffset = waveformLeftOffset,
    this.viewportWidth = 0.0,
    this.scrollOffset = 0.0,
    this.timescale = 0,
    super.repaint,
  });

  /// Find the last value at or before [time] using binary search on ordered data.
  String? getValueAtOrBeforeTime(List<Data> data, int time) {
    if (data.isEmpty) return null;
    int lo = 0;
    int hi = data.length - 1;
    int res = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (data[mid].time <= time) {
        res = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (res == -1) return null;
    return data[res].value;
  }

  String? getValueAtTime(List<Data> data, int time) {
    for (var dataItem in data) {
      if (dataItem.time == time) {
        return dataItem.value;
      }
    }
    return null;
  }

  void writeText(
    Canvas canvas,
    Offset offset, {
    required String text,
    TextStyle? customTextStyle,
  }) {
    final textStyle =
        customTextStyle ?? const TextStyle(color: Colors.green, fontSize: 12);

    final textSpan = TextSpan(text: '0x$text', style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    textPainter.paint(canvas, offset);
  }

  /// Formats a waveform value for multi-bit labels.
  ///
  /// - Preserves X/Z values (returns the original string without `0x`).
  /// - Converts bitvectors (`1010`, `0b1010`) and decimals to hex.
  /// - Pads hex to `signalWidth` when available.
  String formatValueAsHexLabel(String rawValue) {
    var v = rawValue.trim();
    if (v.isEmpty) return v;

    // Some loaders can produce trailing NUL characters.
    v = v.replaceAll('\u0000', '');

    final lower = v.toLowerCase();
    if (lower.contains('x') || lower.contains('z')) {
      return v;
    }

    BigInt? parsed;

    if (lower.startsWith('0x')) {
      final digits = lower.substring(2);
      if (digits.isEmpty) return v;
      parsed = BigInt.tryParse(digits, radix: 16);
    } else if (lower.startsWith('0b')) {
      final bits = lower.substring(2);
      if (bits.isEmpty) return v;
      parsed = BigInt.tryParse(bits, radix: 2);
    } else if (RegExp(r'^[01]+$').hasMatch(lower) && lower.length > 1) {
      // Raw bitvector without 0b prefix.
      parsed = BigInt.tryParse(lower, radix: 2);
    } else if (RegExp(r'^[0-9a-f]+$').hasMatch(lower) && lower.length > 1) {
      // Raw hex digits without 0x prefix.
      parsed = BigInt.tryParse(lower, radix: 16);
    } else {
      // Fall back to decimal.
      parsed = BigInt.tryParse(lower);
    }

    if (parsed == null) return v;

    var hex = parsed.toRadixString(16);

    // Pad to the declared width when available.
    final w = signalWidth;
    if (w != null && w > 0) {
      final digits = (w + 3) ~/ 4;
      hex = hex.padLeft(digits, '0');
    }

    return '0x$hex';
  }
}
