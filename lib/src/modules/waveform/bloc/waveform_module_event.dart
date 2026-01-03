// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// waveform_module_event.dart
// The events for the waveform module BLoC.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

part of 'waveform_module_bloc.dart';

sealed class WaveformModuleEvent extends Equatable {
  const WaveformModuleEvent();
}

final class WaveformModuleInit extends WaveformModuleEvent {
  @override
  List<Object> get props => [];
}

final class WaveformModuleOnTap extends WaveformModuleEvent {
  final int timePs;

  const WaveformModuleOnTap(this.timePs);

  @override
  List<Object> get props => [timePs];
}
