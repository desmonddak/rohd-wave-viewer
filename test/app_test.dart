// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// app_test.dart
// Tests for the main App widget.
//
// 2026 January
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rohd_wave_viewer/app.dart';
import 'package:rohd_wave_viewer/src/modules/rohd_module/bloc/rohd_module_bloc.dart';

import 'helpers.dart';

void main() {
  group('App Widget Tests', () {
    late MockModuleStructureRepository mockModuleRepository;

    setUp(() {
      mockModuleRepository = MockModuleStructureRepository();
    });

    testWidgets('App renders and builds MaterialApp', (WidgetTester tester) async {
      await tester.pumpWidget(
        App(moduleStructureRepository: mockModuleRepository),
      );

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App initializes with all required BlocProviders',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        App(moduleStructureRepository: mockModuleRepository),
      );

      // Verify that the blocs are provided
      expect(find.byType(MultiBlocProvider), findsOneWidget);
      expect(
        find.byType(RohdModuleBloc),
        findsWidgets,
        reason: 'RohdModuleBloc should be provided',
      );
    });

    testWidgets('App has correct title and theme configuration',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        App(moduleStructureRepository: mockModuleRepository),
      );

      final MaterialApp app = find.byType(MaterialApp).evaluate().first.widget as MaterialApp;
      expect(app.title, 'ROHD Wave viewer');
      expect(app.theme, isNotNull);
    });

    testWidgets('App has correct initial route', (WidgetTester tester) async {
      await tester.pumpWidget(
        App(moduleStructureRepository: mockModuleRepository),
      );

      final MaterialApp app = find.byType(MaterialApp).evaluate().first.widget as MaterialApp;
      expect(app.initialRoute, '/');
      expect(app.routes, isNotEmpty);
      expect(app.routes?.containsKey('/'), true);
    });
  });
}
