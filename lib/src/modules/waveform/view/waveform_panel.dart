// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// waveform_panel.dart
// The waveform panel.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// waveform_panel.dart
// The waveform panel.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rohd_wave_viewer/src/modules/rohd_module/bloc/rohd_module_bloc.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/view/widgets/waveform_background.dart';

class WaveformPanel extends StatelessWidget {
  const WaveformPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    final scrollController = ScrollController();

    return BlocBuilder<RohdModuleBloc, RohdModuleState>(
        builder: (context, state) {
      // Get time range from metadata, default to 20 if not available
      final endTime = state.moduleStructure.metadata.endTime;
      final timescale = endTime > 0 ? endTime : 20;

      return Theme(
        data: Theme.of(context).copyWith(
          scrollbarTheme: ScrollbarThemeData(
            thumbColor: WidgetStateProperty.all(Colors.white),
          ),
        ),
        child: Scrollbar(
          thumbVisibility: true,
          controller: scrollController,
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: height,
              child: WaveformBackground(
                timescale: timescale,
              ),
            ),
          ),
        ),
      );
    });
  }
}
