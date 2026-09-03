import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_assginment/core/theme/app_theme.dart';
import 'package:mobile_assginment/core/theme/theme_manager.dart';
import 'package:mobile_assginment/features/auth/auth_manager.dart';
import 'package:mobile_assginment/features/auth/profile_screen.dart';
import 'package:mobile_assginment/main.dart';
import 'package:mobile_assginment/features/calculator_roi/calc_manager.dart';
import 'package:mobile_assginment/features/interest_trigger/trigger_manager.dart';
import 'package:mobile_assginment/features/loan_approval/loan_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to system and safely ignores an unknown saved mode', () async {
    final prefs = await SharedPreferences.getInstance();
    final first = ThemeManager(prefs);
    expect(first.themeMode, ThemeMode.system);
    first.dispose();
    await prefs.setString(ThemeManager.preferenceKey, 'invalid');
    final restored = ThemeManager(prefs);
    expect(restored.themeMode, ThemeMode.system);
    restored.dispose();
  });

  test('all modes update immediately and survive manager recreation', () async {
    final prefs = await SharedPreferences.getInstance();
    final manager = ThemeManager(prefs);
    for (final mode in ThemeMode.values) {
      final saved = manager.setThemeMode(mode);
      expect(manager.themeMode, mode);
      expect(await saved, isTrue);
      await prefs.reload();
      final restored = ThemeManager(prefs);
      expect(restored.themeMode, mode);
      restored.dispose();
    }
    manager.dispose();
  });

  test('rapid theme changes persist the last choice', () async {
    final prefs = await SharedPreferences.getInstance();
    final manager = ThemeManager(prefs);
    await Future.wait([
      manager.setThemeMode(ThemeMode.dark),
      manager.setThemeMode(ThemeMode.light),
      manager.setThemeMode(ThemeMode.system),
    ]);
    expect(prefs.getString(ThemeManager.preferenceKey), 'system');
    manager.dispose();
  });

  testWidgets('all tabs support dark portrait and landscape layouts', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.physicalSize = size;
      final manager = ThemeManager(await SharedPreferences.getInstance());
      await manager.setThemeMode(ThemeMode.dark);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: manager),
            ChangeNotifierProvider(
              create: (_) => AuthManager.forTesting(loggedIn: true),
            ),
            ChangeNotifierProvider(create: (_) => CalcManager()),
            ChangeNotifierProvider(create: (_) => TriggerManager()),
            ChangeNotifierProvider(create: (_) => LoanManager()),
          ],
          child: const MainApp(),
        ),
      );
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      for (final label in ['Loans', 'Calculator', 'Profile', 'Rates']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          Theme.of(tester.element(find.byType(AppBar))).brightness,
          Brightness.dark,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      manager.dispose();
    }
  });

  testWidgets('MaterialApp follows explicit and system brightness', (
    tester,
  ) async {
    final manager = ThemeManager(await SharedPreferences.getInstance());
    addTearDown(manager.dispose);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: manager),
          ChangeNotifierProvider(create: (_) => AuthManager.forTesting()),
        ],
        child: const MainApp(),
      ),
    );
    Brightness brightness() =>
        Theme.of(tester.element(find.text('Skip'))).brightness;
    expect(brightness(), Brightness.light);
    await manager.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);
    await manager.setThemeMode(ThemeMode.system);
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.light);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);
    await manager.setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.light);
  });

  testWidgets('Profile theme selector works in portrait and landscape', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.physicalSize = size;
      final manager = ThemeManager(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: manager),
            ChangeNotifierProvider(
              create: (_) => AuthManager.forTesting(loggedIn: true),
            ),
          ],
          child: Consumer<ThemeManager>(
            builder: (context, theme, child) => MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: theme.themeMode,
              home: const Scaffold(body: ProfileScreen()),
            ),
          ),
        ),
      );
      for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) {
        final label = switch (mode) {
          ThemeMode.dark => 'Dark',
          ThemeMode.light => 'Light',
          ThemeMode.system => 'System',
        };
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(manager.themeMode, mode);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      manager.dispose();
    }
  });
}
