import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_assginment/features/auth/auth_manager.dart';
import 'package:mobile_assginment/features/auth/login_screen.dart';
import 'package:mobile_assginment/features/auth/profile_screen.dart';
import 'package:mobile_assginment/features/auth/signup_screen.dart';
import 'package:mobile_assginment/features/calculator_roi/calc_manager.dart';
import 'package:mobile_assginment/features/calculator_roi/calc_screen.dart';
import 'package:mobile_assginment/features/interest_trigger/trigger_manager.dart';
import 'package:mobile_assginment/features/interest_trigger/trigger_screen.dart';
import 'package:mobile_assginment/features/loan_approval/loan_manager.dart';
import 'package:mobile_assginment/features/loan_approval/loan_screen.dart';
import 'package:mobile_assginment/features/onboarding/onboarding_screen.dart';
import 'package:mobile_assginment/main.dart';
import 'package:provider/provider.dart';

const _screenSizes = [Size(390, 844), Size(844, 390), Size(1280, 800)];

Future<void> _pumpAtSize(WidgetTester tester, Size size, Widget child) async {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('onboarding supports portrait and landscape sizes', (
    tester,
  ) async {
    for (final size in _screenSizes) {
      await _pumpAtSize(tester, size, OnboardingScreen(onFinished: () {}));
      expect(find.text('Skip'), findsOneWidget);
    }
  });

  testWidgets('login supports portrait and landscape sizes', (tester) async {
    for (final size in _screenSizes) {
      await _pumpAtSize(
        tester,
        size,
        ChangeNotifierProvider(
          create: (_) => AuthManager(),
          child: const LoginScreen(),
        ),
      );
      expect(find.text('Welcome Back'), findsOneWidget);
    }
  });

  testWidgets('signup supports portrait and landscape sizes', (tester) async {
    for (final size in _screenSizes) {
      await _pumpAtSize(
        tester,
        size,
        ChangeNotifierProvider(
          create: (_) => AuthManager(),
          child: const SignupScreen(),
        ),
      );
      expect(find.text('Create Account'), findsWidgets);
    }
  });

  testWidgets('home supports portrait and landscape sizes', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in _screenSizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final auth = AuthManager();
      auth.login(email: 'sme@techvision.com', password: 'password123');
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => LoanManager()),
            ChangeNotifierProvider(create: (_) => CalcManager()),
            ChangeNotifierProvider(create: (_) => TriggerManager()),
          ],
          child: const MainApp(),
        ),
      );
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    }
  });

  testWidgets('rates supports portrait and landscape sizes', (tester) async {
    for (final size in _screenSizes) {
      await _pumpAtSize(
        tester,
        size,
        ChangeNotifierProvider(
          create: (_) => TriggerManager(),
          child: const TriggerScreen(),
        ),
      );
      expect(find.text('BNM Interest Rate Timeline'), findsOneWidget);
    }
  });

  testWidgets('SME loans support portrait and landscape sizes', (tester) async {
    for (final size in _screenSizes) {
      await _pumpAtSize(
        tester,
        size,
        ChangeNotifierProvider(
          create: (_) => LoanManager(),
          child: const LoanScreen(isBanker: false),
        ),
      );
      expect(find.text('New Loan Application'), findsOneWidget);
    }
  });

  testWidgets('banker loans support portrait and landscape sizes', (
    tester,
  ) async {
    for (final size in _screenSizes) {
      await _pumpAtSize(
        tester,
        size,
        ChangeNotifierProvider(
          create: (_) => LoanManager(),
          child: const LoanScreen(isBanker: true),
        ),
      );
      expect(find.text('No loan applications to review'), findsOneWidget);
    }
  });

  testWidgets('calculator supports portrait and landscape sizes', (
    tester,
  ) async {
    for (final size in _screenSizes) {
      await _pumpAtSize(
        tester,
        size,
        ChangeNotifierProvider(
          create: (_) => CalcManager(),
          child: const CalcScreen(),
        ),
      );
      expect(find.text('Calculation Results'), findsOneWidget);
    }
  });

  testWidgets('profile supports portrait and landscape sizes', (tester) async {
    for (final size in _screenSizes) {
      final auth = AuthManager();
      auth.login(email: 'sme@techvision.com', password: 'password123');
      await _pumpAtSize(
        tester,
        size,
        ChangeNotifierProvider.value(value: auth, child: const ProfileScreen()),
      );
      expect(find.text('Profile Information'), findsOneWidget);
    }
  });
}
