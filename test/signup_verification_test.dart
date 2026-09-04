import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_assginment/features/auth/auth_manager.dart';
import 'package:mobile_assginment/features/auth/login_screen.dart';
import 'package:mobile_assginment/features/auth/signup_screen.dart';
import 'package:mobile_assginment/services/supabase/auth_repository.dart';
import 'package:mobile_assginment/services/supabase/supabase_service.dart';

class _SignupRepository implements AuthRepository {
  final bool returnsSession;
  final Object? failure;
  final bool duplicate;
  _SignupRepository({
    this.returnsSession = false,
    this.failure,
    this.duplicate = false,
  });

  final events = StreamController<AuthState>.broadcast(sync: true);
  Session? session;
  int cleared = 0;

  @override
  User? get currentUser => session?.user;
  @override
  Session? get currentSession => session;
  @override
  Stream<AuthState> get authStateChanges => events.stream;
  @override
  Future<User?> restoreUser() async => null;

  @override
  Future<AuthResponse> signUp({
    required String fullName,
    required String email,
    required String password,
    required String companyName,
    required String phone,
  }) async {
    if (failure != null) throw failure!;
    final user = User(
      id: 'new-user',
      appMetadata: {},
      userMetadata: {'full_name': fullName},
      aud: 'authenticated',
      createdAt: '2026-09-04T00:00:00Z',
      email: email,
      identities: duplicate ? [] : null,
    );
    if (returnsSession) {
      session = Session(
        accessToken: 'test-access',
        tokenType: 'bearer',
        user: user,
      );
      events.add(AuthState(AuthChangeEvent.signedIn, session));
    }
    return AuthResponse(user: user, session: session);
  }

  @override
  Future<void> clearRegistrationSession() async {
    cleared++;
    session = null;
    events.add(AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<String?> _register(AuthManager manager) => manager.signUp(
  fullName: 'Test User',
  email: 'new@example.com',
  password: 'Password123',
);

void main() {
  test(
    'registration never loads Home even when signup emits signedIn',
    () async {
      for (final returnsSession in [false, true]) {
        final repository = _SignupRepository(returnsSession: returnsSession);
        var authenticated = 0;
        final manager = AuthManager(
          repository,
          null,
          onAuthenticationChanged: (_) async {
            authenticated++;
          },
        );
        await manager.initialize();
        expect(await _register(manager), isNull);
        await Future<void>.delayed(Duration.zero);
        expect(manager.isLoggedIn, isFalse);
        expect(manager.currentUser, isNull);
        expect(repository.session, isNull);
        expect(repository.cleared, returnsSession ? 1 : 0);
        expect(authenticated, 0);
        manager.dispose();
        await repository.events.close();
      }
    },
  );

  test(
    'duplicate identities and server errors remain friendly and distinct',
    () async {
      final repository = _SignupRepository(duplicate: true);
      final manager = AuthManager(repository, null);
      expect(
        await _register(manager),
        'An account with this email already exists.',
      );
      manager.dispose();
      await repository.events.close();
      final cases = <Object, String>{
        const AuthException('raw duplicate', code: 'user_already_exists'):
            'An account with this email already exists.',
        const AuthException('raw email', code: 'email_address_invalid'):
            'Please enter a valid email address.',
        const AuthException(
          'raw weak',
          code: 'weak_password',
        ): 'Password must contain at least 8 characters, one uppercase letter, one lowercase letter, and one number.',
        const AuthException('raw rate', statusCode: '429'):
            'Too many verification email requests. Please try again later.',
        TimeoutException(
          'raw timeout',
        ): 'The request timed out. Please check your connection and try again.',
        StateError('raw unknown'):
            'Unable to create your account. Please try again.',
      };
      for (final entry in cases.entries) {
        final repo = _SignupRepository(failure: entry.key);
        final auth = AuthManager(repo, null);
        expect(await _register(auth), entry.value);
        expect(auth.isLoggedIn, isFalse);
        expect(friendlySignUpError(entry.key), entry.value);
        auth.dispose();
        await repo.events.close();
      }
    },
  );

  testWidgets(
    'success dialog and signup draft survive rotation then clear on return',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _SignupRepository(returnsSession: true);
      final auth = AuthManager(repo, null);
      await auth.initialize();
      addTearDown(auth.dispose);
      addTearDown(repo.events.close);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthManager>.value(
          value: auth,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.ensureVisible(find.text('Sign Up'));
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Test User');
      await tester.enterText(fields.at(1), 'new@example.com');
      await tester.enterText(fields.at(2), 'Password123');
      await tester.enterText(fields.at(3), 'Password123');
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(fields.at(0)).controller!.text,
        'Test User',
      );
      final submit = find.widgetWithText(ElevatedButton, 'Create Account');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Account Created'), findsOneWidget);
      expect(auth.isLoggedIn, isFalse);
      for (final size in [
        const Size(390, 844),
        const Size(844, 390),
        const Size(390, 844),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(find.text('Account Created'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('Back to Login'));
      await tester.pumpAndSettle();
      expect(find.byType(SignupScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.ensureVisible(find.text('Sign Up'));
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      for (final field in tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      )) {
        expect(field.controller!.text, isEmpty);
      }
    },
  );
}
