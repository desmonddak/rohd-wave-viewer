// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// external_library_io.dart
// Native platform implementation - stubs for web-only functions

// 2026 January 03
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

/// Returns null on native platforms to let flutter_rust_bridge load the library normally.
ExternalLibrary? createPreloadedExternalLibrary() {
  return null;
}

/// Stub - only available on web platform.
Future<void> waitForWasmInit({
  Duration timeout = const Duration(seconds: 10),
}) async {
  throw UnsupportedError('waitForWasmInit is only available on web');
}

/// Stub - only available on web platform.
Future<void> loadWasmScript(String scriptUrl) async {
  throw UnsupportedError('loadWasmScript is only available on web');
}

/// Stub - only available on web platform.
Future<Uint8List> fetchBytes(String url) async {
  throw UnsupportedError('fetchBytes is only available on web');
}
