import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_assginment/features/interest_trigger/trigger_manager.dart';
import 'package:mobile_assginment/features/interest_trigger/trigger_screen.dart';
import 'package:mobile_assginment/services/notification/local_notification_service.dart';
import 'package:mobile_assginment/services/notification/notification_delivery_guard.dart';

import 'persistence_manager_test.dart' show MemoryDatabase;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'events survive refresh, inbox deletion, manager recreation and user switching',
    () async {
      final database = MemoryDatabase();
      final sent = <String>[];
      TriggerManager createManager() => TriggerManager(
        database: database,
        localNotificationService: _RecordingNotifications(sent),
      );
      final manager = createManager();
      await manager.initialize(userId: 'uuid-a');
      manager.addRule(
        TriggerRule(
          id: 'rule-1',
          targetOPR: 3,
          equipmentType: 'AI Vision Inspector',
        ),
      );
      manager.checkTriggers(3, 2024);
      manager.checkTriggers(3, 2024);
      await manager.waitForPendingWrites();
      expect(sent, hasLength(1));
      expect(manager.notifications, hasLength(1));

      await manager.refresh();
      manager.checkTriggers(3, 2024);
      manager.checkTriggers(4, 2025);
      manager.checkTriggers(3, 2024);
      manager.clearInbox();
      manager.checkTriggers(3, 2024);
      await manager.waitForPendingWrites();
      expect(sent, hasLength(1));
      expect(manager.notifications, hasLength(1));

      final reloaded = createManager();
      await reloaded.initialize(userId: 'uuid-a');
      reloaded.checkTriggers(3, 2024);
      await reloaded.waitForPendingWrites();
      expect(sent, hasLength(1));
      reloaded.checkTriggers(3, 2023);
      reloaded.addRule(
        TriggerRule(
          id: 'rule-2',
          targetOPR: 3,
          equipmentType: 'AI Vision Inspector',
        ),
      );
      reloaded.checkTriggers(3, 2024);
      await reloaded.waitForPendingWrites();
      expect(sent, hasLength(3));
      expect(reloaded.notifications, hasLength(2));

      await reloaded.setUser('uuid-b');
      reloaded.checkTriggers(3, 2024);
      await reloaded.waitForPendingWrites();
      expect(sent, hasLength(3));
      reloaded.addRule(
        TriggerRule(
          id: 'rule-1',
          targetOPR: 3,
          equipmentType: 'AI Vision Inspector',
        ),
      );
      reloaded.checkTriggers(3, 2024);
      await reloaded.waitForPendingWrites();
      expect(sent, hasLength(4));
      expect(sent.last, '["uuid-b","rule-1",2024]');
      expect(reloaded.notifications.single.userId, 'uuid-b');
      await reloaded.setUser('uuid-a');
      reloaded.checkTriggers(3, 2024);
      await reloaded.waitForPendingWrites();
      expect(sent, hasLength(4));
      manager.dispose();
      reloaded.dispose();
    },
  );

  test(
    'delivery guard serializes duplicate requests and releases failed attempts',
    () async {
      final guard = NotificationDeliveryGuard();
      var count = 0;
      await Future.wait(
        List.generate(
          5,
          (_) => guard.deliverOnce('event', () async {
            count++;
          }),
        ),
      );
      expect(count, 1);
      await NotificationDeliveryGuard().deliverOnce('event', () async {
        count++;
      });
      expect(count, 1);
      await expectLater(
        guard.deliverOnce('failed', () async {
          throw StateError('failed');
        }),
        throwsStateError,
      );
      await guard.deliverOnce('failed', () async {
        count++;
      });
      expect(count, 2);
    },
  );

  testWidgets('rotating and rebuilding TriggerScreen does not deliver again', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    final sent = <String>[];
    final manager = TriggerManager(
      database: MemoryDatabase(),
      localNotificationService: _RecordingNotifications(sent),
    );
    await manager.initialize(userId: 'uuid-a');
    manager.addRule(
      TriggerRule(
        id: 'rule-1',
        targetOPR: 3,
        equipmentType: 'AI Vision Inspector',
      ),
    );
    await manager.waitForPendingWrites();
    for (var i = 0; i < 5; i++) {
      tester.view.physicalSize = i.isEven
          ? const Size(390, 844)
          : const Size(844, 390);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: manager,
          child: MaterialApp(
            home: Scaffold(body: TriggerScreen(key: ValueKey(i))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(manager.waitForPendingWrites);
      expect(sent, hasLength(1));
      expect(tester.takeException(), isNull);
    }
    await tester.runAsync(manager.refresh);
    manager.checkTriggers(3, 2024);
    await tester.runAsync(manager.waitForPendingWrites);
    expect(sent, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    manager.dispose();
  });
}

class _RecordingNotifications implements OprNotificationService {
  _RecordingNotifications(this.sent);
  final List<String> sent;
  final NotificationDeliveryGuard guard = NotificationDeliveryGuard();

  @override
  Future<void> showOprAlert({
    required String notificationId,
    required String body,
  }) {
    return guard.deliverOnce(notificationId, () async {
      sent.add(notificationId);
    });
  }
}
