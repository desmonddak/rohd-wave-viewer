// Small non-generated helpers that wrap the generated FRB API.
// Keep hand-written code here so it survives codegen regeneration.

import 'package:flutter/foundation.dart';
import '../generated/api.dart' as rust;

/// Debug wrapper that fetches waveform data and logs a short sample.
Future<List<rust.SignalWaveformData>> getWaveformDataDebug(
    {required List<String> signalIds}) async {
  final data = await rust.getWaveformData(signalIds: signalIds);
  if (data.isNotEmpty) {
    try {
      final first = data.first;
      final sample = first.data.take(8).map((p) => p.value).toList();
      debugPrint('[FRB_DEBUG_DART] signal=${first.signalId} sample=$sample');
    } catch (e, st) {
      debugPrint('[FRB_DEBUG_DART] error logging sample: $e $st');
    }
  }
  return data;
}
