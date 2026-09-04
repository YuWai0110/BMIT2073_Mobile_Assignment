import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_assginment/core/theme/theme_manager.dart';
import 'package:mobile_assginment/features/auth/auth_manager.dart';
import 'package:mobile_assginment/features/auth/profile_manager.dart';
import 'package:mobile_assginment/features/auth/profile_screen.dart';

void main() {
  test('logout clears unsaved profile drafts', () async {
    final auth = AuthManager.forTesting(loggedIn: true);
    final profile = auth.profileManager;
    profile.startEditing();
    profile.updateDraft(name: const TextEditingValue(text: 'Private draft'));
    await auth.logout();
    expect(profile.isEditing, isFalse);
    expect(profile.fullName.text, isEmpty);
    expect(profile.company.text, isEmpty);
    expect(profile.phone.text, isEmpty);
    auth.dispose();
  });
  test('profile validates lengths and Malaysian phone formats', () {
    expect(ProfileManager.validateName('   '), isNotNull);
    expect(ProfileManager.validateName('A' * 30), isNull);
    expect(ProfileManager.validateName('A' * 31), isNotNull);
    expect(ProfileManager.validateCompany(''), isNull);
    expect(ProfileManager.validateCompany('A' * 50), isNull);
    expect(ProfileManager.validateCompany('A' * 51), isNotNull);
    for (final phone in [
      '',
      '0123456789',
      '012-3456789',
      '+60123456789',
      '01123456789',
    ]) {
      expect(ProfileManager.validatePhone(phone), isNull);
    }
    for (final phone in [
      '1234567890',
      '0123',
      '+65123456789',
      '012345678901',
      '012abc6789',
    ]) {
      expect(ProfileManager.validatePhone(phone), isNotNull);
    }
  });

  testWidgets('editing drafts and selection survive rotation and recreation', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeManager(await SharedPreferences.getInstance());
    final auth = _SavingAuth();
    auth.currentUser!.fullName = 'Long legacy name ' * 20;
    Future<void> pump(Size size) async {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthManager>.value(value: auth),
            ChangeNotifierProvider.value(value: theme),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: KeyedSubtree(
                key: ValueKey(size),
                child: const ProfileScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(const Size(390, 844));
    final heading = tester.widget<Text>(
      find.text(auth.currentUser!.fullName).first,
    );
    expect(heading.maxLines, 2);
    expect(heading.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('Full Name')),
      'Draft Name',
    );
    await tester.enterText(
      find.byKey(const ValueKey('Company')),
      'Draft Company',
    );
    await tester.enterText(find.byKey(const ValueKey('Phone')), '012-3456789');
    final controller = tester
        .widget<TextFormField>(find.byKey(const ValueKey('Full Name')))
        .controller!;
    controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.pump();
    for (final size in [const Size(844, 390), const Size(390, 844)]) {
      await pump(size);
      expect(auth.profileManager.isEditing, isTrue);
      final name = tester
          .widget<TextFormField>(find.byKey(const ValueKey('Full Name')))
          .controller!;
      expect(name.text, 'Draft Name');
      expect(name.selection.baseOffset, 3);
      expect(auth.profileManager.company.text, 'Draft Company');
      expect(auth.profileManager.phone.text, '012-3456789');
      expect(tester.takeException(), isNull);
    }
    auth.profileManager.updateDraft(
      name: const TextEditingValue(text: 'Provider draft'),
    );
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('Full Name')))
          .controller!
          .text,
      'Provider draft',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    theme.dispose();
  });

  testWidgets(
    'invalid save is disabled and cancel never submits; confirm submits once',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeManager(await SharedPreferences.getInstance());
      final auth = _SavingAuth();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthManager>.value(value: auth),
            ChangeNotifierProvider.value(value: theme),
          ],
          child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('Full Name')), '   ');
      await tester.pump();
      expect(find.text('Please enter your full name.'), findsOneWidget);
      final save = find.widgetWithText(TextButton, 'Save');
      expect(tester.widget<TextButton>(save).onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('Full Name')),
        'Updated Name',
      );
      await tester.pump();
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Confirm Profile Update'), findsOneWidget);
      expect(auth.calls, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(auth.calls, 0);
      expect(auth.profileManager.isEditing, isTrue);
      expect(auth.profileManager.fullName.text, 'Updated Name');
      await tester.tap(save);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(auth.calls, 1);
      expect(auth.profileManager.isSaving, isTrue);
      expect(tester.widget<TextButton>(save).onPressed, isNull);
      auth.completion.complete(null);
      await tester.pumpAndSettle();
      expect(auth.profileManager.isEditing, isFalse);
      expect(find.text('Profile updated successfully'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
      theme.dispose();
    },
  );
}

class _SavingAuth extends AuthManager {
  _SavingAuth() : super.forTesting(loggedIn: true);
  int calls = 0;
  final completion = Completer<String?>();
  @override
  Future<String?> updateProfile({
    String? fullName,
    String? companyName,
    String? phone,
  }) async {
    calls++;
    final error = await completion.future;
    if (error == null) {
      currentUser!.fullName = fullName!;
      currentUser!.companyName = companyName!;
      currentUser!.phone = phone!;
      notifyListeners();
    }
    return error;
  }
}
