// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// signal_event.dart
// The events for the Signal BLoC.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

part of 'signal_bloc.dart';

sealed class SignalEvent extends Equatable {}

class SignalUpdateEvent extends SignalEvent {
  final Module selectedModule;

  SignalUpdateEvent(this.selectedModule);

  @override
  List<Object?> get props => [selectedModule];
}

class SignalSelectedEvent extends SignalEvent {
  final Signal selectedSignal;
  SignalSelectedEvent(this.selectedSignal);

  @override
  List<Object?> get props => [selectedSignal];
}

/// Selects a signal for focus-mode navigation (arrow keys navigate data points).
class SignalFocusEvent extends SignalEvent {
  final Signal signal;

  SignalFocusEvent(this.signal);

  @override
  List<Object?> get props => [signal];
}

/// Deselects the focused signal; arrow keys return to normal pan.
class SignalUnfocusEvent extends SignalEvent {
  @override
  List<Object?> get props => [];
}
