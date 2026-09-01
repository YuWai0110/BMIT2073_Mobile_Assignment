import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_assginment/features/calculator_roi/calc_manager.dart';
import 'package:mobile_assginment/features/interest_trigger/trigger_manager.dart';
import 'package:mobile_assginment/features/interest_trigger/trigger_screen.dart';
import 'package:mobile_assginment/services/database/database_service.dart';
import 'package:provider/provider.dart';

void main() {
  group('CalcManager persistence', () {
    test('restores, updates, and deletes EMI schemes', () async {
      final database = MemoryDatabase();
      final manager = CalcManager(database: database);
      await manager.initialize();

      final scheme = CalcScheme(
        id: 'scheme-1',
        title: 'Robotic Arm',
        equipmentPrice: 50000,
        unitCount: 2,
        loanTermMonths: 36,
        interestRate: 4.5,
        monthlyPayment: 2974.79,
        totalPayment: 107092.44,
      );
      manager.saveScheme(scheme);
      await manager.waitForPendingWrites();

      final restored = CalcManager(database: database);
      await restored.initialize();
      expect(restored.schemes, hasLength(1));
      expect(restored.schemes.single.loanTermMonths, 36);
      expect(restored.schemes.single.unitCount, 2);

      restored.updateScheme(scheme.copyWith(title: 'Updated Robotic Arm'));
      await restored.waitForPendingWrites();

      final updated = CalcManager(database: database);
      await updated.initialize();
      expect(updated.schemes.single.title, 'Updated Robotic Arm');

      updated.deleteScheme(scheme.id);
      await updated.waitForPendingWrites();

      final deleted = CalcManager(database: database);
      await deleted.initialize();
      expect(deleted.schemes, isEmpty);
    });
  });

  group('TriggerManager persistence', () {
    test('restores rules and notification read state', () async {
      final database = MemoryDatabase();
      final manager = TriggerManager(database: database);
      await manager.initialize(userId: 'user-a');

      final rule = TriggerRule(
        id: 'rule-1',
        targetOPR: 3,
        equipmentType: 'Robotic Arm',
      );
      manager.addRule(rule);
      manager.toggleRule(rule.id);
      manager.toggleRule(rule.id);
      manager.editRule(rule.copyWith(targetOPR: 3.25));
      final messages = manager.checkTriggers(3, 2026);
      await manager.waitForPendingWrites();

      expect(messages, hasLength(1));

      final restored = TriggerManager(database: database);
      await restored.initialize(userId: 'user-a');
      expect(restored.rules, hasLength(1));
      expect(restored.rules.single.targetOPR, 3.25);
      expect(restored.rules.single.isEnabled, isTrue);
      expect(restored.notifications, hasLength(1));
      expect(restored.unreadCount, 1);

      final notificationId = restored.notifications.single.id;
      restored.markNotificationRead(notificationId);
      await restored.waitForPendingWrites();

      final readState = TriggerManager(database: database);
      await readState.initialize(userId: 'user-a');
      expect(readState.unreadCount, 0);

      readState.deleteNotification(notificationId);
      readState.removeRule(rule.id);
      await readState.waitForPendingWrites();

      final deleted = TriggerManager(database: database);
      await deleted.initialize(userId: 'user-a');
      expect(deleted.notifications, isEmpty);
      expect(deleted.rules, isEmpty);
    });

    test('isolates trigger rules by authenticated user', () async {
      final database = MemoryDatabase();
      final manager = TriggerManager(database: database);
      await manager.initialize(userId: 'user-a');
      manager.addRule(
        TriggerRule(
          id: 'user-a-rule',
          targetOPR: 3,
          equipmentType: 'Robotic Arm',
        ),
      );
      await manager.waitForPendingWrites();

      await manager.setUser('user-b');
      expect(manager.rules, isEmpty);
      manager.addRule(
        TriggerRule(
          id: 'user-b-rule',
          targetOPR: 2.75,
          equipmentType: 'AI Vision Inspector',
        ),
      );
      await manager.waitForPendingWrites();

      await manager.setUser('user-a');
      expect(manager.rules.map((rule) => rule.id), ['user-a-rule']);
    });
  });

  testWidgets('TriggerScreen checks persisted rules after the first frame', (
    tester,
  ) async {
    final database = MemoryDatabase();
    final manager = TriggerManager(database: database);
    await manager.initialize(userId: 'user-a');
    manager.addRule(
      TriggerRule(
        id: 'startup-rule',
        targetOPR: 3.25,
        equipmentType: 'Robotic Arm',
      ),
    );
    await manager.waitForPendingWrites();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: manager,
        child: const MaterialApp(home: Scaffold(body: TriggerScreen())),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}

class MemoryDatabase implements LocalDatabase {
  final Map<String, Map<String, Object?>> _schemes = {};
  final Map<String, Map<String, Object?>> _rules = {};
  final Map<String, Map<String, Object?>> _notifications = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<List<Map<String, Object?>>> getEmiSchemes() async {
    return _schemes.values.map(Map<String, Object?>.from).toList();
  }

  @override
  Future<void> upsertEmiScheme(Map<String, Object?> values) async {
    _schemes[values['id']! as String] = Map.from(values);
  }

  @override
  Future<void> deleteEmiScheme(String id) async {
    _schemes.remove(id);
  }

  @override
  Future<List<Map<String, Object?>>> getTriggerRules(String userId) async {
    return _rules.values
        .where((row) => row['user_id'] == userId)
        .map(Map<String, Object?>.from)
        .toList();
  }

  @override
  Future<void> upsertTriggerRule(Map<String, Object?> values) async {
    _rules['${values['user_id']}:${values['id']}'] = Map.from(values);
  }

  @override
  Future<void> deleteTriggerRule(String id, String userId) async {
    _rules.remove('$userId:$id');
  }

  @override
  Future<List<Map<String, Object?>>> getNotifications() async {
    return _notifications.values.map(Map<String, Object?>.from).toList();
  }

  @override
  Future<void> upsertNotification(Map<String, Object?> values) async {
    _notifications[values['id']! as String] = Map.from(values);
  }

  @override
  Future<void> markNotificationRead(String id, bool isRead) async {
    _notifications[id]?['isRead'] = isRead ? 1 : 0;
  }

  @override
  Future<void> deleteNotification(String id) async {
    _notifications.remove(id);
  }

  @override
  Future<void> clearNotifications() async {
    _notifications.clear();
  }
}
