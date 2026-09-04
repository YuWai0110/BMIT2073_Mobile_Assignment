import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_assginment/core/widgets/app_snackbar.dart';

void main() {
  testWidgets('success feedback stays visible in portrait and landscape', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => AppSnackBar.success(
                    context,
                    'Scheme updated successfully',
                  ),
                  child: const Text('Save'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.behavior, SnackBarBehavior.floating);
      expect(bar.backgroundColor, Colors.green.shade700);
      expect(bar.duration, const Duration(seconds: 2));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      final message = tester.getRect(find.text('Scheme updated successfully'));
      expect(message.left, greaterThanOrEqualTo(0));
      expect(message.right, lessThanOrEqualTo(size.width));
      expect(message.bottom, lessThan(size.height));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    }
  });
}
