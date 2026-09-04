import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_assginment/core/theme/theme_manager.dart';
import 'package:mobile_assginment/features/auth/auth_manager.dart';
import 'package:mobile_assginment/features/auth/login_screen.dart';
import 'package:mobile_assginment/features/calculator_roi/calc_manager.dart';
import 'package:mobile_assginment/features/interest_trigger/trigger_manager.dart';
import 'package:mobile_assginment/features/loan_approval/loan_manager.dart';
import 'package:mobile_assginment/features/onboarding/onboarding_screen.dart';
import 'package:mobile_assginment/main.dart';

class _LoginAuth extends AuthManager {
  _LoginAuth() : super.forTesting();
  bool signedIn = false;
  @override
  bool get isLoggedIn => signedIn;
  @override
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    signedIn = true;
    notifyListeners();
    return null;
  }

  @override
  Future<void> logout() async {
    signedIn = false;
    notifyListeners();
  }
}

Future<void> _pumpApp(
  WidgetTester tester,
  AuthManager auth, {
  bool session = false,
}) async {
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthManager>.value(value: auth),
        ChangeNotifierProvider(create: (_) => ThemeManager(preferences)),
        ChangeNotifierProvider(create: (_) => CalcManager()),
        ChangeNotifierProvider(create: (_) => TriggerManager()),
        ChangeNotifierProvider(create: (_) => LoanManager()),
      ],
      child: MainApp(hasStartupSession: session),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'fresh onboarding preserves page on rotation then login opens Home',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final auth = _LoginAuth();
      addTearDown(auth.dispose);
      await _pumpApp(tester, auth);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      final originalState = tester.state(find.byType(OnboardingScreen));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(OnboardingScreen)), same(originalState));
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        1,
      );
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
      await auth.login(email: 'test@example.com', password: 'Password123');
      await tester.pumpAndSettle();
      expect(find.text('Interest Rate Monitor'), findsOneWidget);
      await auth.logout();
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'restored session skips onboarding on a new app instance and resets on logout',
    (tester) async {
      final auth = AuthManager.forTesting(loggedIn: true);
      addTearDown(auth.dispose);
      await _pumpApp(tester, auth, session: true);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.text('Interest Rate Monitor'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      final restored = AuthManager.forTesting(loggedIn: true);
      addTearDown(restored.dispose);
      await _pumpApp(tester, restored, session: true);
      expect(find.text('Interest Rate Monitor'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      await restored.logout();
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
