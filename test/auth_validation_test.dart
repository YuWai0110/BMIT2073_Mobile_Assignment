import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_assginment/features/auth/auth_manager.dart';
import 'package:mobile_assginment/features/auth/auth_validators.dart';
import 'package:mobile_assginment/features/auth/signup_screen.dart';
import 'package:mobile_assginment/services/supabase/supabase_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('registration validation', () {
    testWidgets('password error wraps fully in portrait and landscape', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      const message =
          'Password must contain at least 8 characters, one uppercase letter, one lowercase letter, and one number.';
      for (final size in [const Size(390, 844), const Size(844, 390)]) {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.physicalSize = size;
        await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
        await tester.enterText(find.byType(TextFormField).at(2), 'weak');
        await tester.pumpAndSettle();
        final error = find.text(message);
        expect(error, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(error);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.size.height, greaterThan(20));
        expect(tester.takeException(), isNull);
      }
    });
    test('validates the full name and email', () {
      expect(validateFullName('  '), 'Please enter your full name.');
      expect(validateFullName('Al'), isNull);
      expect(
        validateFullName('A'),
        'Full name must be between 2 and 30 characters.',
      );
      expect(validateFullName('A' * 30), isNull);
      expect(
        validateFullName('A' * 31),
        'Full name must be between 2 and 30 characters.',
      );
      expect(validateFullName(' Ahmad Ali '), isNull);
      expect(
        validateEmailAddress('invalid-email'),
        'Please enter a valid email address.',
      );
      expect(validateEmailAddress('user@example.com'), isNull);
    });

    test('requires a strong password and exact confirmation', () {
      expect(
        validateRegistrationPassword('short'),
        'Password must contain at least 8 characters, one uppercase letter, one lowercase letter, and one number.',
      );
      expect(validateRegistrationPassword('password1'), isNotNull);
      expect(validateRegistrationPassword('PASSWORD1'), isNotNull);
      expect(validateRegistrationPassword('Password'), isNotNull);
      expect(validateRegistrationPassword('Password1'), isNull);
      expect(
        validatePasswordConfirmation('Password2', 'Password1'),
        'Passwords do not match.',
      );
      expect(validatePasswordConfirmation('Password1', 'Password1'), isNull);
    });

    test(
      'allows optional Malaysian phone formats and validates company length',
      () {
        expect(validateRegistrationCompany(''), isNull);
        expect(validateRegistrationCompany('A' * 50), isNull);
        expect(
          validateRegistrationCompany('A' * 51),
          'Company name cannot exceed 50 characters.',
        );
        expect(validateMalaysianPhone(''), isNull);
        expect(validateMalaysianPhone('0123456789'), isNull);
        expect(validateMalaysianPhone('01234567890'), isNull);
        expect(validateMalaysianPhone('+60-12-345-6789'), isNull);
        expect(validateMalaysianPhone('012-3456789'), isNull);
        expect(validateMalaysianPhone('+60123456789'), isNull);
        for (final value in [
          '1234567890',
          '+65123456789',
          '012345678901',
          '012abc6789',
        ]) {
          expect(
            validateMalaysianPhone(value),
            'Please enter a valid Malaysian phone number.',
          );
        }
      },
    );

    testWidgets('enables Create Account only when the form is valid', (
      tester,
    ) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AuthManager.forTesting(),
          child: const MaterialApp(home: SignupScreen()),
        ),
      );

      ElevatedButton createAccountButton() => tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Create Account'),
      );

      expect(createAccountButton().onPressed, isNull);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'yy');
      await tester.enterText(fields.at(1), 'ahmad@example.com');
      await tester.enterText(fields.at(2), 'Password1');
      await tester.enterText(fields.at(3), 'Password1');
      await tester.pump();

      expect(createAccountButton().onPressed, isNotNull);

      await tester.enterText(fields.at(4), 'A' * 51);
      await tester.pump();
      expect(createAccountButton().onPressed, isNull);
      expect(
        find.text('Company name cannot exceed 50 characters.'),
        findsOneWidget,
      );
      await tester.enterText(fields.at(4), 'A' * 50);
      for (final phone in ['0123456789', '012-3456789', '+60123456789']) {
        await tester.enterText(fields.at(5), phone);
        await tester.pump();
        expect(
          tester.widget<TextFormField>(fields.at(5)).controller!.text,
          phone,
        );
        expect(createAccountButton().onPressed, isNotNull);
      }

      await tester.enterText(fields.at(5), '123');
      await tester.pump();

      expect(createAccountButton().onPressed, isNull);
      expect(
        find.text('Please enter a valid Malaysian phone number.'),
        findsOneWidget,
      );
    });
  });

  group('password reset errors', () {
    test('maps invalid email and rate limit errors', () {
      expect(
        friendlyPasswordResetError(
          const AuthApiException(
            'Email address is invalid',
            statusCode: '400',
            code: 'email_address_invalid',
          ),
        ),
        'Please enter a valid email address.',
      );
      expect(
        friendlyPasswordResetError(
          const AuthApiException(
            'Rate limit exceeded',
            statusCode: '429',
            code: 'over_email_send_rate_limit',
          ),
        ),
        'Too many reset attempts. Please try again later.',
      );
    });

    test('maps timeout, network and unknown failures', () {
      expect(
        friendlyPasswordResetError(TimeoutException('timeout')),
        contains('timed out'),
      );
      expect(
        friendlyPasswordResetError(const SocketException('offline')),
        contains('internet connection'),
      );
      expect(
        friendlyPasswordResetError(StateError('unknown')),
        'Unable to send the password reset email. Please try again.',
      );
    });
  });
}
