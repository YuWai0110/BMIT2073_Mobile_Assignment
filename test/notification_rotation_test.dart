import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile_assginment/features/interest_trigger/trigger_manager.dart';
import 'package:mobile_assginment/features/interest_trigger/trigger_screen.dart';

import 'persistence_manager_test.dart'
    show MemoryDatabase, FakeOprNotificationService;

void main() {
  test(
    'banner claims are unique per user rule and year, independent of inbox',
    () async {
      final manager = TriggerManager(database: MemoryDatabase());
      await manager.initialize(userId: 'user-a');
      manager.addRule(
        TriggerRule(
          id: 'one',
          targetOPR: 3,
          equipmentType: 'AI Vision Inspector',
        ),
      );
      expect(manager.checkTriggers(3, 2024, forBanner: true), hasLength(1));
      expect(manager.checkTriggers(3, 2024, forBanner: true), isEmpty);
      await manager.refresh();
      expect(manager.checkTriggers(3, 2024, forBanner: true), isEmpty);
      manager.clearInbox();
      expect(manager.checkTriggers(3, 2024, forBanner: true), isEmpty);
      expect(manager.notifications, hasLength(1));
      expect(manager.checkTriggers(3, 2023, forBanner: true), hasLength(1));
      expect(manager.checkTriggers(3, 2024, forBanner: true), isEmpty);
      manager.addRule(
        TriggerRule(
          id: 'two',
          targetOPR: 3,
          equipmentType: 'AI Vision Inspector',
        ),
      );
      expect(manager.checkTriggers(3, 2024, forBanner: true), hasLength(1));
      await manager.setUser('user-b');
      expect(manager.checkTriggers(3, 2024, forBanner: true), isEmpty);
      manager.addRule(
        TriggerRule(
          id: 'one',
          targetOPR: 3,
          equipmentType: 'AI Vision Inspector',
        ),
      );
      expect(manager.checkTriggers(3, 2024, forBanner: true), hasLength(1));
      await manager.waitForPendingWrites();
      manager.dispose();
    },
  );

  testWidgets(
    'open inbox closes on ten rotations and can reopen without banners',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      final local = FakeOprNotificationService();
      final manager = TriggerManager(
        database: MemoryDatabase(),
        localNotificationService: local,
      );
      await manager.initialize(userId: 'user-a');
      manager.addRule(
        TriggerRule(
          id: 'one',
          targetOPR: 3,
          equipmentType: 'AI Vision Inspector',
        ),
      );
      Future<void> pumpPage(int key) => tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: manager,
          child: MaterialApp(
            home: Scaffold(body: TriggerScreen(key: ValueKey(key))),
          ),
        ),
      );
      await pumpPage(0);
      await tester.pumpAndSettle();
      final oldBannerAction = tester
          .widget<SnackBar>(find.byType(SnackBar))
          .action!
          .onPressed;
      ScaffoldMessenger.of(tester.element(find.byType(TriggerScreen)))
          .removeCurrentSnackBar();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      final inboxButton = find.byWidgetPredicate(
        (widget) => widget is FloatingActionButton && widget.heroTag == 'inbox',
      );
      for (var i = 1; i <= 10; i++) {
        await tester.tap(inboxButton);
        await tester.pumpAndSettle();
        expect(find.text('Notification Inbox (1)'), findsOneWidget);
        tester.view.physicalSize = i.isOdd
            ? const Size(844, 390)
            : const Size(390, 844);
        await pumpPage(i);
        await tester.pumpAndSettle();
        expect(find.text('Notification Inbox (1)'), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(manager.unreadCount, 1);
        expect(tester.takeException(), isNull);
      }
      oldBannerAction();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Notification Inbox (1)'), findsNothing);
      await tester.tap(inboxButton);
      await tester.pumpAndSettle();
      expect(find.text('Notification Inbox (1)'), findsOneWidget);
      await manager.waitForPendingWrites();
      expect(local.alertBodies, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      manager.dispose();
    },
  );
}
