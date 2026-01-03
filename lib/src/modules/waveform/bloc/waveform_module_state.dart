// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// waveform_module_state.dart
// The states for the waveform module BLoC.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

part of 'waveform_module_bloc.dart';

sealed class WaveformModuleState extends Equatable {
  final int timePs;

  const WaveformModuleState(this.timePs);

  @override
  List<Object> get props => [timePs];
}

final class InitialCursor extends WaveformModuleState {
  const InitialCursor() : super(0);
}

final class UpdatedCursor extends WaveformModuleState {
  const UpdatedCursor(super.timePs);
}

final class Error extends WaveformModuleState {
  const Error() : super(0);
}
