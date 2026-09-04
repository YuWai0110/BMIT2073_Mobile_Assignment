import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile_assginment/features/auth/auth_manager.dart';
import 'package:mobile_assginment/features/auth/forgot_password_screen.dart';
import 'package:mobile_assginment/features/calculator_roi/calc_manager.dart';
import 'package:mobile_assginment/features/calculator_roi/calc_screen.dart';
import 'package:mobile_assginment/features/calculator_roi/calc_validators.dart';
import 'package:mobile_assginment/core/responsive_input_dialog.dart';

class _ResetAuth extends AuthManager {
  _ResetAuth() : super.forTesting();

  int requests = 0;
  final response = Completer<String?>();

  @override
  Future<String?> resetPassword({required String email}) {
    requests++;
    return response.future;
  }
}

void main() {
  test('scheme name validates trimmed length boundaries', () {
    expect(validateSchemeName('  '), 'Scheme name is required.');
    expect(validateSchemeName(' a '), 'Minimum 2 characters required.');
    expect(validateSchemeName(' ab '), isNull);
    expect(validateSchemeName(' ${'a' * 50} '), isNull);
    expect(validateSchemeName('a' * 51), 'Maximum 50 characters allowed.');
  });

  testWidgets('reset cooldown survives rotation and error until 60 seconds', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final auth = _ResetAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthManager>.value(
        value: auth,
        child: const MaterialApp(home: ForgotPasswordScreen()),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.tap(find.text('Send Reset Email'));
    await tester.pump();
    expect(find.text('Resend available in 60s'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    auth.response.complete('Too many requests. Please try again later.');
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    tester.view.physicalSize = const Size(844, 390);
    await tester.pump();
    expect(find.text('Resend available in 50s'), findsOneWidget);
    expect(auth.requests, 1);
    await tester.pump(const Duration(seconds: 49));
    expect(find.text('Resend available in 1s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Send Reset Email'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving reset screen cancels timer and ignores late response', (
    tester,
  ) async {
    final auth = _ResetAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthManager>.value(
        value: auth,
        child: const MaterialApp(home: ForgotPasswordScreen()),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.tap(find.text('Send Reset Email'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    auth.response.complete(null);
    await tester.pump(const Duration(seconds: 61));
    expect(tester.takeException(), isNull);
  });

  testWidgets('scheme validation and typed draft survive rotation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final manager = CalcManager()
      ..updateEquipmentPrice('5000.00')
      ..updateQuantity('1');
    addTearDown(manager.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: manager,
        child: const MaterialApp(home: Scaffold(body: CalcScreen())),
      ),
    );
    await tester.ensureVisible(find.text('Save This Scheme'));
    await tester.tap(find.text('Save This Scheme'));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(ResponsiveInputDialog),
      matching: find.byType(TextFormField),
    );
    final save = find.widgetWithText(ElevatedButton, 'Save');
    expect(find.text('Scheme name is required.'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(save).onPressed, isNull);
    await tester.enterText(field, ' a ');
    await tester.pump();
    expect(find.text('Minimum 2 characters required.'), findsOneWidget);
    await tester.enterText(field, 'a' * 51);
    await tester.pump();
    expect(find.text('Maximum 50 characters allowed.'), findsOneWidget);
    await tester.enterText(field, ' Factory Upgrade ');
    await tester.pump();
    for (final size in [const Size(844, 390), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        ' Factory Upgrade ',
      );
      expect(tester.widget<ElevatedButton>(save).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(ResponsiveInputDialog), findsNothing);
  });
}
