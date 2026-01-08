// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cursor.dart
// Cursor widget for the waveform display.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:flutter/material.dart';
import 'painters/cursor.dart';

class CursorWidget extends StatelessWidget {
  final Offset position;

  const CursorWidget(this.position, {super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: Cursor(position),
      ),
    );
  }
}
