import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_assginment/features/auth/auth_manager.dart';
import 'package:mobile_assginment/features/auth/auth_validators.dart';
import 'package:mobile_assginment/features/auth/signup_screen.dart';
import 'package:mobile_assginment/services/supabase/supabase_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('registration validation', () {
    test('validates the full name and email', () {
      expect(validateFullName('  '), 'Please enter your full name.');
      expect(validateFullName('Al'), 'Please enter your full name.');
      expect(validateFullName(' Ahmad Ali '), isNull);
      expect(
        validateEmailAddress('invalid-email'),
        'Please enter a valid email address.',
      );
      expect(validateEmailAddress('user@example.com'), isNull);
    });

    test('requires a strong password and exact confirmation', () {
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

    test('allows only an optional 10 or 11 digit phone number', () {
      expect(validateMalaysianPhone(''), isNull);
      expect(validateMalaysianPhone('0123456789'), isNull);
      expect(validateMalaysianPhone('01234567890'), isNull);
      expect(
        validateMalaysianPhone('+60-12-345-6789'),
        'Please enter a valid Malaysian phone number.',
      );
    });

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
      await tester.enterText(fields.at(0), 'Ahmad Ali');
      await tester.enterText(fields.at(1), 'ahmad@example.com');
      await tester.enterText(fields.at(2), 'Password1');
      await tester.enterText(fields.at(3), 'Password1');
      await tester.pump();

      expect(createAccountButton().onPressed, isNotNull);

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
