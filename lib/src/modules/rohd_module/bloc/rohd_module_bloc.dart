// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// rohd_module_bloc.dart
// The BLoC for ROHD modules.
//
// 2024 April
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:module_structure_api/module_structure_api.dart';
import 'package:module_structure_repository/module_structure_repository.dart';
import 'package:flutter/foundation.dart';

part 'rohd_module_event.dart';
part 'rohd_module_state.dart';

class RohdModuleBloc extends Bloc<RohdModuleEvent, RohdModuleState> {
  RohdModuleBloc({
    required ModuleStructureRepository moduleStructureRepository,
  })  : _moduleStructureRepository = moduleStructureRepository,
        super(Loading(ModuleStructure.empty())) {
    on<RohdModuleInit>(onRohdModuleInit);
    on<RohdModuleSelect>(onModuleSelected);
    // Note: Do NOT call add(RohdModuleInit()) here - wait until VCD is loaded
  }

  final ModuleStructureRepository _moduleStructureRepository;

  Future<void> onRohdModuleInit(
    RohdModuleInit event,
    Emitter<RohdModuleState> emit,
  ) async {
    emit(
      Loading(ModuleStructure.empty()),
    );
    try {
      debugPrint('[RohdModuleBloc] onRohdModuleInit started');
      final rohdModule = await _moduleStructureRepository.getModuleStructure();
      debugPrint('[RohdModuleBloc] Got module structure with ${rohdModule.modules.length} modules');

      // Load waveform data for all signals
      final allSignalIds = _moduleStructureRepository.cachedSignalIds;
      debugPrint('[RohdModuleBloc] Cached signal IDs: ${allSignalIds.length}');
      if (allSignalIds.isNotEmpty) {
        await _moduleStructureRepository.loadAndAppendWaveformData(
          signalIds: allSignalIds,
        );
        debugPrint('[RohdModuleBloc] Waveform data loaded for ${allSignalIds.length} signals');
      }

      emit(Rendered(rohdModule));
      debugPrint('[RohdModuleBloc] Emitted Rendered state');
    } catch (e, stackTrace) {
      debugPrint('[RohdModuleBloc] Error loading module structure: $e');
      debugPrint('[RohdModuleBloc] Stack trace: $stackTrace');
      emit(Error(ModuleStructure.empty()));
    }
  }

  Future<void> onModuleSelected(
    RohdModuleSelect event,
    Emitter<RohdModuleState> emit,
  ) async {
    try {
      _moduleStructureRepository.selectModule(event.selectedModule);
      emit(ModuleSelected(event.moduleStructure, event.selectedModule));
    } catch (e) {
      emit(Error(ModuleStructure.empty()));
    }
  }
}
