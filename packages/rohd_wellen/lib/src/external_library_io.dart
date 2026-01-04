// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// external_library_io.dart
// Native platform implementation - return null to use default loading

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

/// Returns null on native platforms to let flutter_rust_bridge load the library normally.
ExternalLibrary? createPreloadedExternalLibrary() {
  return null;
}
