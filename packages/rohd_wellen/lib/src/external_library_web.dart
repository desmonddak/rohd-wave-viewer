// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// external_library_web.dart
// Web platform implementation - return a preloaded ExternalLibrary

// 2026 January 03
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_web.dart';

/// On web, returns an ExternalLibrary to indicate WASM is already loaded via wasm_bindgen().
/// This prevents flutter_rust_bridge from trying to load the WASM again.
ExternalLibrary? createPreloadedExternalLibrary() {
  return const ExternalLibrary(debugInfo: 'wasm-preloaded-via-wasm_bindgen');
}
