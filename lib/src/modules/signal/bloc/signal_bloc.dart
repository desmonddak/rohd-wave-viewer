// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// signal_bloc.dart
// The BLoC for the signal module.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:module_structure_api/module_structure_api.dart';
import 'package:module_structure_repository/module_structure_repository.dart';

part 'signal_event.dart';
part 'signal_state.dart';

class SignalBloc extends Bloc<SignalEvent, SignalState> {
  final ModuleStructureRepository _moduleStructureRepository;

  SignalBloc(ModuleStructureRepository moduleStructureRepository)
      : _moduleStructureRepository = moduleStructureRepository,
        super(SignalLoading()) {
    on<SignalUpdateEvent>(updateSignals);
    on<SignalSelectedEvent>(addSignalToMonitor);
    on<SignalFocusEvent>(focusSignal);
    on<SignalUnfocusEvent>(unfocusSignal);
  }

  void updateSignals(
    SignalUpdateEvent event,
    Emitter<SignalState> emit,
  ) {
    final signals = _moduleStructureRepository
        .getSignalsBySelectedModule(event.selectedModule);

    emit(SignalLoaded(
      signals,
      state.monitorSignalsList,
      focusedSignal: state.focusedSignal,
    ));
  }

  void addSignalToMonitor(
    SignalSelectedEvent event,
    Emitter<SignalState> emit,
  ) {
    emit(SignalLoaded(
      state.signals,
      [...state.monitorSignalsList, event.selectedSignal],
      focusedSignal: state.focusedSignal,
    ));
  }

  /// Focus on a signal for data-point-by-data-point navigation.
  void focusSignal(
    SignalFocusEvent event,
    Emitter<SignalState> emit,
  ) {
    emit(SignalLoaded(
      state.signals,
      state.monitorSignalsList,
      focusedSignal: event.signal,
    ));
  }

  /// Unfocus the current signal; return to normal navigation.
  void unfocusSignal(
    SignalUnfocusEvent event,
    Emitter<SignalState> emit,
  ) {
    emit(SignalLoaded(
      state.signals,
      state.monitorSignalsList,
      focusedSignal: null,
    ));
  }
}
