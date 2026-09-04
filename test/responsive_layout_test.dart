import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_assginment/core/theme/theme_manager.dart';
import 'package:mobile_assginment/core/responsive_input_dialog.dart';
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
import 'package:mobile_assginment/services/database/database_service.dart';
import 'package:provider/provider.dart';

const _screenSizes = [Size(390, 844), Size(844, 390), Size(1280, 800)];
late SharedPreferences _themePreferences;

Future<void> _pumpAtSize(WidgetTester tester, Size size, Widget child) async {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => ThemeManager(_themePreferences),
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _themePreferences = await SharedPreferences.getInstance();
  });
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
          create: (_) => AuthManager.forTesting(),
          child: const LoginScreen(),
        ),
      );
      expect(find.text('Welcome Back'), findsOneWidget);
    }
  });

  testWidgets('banker dialog closes before authentication and stays safe', (
    tester,
  ) async {
    await _pumpAtSize(
      tester,
      const Size(390, 844),
      ChangeNotifierProvider(
        create: (_) => AuthManager.forTesting(),
        child: const LoginScreen(),
      ),
    );

    await tester.longPress(find.text('BNM SME Platform'));
    await tester.pumpAndSettle();
    final dialog = find.byType(ResponsiveInputDialog);
    expect(dialog, findsOneWidget);
    final fields = find.descendant(
      of: dialog,
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'banker@bnm.gov.my');
    await tester.enterText(fields.at(1), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Enter'));
    await tester.pumpAndSettle();

    expect(dialog, findsNothing);
    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('demo account buttons only auto-fill credentials', (
    tester,
  ) async {
    await _pumpAtSize(
      tester,
      const Size(390, 844),
      ChangeNotifierProvider(
        create: (_) => AuthManager.forTesting(),
        child: const LoginScreen(),
      ),
    );

    await tester.ensureVisible(find.text('Banker Demo'));
    await tester.tap(find.text('Banker Demo'));
    await tester.pump();
    final emailField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(0),
    );
    final passwordField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(1),
    );

    expect(emailField.controller?.text, 'banker@bnm.gov.my');
    expect(passwordField.controller?.text, 'password123');
    expect(find.byType(BottomNavigationBar), findsNothing);
  });

  testWidgets('signup supports portrait and landscape sizes', (tester) async {
    for (final size in _screenSizes) {
      await _pumpAtSize(
        tester,
        size,
        ChangeNotifierProvider(
          create: (_) => AuthManager.forTesting(),
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
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final auth = AuthManager.forTesting(loggedIn: true);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => ThemeManager(_themePreferences),
            ),
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => LoanManager()),
            ChangeNotifierProvider(create: (_) => CalcManager()),
            ChangeNotifierProvider(create: (_) => TriggerManager()),
          ],
          child: const MainApp(),
        ),
      );
      expect(find.text('Skip'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(RefreshIndicator), findsOneWidget);
      if (size.width >= 700 && size.width > size.height) {
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(BottomNavigationBar), findsNothing);
      } else {
        expect(find.byType(NavigationRail), findsNothing);
        expect(find.byType(BottomNavigationBar), findsOneWidget);
      }
    }
  });

  testWidgets('landscape navigation rail preserves the selected index', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    final auth = AuthManager.forTesting(loggedIn: true);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => ThemeManager(_themePreferences),
          ),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(create: (_) => LoanManager()),
          ChangeNotifierProvider(create: (_) => CalcManager()),
          ChangeNotifierProvider(create: (_) => TriggerManager()),
        ],
        child: const MainApp(),
      ),
    );
    expect(find.text('Skip'), findsNothing);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calculator'));
    await tester.pumpAndSettle();

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.selectedIndex, 2);
    expect(find.widgetWithText(AppBar, 'ROI Calculator'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);

    tester.view.physicalSize = const Size(800, 1280);
    await tester.pumpAndSettle();

    final bottomNavigation = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(bottomNavigation.currentIndex, 2);
    expect(find.byType(NavigationRail), findsNothing);
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

  testWidgets('trigger dialog works with the keyboard in both orientations', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    for (final size in const [Size(390, 844), Size(844, 390)]) {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = FakeViewPadding.zero;
      final manager = TriggerManager(database: _DialogDatabase());
      await manager.initialize(userId: 'dialog-user');

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: manager,
          child: const MaterialApp(home: Scaffold(body: TriggerScreen())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton).last);
      await tester.pumpAndSettle();

      final dialog = find.byType(ResponsiveInputDialog);
      final targetRateField = find
          .descendant(of: dialog, matching: find.byType(TextFormField))
          .first;
      await tester.tap(targetRateField);
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.width > size.height ? 220 : 300,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.enterText(targetRateField, '2.75');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      expect(manager.rules, hasLength(1));
      expect(manager.rules.single.targetOPR, 2.75);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'save scheme dialog works with the keyboard in both orientations',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      for (final size in const [Size(390, 844), Size(844, 390)]) {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = FakeViewPadding.zero;
        final manager = CalcManager(database: _DialogDatabase());
        await manager.initialize(userId: 'dialog-user');

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: manager,
            child: const MaterialApp(home: Scaffold(body: CalcScreen())),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(0), '50000.00');
        await tester.enterText(find.byType(TextFormField).at(1), '1');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save This Scheme'));
        await tester.tap(find.text('Save This Scheme'));
        await tester.pumpAndSettle();

        final dialog = find.byType(ResponsiveInputDialog);
        final schemeNameField = find.descendant(
          of: dialog,
          matching: find.byType(TextField),
        );
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.width > size.height ? 220 : 300,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.enterText(schemeNameField, 'Factory Upgrade');
        await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Save'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
        await tester.pumpAndSettle();

        expect(dialog, findsNothing);
        expect(manager.schemes, hasLength(1));
        expect(manager.schemes.single.title, 'Factory Upgrade');
        expect(tester.takeException(), isNull);
      }
    },
  );

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

  testWidgets('calculator validates input and supports a 15-year term', (
    tester,
  ) async {
    await _pumpAtSize(
      tester,
      const Size(390, 844),
      ChangeNotifierProvider(
        create: (_) => CalcManager(),
        child: const Scaffold(body: CalcScreen()),
      ),
    );

    final fields = find.byType(TextFormField);
    expect(tester.widget<TextFormField>(fields.at(0)).controller!.text, '0');
    expect(tester.widget<TextFormField>(fields.at(1)).controller!.text, '0');

    await tester.enterText(fields.at(1), '-5');
    expect(tester.widget<TextFormField>(fields.at(1)).controller!.text, '-5');

    await tester.ensureVisible(find.text('Save This Scheme'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Save This Scheme'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Enter a whole number from 1 to 999.'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('180 months (15 yrs)'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('180 months (15 yrs)'), findsOneWidget);
  });

  testWidgets('profile supports portrait and landscape sizes', (tester) async {
    for (final size in _screenSizes) {
      final auth = AuthManager.forTesting(loggedIn: true);
      await _pumpAtSize(
        tester,
        size,
        ChangeNotifierProvider.value(value: auth, child: const ProfileScreen()),
      );
      expect(find.text('Profile Information'), findsOneWidget);
    }
  });
}

class _DialogDatabase implements LocalDatabase {
  @override
  Future<void> initialize() async {}

  @override
  Future<List<Map<String, Object?>>> getEmiSchemes(String userId) async => [];

  @override
  Future<void> upsertEmiScheme(Map<String, Object?> values) async {}

  @override
  Future<void> deleteEmiScheme(String id, String userId) async {}

  @override
  Future<List<Map<String, Object?>>> getTriggerRules(String userId) async => [];

  @override
  Future<void> upsertTriggerRule(Map<String, Object?> values) async {}

  @override
  Future<void> deleteTriggerRule(String id, String userId) async {}

  @override
  Future<List<Map<String, Object?>>> getNotifications(String userId) async =>
      [];

  @override
  Future<void> upsertNotification(Map<String, Object?> values) async {}

  @override
  Future<void> markNotificationRead(
    String id,
    bool isRead,
    String userId,
  ) async {}

  @override
  Future<void> deleteNotification(String id, String userId) async {}

  @override
  Future<void> clearNotifications(String userId) async {}
}
