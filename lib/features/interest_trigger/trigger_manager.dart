import 'package:flutter/foundation.dart';

class TriggerRule {
  final String id;
  double targetOPR;
  String equipmentType;
  bool isEnabled;

  TriggerRule({
    required this.id,
    required this.targetOPR,
    required this.equipmentType,
    this.isEnabled = true,
  });

  TriggerRule copyWith({
    String? id,
    double? targetOPR,
    String? equipmentType,
    bool? isEnabled,
  }) {
    return TriggerRule(
      id: id ?? this.id,
      targetOPR: targetOPR ?? this.targetOPR,
      equipmentType: equipmentType ?? this.equipmentType,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

class TriggerManager extends ChangeNotifier {
  final List<TriggerRule> _rules = [];
  final List<String> _notificationInbox = [];

  List<TriggerRule> get rules => List.unmodifiable(_rules);
  List<String> get notificationInbox => List.unmodifiable(_notificationInbox);
  int get unreadCount => _notificationInbox.length;

  void addRule(TriggerRule rule) {
    _rules.add(rule);
    notifyListeners();
  }

  void editRule(TriggerRule updated) {
    final index = _rules.indexWhere((r) => r.id == updated.id);
    if (index != -1) {
      _rules[index] = updated;
      notifyListeners();
    }
  }

  void toggleRule(String id) {
    final index = _rules.indexWhere((r) => r.id == id);
    if (index != -1) {
      _rules[index].isEnabled = !_rules[index].isEnabled;
      notifyListeners();
    }
  }

  void removeRule(String id) {
    _rules.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  List<String> checkTriggers(double currentOPR, int year) {
    final List<String> triggered = [];

    for (final rule in _rules) {
      if (!rule.isEnabled) continue;
      if (currentOPR <= rule.targetOPR) {
        final msg =
            '🔔 [$year] OPR ${currentOPR.toStringAsFixed(2)}% is at/below '
            'your target ${rule.targetOPR.toStringAsFixed(2)}% — '
            'Best time to purchase ${rule.equipmentType}!';
        triggered.add(msg);
        if (!_notificationInbox.contains(msg)) {
          _notificationInbox.insert(0, msg);
        }
      }
    }

    if (triggered.isNotEmpty) {
      notifyListeners();
    }
    return triggered;
  }

  void clearInbox() {
    _notificationInbox.clear();
    notifyListeners();
  }
}
