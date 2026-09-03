import 'package:flutter/foundation.dart';

import '../../services/database/database_service.dart';
import '../../services/notification/local_notification_service.dart';

class TriggerRule {
  final String id;
  double targetOPR;
  String equipmentType;
  bool isEnabled;
  String comparison;
  DateTime createdAt;

  TriggerRule({
    required this.id,
    required this.targetOPR,
    required this.equipmentType,
    this.isEnabled = true,
    this.comparison = 'atOrBelow',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  TriggerRule copyWith({
    String? id,
    double? targetOPR,
    String? equipmentType,
    bool? isEnabled,
    String? comparison,
    DateTime? createdAt,
  }) {
    return TriggerRule(
      id: id ?? this.id,
      targetOPR: targetOPR ?? this.targetOPR,
      equipmentType: equipmentType ?? this.equipmentType,
      isEnabled: isEnabled ?? this.isEnabled,
      comparison: comparison ?? this.comparison,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory TriggerRule.fromMap(Map<String, Object?> map) {
    return TriggerRule(
      id: map['id']! as String,
      targetOPR: (map['targetRate']! as num).toDouble(),
      equipmentType: map['equipmentType']! as String,
      isEnabled: (map['enabled']! as num).toInt() == 1,
      comparison: map['comparison']! as String,
      createdAt: DateTime.parse(map['createdAt']! as String),
    );
  }

  Map<String, Object?> toMap(String userId) {
    return {
      'id': id,
      'user_id': userId,
      'targetRate': targetOPR,
      'comparison': comparison,
      'enabled': isEnabled ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'equipmentType': equipmentType,
    };
  }
}

class TriggerNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  TriggerNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  TriggerNotification copyWith({bool? isRead}) {
    return TriggerNotification(
      id: id,
      userId: userId,
      title: title,
      message: message,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  factory TriggerNotification.fromMap(Map<String, Object?> map) {
    return TriggerNotification(
      id: map['id']! as String,
      userId: map['user_id']! as String,
      title: map['title']! as String,
      message: map['message']! as String,
      timestamp: DateTime.parse(map['timestamp']! as String),
      isRead: (map['isRead']! as num).toInt() == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead ? 1 : 0,
    };
  }
}

class TriggerManager extends ChangeNotifier {
  TriggerManager({
    LocalDatabase? database,
    this.localNotificationService,
  }) : _database = database ?? DatabaseService.instance,
       super();

  final LocalDatabase _database;
  final OprNotificationService? localNotificationService;
  final List<TriggerRule> _rules = [];
  final List<TriggerNotification> _notifications = [];
  Future<void> _pendingWrite = Future.value();
  Future<void>? _initialization;
  String? _currentUserId;
  String? _persistenceError;

  List<TriggerRule> get rules => List.unmodifiable(_rules);
  List<TriggerNotification> get notifications =>
      List.unmodifiable(_notifications);
  List<String> get notificationInbox => List.unmodifiable(
    _notifications.map((notification) => notification.message),
  );
  int get unreadCount => _notifications.where((item) => !item.isRead).length;
  String? get persistenceError => _persistenceError;

  Future<void> initialize({String? userId}) {
    return _initialization ??= _loadPersistedData(userId);
  }

  Future<void> _loadPersistedData(String? userId) async {
    _currentUserId = userId;
    await _loadDataForUser(userId);
  }

  Future<void> setUser(String? userId) async {
    await initialize();
    await _pendingWrite;
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    await _loadDataForUser(userId);
  }

  Future<void> refresh() async {
    await initialize();
    await _pendingWrite;
    await _loadPersistedData(_currentUserId);
  }

  Future<void> _loadDataForUser(String? userId) async {
    final ruleRows = userId == null
        ? <Map<String, Object?>>[]
        : await _database.getTriggerRules(userId);
    final notificationRows = userId == null
        ? <Map<String, Object?>>[]
        : await _database.getNotifications(userId);
    if (_currentUserId != userId) return;
    _rules
      ..clear()
      ..addAll(ruleRows.map(TriggerRule.fromMap));
    _notifications
      ..clear()
      ..addAll(notificationRows.map(TriggerNotification.fromMap));
    notifyListeners();
  }

  void addRule(TriggerRule rule) {
    final userId = _currentUserId;
    if (userId == null) return;
    _rules.add(rule);
    notifyListeners();
    final values = rule.toMap(userId);
    _queueWrite(() => _database.upsertTriggerRule(values));
  }

  void editRule(TriggerRule updated) {
    final userId = _currentUserId;
    if (userId == null) return;
    final index = _rules.indexWhere((rule) => rule.id == updated.id);
    if (index != -1) {
      _rules[index] = updated;
      notifyListeners();
      final values = updated.toMap(userId);
      _queueWrite(() => _database.upsertTriggerRule(values));
    }
  }

  void toggleRule(String id) {
    final userId = _currentUserId;
    if (userId == null) return;
    final index = _rules.indexWhere((rule) => rule.id == id);
    if (index != -1) {
      _rules[index].isEnabled = !_rules[index].isEnabled;
      notifyListeners();
      final values = _rules[index].toMap(userId);
      _queueWrite(() => _database.upsertTriggerRule(values));
    }
  }

  void removeRule(String id) {
    final userId = _currentUserId;
    if (userId == null) return;
    _rules.removeWhere((rule) => rule.id == id);
    notifyListeners();
    _queueWrite(() => _database.deleteTriggerRule(id, userId));
  }

  List<String> checkTriggers(double currentOPR, int year) {
    final triggered = <String>[];
    final userId = _currentUserId;
    if (userId == null) return triggered;

    for (final rule in _rules) {
      if (!rule.isEnabled) {
        continue;
      }

      final isAtOrAbove = rule.comparison == 'atOrAbove';
      final matches = isAtOrAbove
          ? currentOPR >= rule.targetOPR
          : currentOPR <= rule.targetOPR;
      if (!matches) {
        continue;
      }

      final direction = isAtOrAbove ? 'at/above' : 'at/below';
      final message =
          '🔔 [$year] OPR ${currentOPR.toStringAsFixed(2)}% is $direction '
          'your target ${rule.targetOPR.toStringAsFixed(2)}% — '
          'Best time to purchase ${rule.equipmentType}!';
      triggered.add(message);

      if (_notifications.any((item) => item.message == message)) {
        continue;
      }

      final notification = TriggerNotification(
        id: '${rule.id}-${DateTime.now().microsecondsSinceEpoch}',
        userId: userId,
        title: 'OPR Trigger Alert',
        message: message,
        timestamp: DateTime.now(),
      );
      _notifications.insert(0, notification);
      final localBody =
          'OPR reached ${currentOPR.toStringAsFixed(2)}%. '
          'Best time to purchase ${rule.equipmentType}.';
      _queueWrite(() async {
        await _database.upsertNotification(notification.toMap());
        await localNotificationService?.showOprAlert(
          notificationId: notification.id,
          body: localBody,
        );
      });
    }

    if (triggered.isNotEmpty) {
      notifyListeners();
    }
    return triggered;
  }

  void markNotificationRead(String id, {bool isRead = true}) {
    final userId = _currentUserId;
    if (userId == null) return;
    final index = _notifications.indexWhere((item) => item.id == id);
    if (index == -1 || _notifications[index].isRead == isRead) {
      return;
    }
    _notifications[index] = _notifications[index].copyWith(isRead: isRead);
    notifyListeners();
    _queueWrite(() => _database.markNotificationRead(id, isRead, userId));
  }

  void deleteNotification(String id) {
    final userId = _currentUserId;
    if (userId == null) return;
    _notifications.removeWhere((item) => item.id == id);
    notifyListeners();
    _queueWrite(() => _database.deleteNotification(id, userId));
  }

  void clearInbox() {
    final userId = _currentUserId;
    if (userId == null) return;
    _notifications.clear();
    notifyListeners();
    _queueWrite(() => _database.clearNotifications(userId));
  }

  Future<void> waitForPendingWrites() {
    return _pendingWrite;
  }

  void _queueWrite(Future<void> Function() operation) {
    _pendingWrite = _pendingWrite.then((_) => operation()).catchError((error) {
      _persistenceError = error.toString();
      notifyListeners();
    });
  }
}
