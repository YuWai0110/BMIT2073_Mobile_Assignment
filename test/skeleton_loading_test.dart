import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_assginment/core/theme/app_theme.dart';
import 'package:mobile_assginment/core/theme/theme_manager.dart';
import 'package:mobile_assginment/core/widgets/skeleton_box.dart';
import 'package:mobile_assginment/core/widgets/loading_skeletons.dart';
import 'package:mobile_assginment/features/auth/auth_manager.dart';
import 'package:mobile_assginment/features/auth/profile_screen.dart';
import 'package:mobile_assginment/features/loan_approval/loan_manager.dart';
import 'package:mobile_assginment/features/loan_approval/loan_screen.dart';

void main() {
  testWidgets('skeletons pulse and fit both orientations and themes', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      tester.view.physicalSize = size;
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        for (final child in [
          const ProfileSkeleton(),
          const SingleChildScrollView(child: LoanApplicationsSkeleton()),
          const AiAdvisorSkeleton(),
        ]) {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(body: child),
            ),
          );
          await tester.pump();
          final opacity = find.byType(AnimatedOpacity).first;
          expect(tester.widget<AnimatedOpacity>(opacity).opacity, 0.45);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 901));
          await tester.pump();
          expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
          expect(tester.takeException(), isNull);
          final box = tester.widget<Container>(
            find.descendant(
              of: find.byType(SkeletonBox).first,
              matching: find.byType(Container),
            ),
          );
          final color = (box.decoration! as BoxDecoration).color!;
          expect(
            color.a,
            closeTo(theme.brightness == Brightness.dark ? 0.18 : 0.12, 0.001),
          );
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'profile and loan skeletons follow manager state and fade to data',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeManager(await SharedPreferences.getInstance());
      final auth = _LoadingAuth();
      final loan = _LoadingLoans();
      Future<void> pump(Widget child) => tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: theme),
            ChangeNotifierProvider<AuthManager>.value(value: auth),
            ChangeNotifierProvider<LoanManager>.value(value: loan),
          ],
          child: MaterialApp(home: Scaffold(body: child)),
        ),
      );
      await pump(const ProfileScreen());
      await tester.pump();
      expect(find.byType(ProfileSkeleton), findsOneWidget);
      auth.finish();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileSkeleton), findsNothing);
      expect(find.text('Profile Information'), findsOneWidget);
      for (final banker in [false, true]) {
        loan.loading = true;
        await pump(LoanScreen(isBanker: banker));
        await tester.pump();
        expect(find.byType(LoanApplicationsSkeleton), findsOneWidget);
        if (!banker) expect(find.text('New Loan Application'), findsOneWidget);
        loan.finish();
        await tester.pumpAndSettle();
        expect(find.byType(LoanApplicationsSkeleton), findsNothing);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
      loan.dispose();
      theme.dispose();
    },
  );
}

class _LoadingAuth extends AuthManager {
  _LoadingAuth() : super.forTesting(loggedIn: true);
  bool loading = true;
  @override
  bool get isProfileLoading => loading;
  void finish() {
    loading = false;
    notifyListeners();
  }
}

class _LoadingLoans extends LoanManager {
  bool loading = true;
  @override
  bool get isLoading => loading;
  void finish() {
    loading = false;
    notifyListeners();
  }
}
