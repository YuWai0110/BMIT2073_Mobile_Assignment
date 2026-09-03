import 'dart:math';
import 'package:flutter/foundation.dart';

import '../../services/database/database_service.dart';

class CalcScheme {
  final String id;
  String title;
  double equipmentPrice;
  int unitCount;
  int loanTermMonths;
  double interestRate;
  double monthlyPayment;
  double totalPayment;

  CalcScheme({
    required this.id,
    required this.title,
    required this.equipmentPrice,
    required this.unitCount,
    required this.loanTermMonths,
    required this.interestRate,
    required this.monthlyPayment,
    required this.totalPayment,
  });

  CalcScheme copyWith({
    String? id,
    String? title,
    double? equipmentPrice,
    int? unitCount,
    int? loanTermMonths,
    double? interestRate,
    double? monthlyPayment,
    double? totalPayment,
  }) {
    return CalcScheme(
      id: id ?? this.id,
      title: title ?? this.title,
      equipmentPrice: equipmentPrice ?? this.equipmentPrice,
      unitCount: unitCount ?? this.unitCount,
      loanTermMonths: loanTermMonths ?? this.loanTermMonths,
      interestRate: interestRate ?? this.interestRate,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      totalPayment: totalPayment ?? this.totalPayment,
    );
  }

  factory CalcScheme.fromMap(Map<String, Object?> map) {
    return CalcScheme(
      id: map['id']! as String,
      title: map['title']! as String,
      equipmentPrice: (map['equipmentPrice']! as num).toDouble(),
      unitCount: (map['quantity']! as num).toInt(),
      loanTermMonths: ((map['loanYears']! as num).toDouble() * 12).round(),
      interestRate: (map['interestRate']! as num).toDouble(),
      monthlyPayment: (map['monthlyPayment']! as num).toDouble(),
      totalPayment: (map['totalPayment']! as num).toDouble(),
    );
  }

  Map<String, Object?> toMap(String userId) {
    return {
      'id': id,
      'title': title,
      'equipmentPrice': equipmentPrice,
      'quantity': unitCount,
      'interestRate': interestRate,
      'loanYears': loanTermMonths / 12,
      'monthlyPayment': monthlyPayment,
      'totalPayment': totalPayment,
      'user_id': userId,
    };
  }
}

class CalcManager extends ChangeNotifier {
  CalcManager({LocalDatabase? database})
    : _database = database ?? DatabaseService.instance;

  final LocalDatabase _database;
  final List<CalcScheme> _schemes = [];
  Future<void> _pendingWrite = Future.value();
  Future<void>? _initialization;
  String? _currentUserId;
  String? _persistenceError;

  List<CalcScheme> get schemes => List.unmodifiable(_schemes);
  String? get persistenceError => _persistenceError;

  Future<void> initialize({String? userId}) {
    return _initialization ??= _loadSchemes(userId);
  }

  Future<void> setUser(String? userId) async {
    await initialize();
    await _pendingWrite;
    if (_currentUserId == userId) return;
    await _loadSchemes(userId);
  }

  Future<void> refresh() async {
    await initialize();
    await _loadSchemes(_currentUserId);
  }

  Future<void> _loadSchemes(String? userId) async {
    final rows = userId == null
        ? <Map<String, Object?>>[]
        : await _database.getEmiSchemes(userId);
    _currentUserId = userId;
    _schemes
      ..clear()
      ..addAll(rows.map(CalcScheme.fromMap));
    notifyListeners();
  }

  void saveScheme(CalcScheme scheme) {
    final userId = _currentUserId;
    if (userId == null) {
      _persistenceError = 'No authenticated user is available.';
      notifyListeners();
      return;
    }
    _schemes.add(scheme);
    notifyListeners();
    final values = scheme.toMap(userId);
    _queueWrite(() => _database.upsertEmiScheme(values));
  }

  void updateScheme(CalcScheme updated) {
    final userId = _currentUserId;
    if (userId == null) return;
    final index = _schemes.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      _schemes[index] = updated;
      notifyListeners();
      final values = updated.toMap(userId);
      _queueWrite(() => _database.upsertEmiScheme(values));
    }
  }

  void deleteScheme(String id) {
    final userId = _currentUserId;
    if (userId == null) return;
    _schemes.removeWhere((s) => s.id == id);
    notifyListeners();
    _queueWrite(() => _database.deleteEmiScheme(id, userId));
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

  static Map<String, double> calculateEMI({
    required double principal,
    required double annualRate,
    required int months,
  }) {
    if (principal <= 0 || months <= 0) {
      return {'monthlyPayment': 0, 'totalPayment': 0};
    }

    if (annualRate <= 0) {
      final monthly = principal / months;
      return {'monthlyPayment': monthly, 'totalPayment': principal};
    }

    final double r = annualRate / 12 / 100;
    final int n = months;
    final double factor = pow(1 + r, n).toDouble();
    final double emi = principal * r * factor / (factor - 1);

    return {'monthlyPayment': emi, 'totalPayment': emi * n};
  }
}
