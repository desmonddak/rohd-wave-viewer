// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// home.dart
// The home page for the waveform viewer.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:rohd_wave_viewer/src/const/const.dart';
import 'package:rohd_wave_viewer/src/modules/rohd_module/rohd_module.dart';
import 'package:rohd_wave_viewer/src/modules/shared/widgets/widgets.dart';
import 'package:rohd_wave_viewer/src/modules/signal/view/selected_signal_panel.dart';
import 'package:rohd_wave_viewer/src/modules/signal/view/signal_panel.dart';
import 'package:rohd_wave_viewer/src/modules/signal/view/signal_value_panel.dart';
import 'package:rohd_wave_viewer/src/modules/waveform/view/waveform_panel.dart';

class WaveFormViewerPage extends StatefulWidget {
  const WaveFormViewerPage({super.key});

  @override
  State<WaveFormViewerPage> createState() => _WaveFormViewerPageState();
}

class _WaveFormViewerPageState extends State<WaveFormViewerPage> {
  // Each panel needs its own scroll controller to avoid attaching multiple
  // ScrollPositions to the same controller, which breaks interactive Scrollbars.
  final ScrollController _selectedSignalsScrollController = ScrollController();
  final ScrollController _signalValueScrollController = ScrollController();
  final ScrollController _waveformVerticalScrollController = ScrollController();

  @override
  void dispose() {
    _selectedSignalsScrollController.dispose();
    _signalValueScrollController.dispose();
    _waveformVerticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bodyHeight = MediaQuery.of(context).size.height - 80;

    return SplitPane(
      axis: Axis.horizontal,
      initialFractions: const [0.14, 0.13, 0.13, 0.6],
      minSizes: const [200, 150, 50, 600],
      children: [
        const ModuleSignalPanel(),
        Container(
          decoration: panelDecoration(),
          height: bodyHeight,
          child: SelectedSignalsPanel(
            scrollController: _selectedSignalsScrollController,
          ),
        ),
        // Add signal value panel here
        Container(
          decoration: panelDecoration(),
          height: bodyHeight,
          child: SignalValuePanel(
            scrollController: _signalValueScrollController,
          ),
        ),
        Container(
          decoration: panelDecoration(),
          height: bodyHeight,
          child: WaveformPanel(
            verticalScrollController: _waveformVerticalScrollController,
          ),
        ),
      ],
    );
  }
}

class ModuleSignalPanel extends StatelessWidget {
  const ModuleSignalPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final bodyHeight = MediaQuery.of(context).size.height / 2 - 80;
    return SplitPane(
      axis: Axis.vertical,
      initialFractions: const [0.5, 0.5],
      children: [
        Container(
          decoration: panelDecoration(),
          height: bodyHeight,
          child: ListView(
            children: const [
              Center(child: PanelHeader(headerText: modulePanelTitle)),
              RohdModulePanel(),
            ],
          ),
        ),
        Container(
          decoration: panelDecoration(),
          height: bodyHeight,
          child: ListView(
            children: const [
              Center(child: PanelHeader(headerText: 'Module Signals')),
              SignalPanel(),
            ],
          ),
        ),
      ],
    );
  }
}
