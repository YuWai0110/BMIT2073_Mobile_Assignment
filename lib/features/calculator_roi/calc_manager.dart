import 'dart:math';
import 'package:flutter/foundation.dart';

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
}

class CalcManager extends ChangeNotifier {
  final List<CalcScheme> _schemes = [];

  List<CalcScheme> get schemes => List.unmodifiable(_schemes);

  void saveScheme(CalcScheme scheme) {
    _schemes.add(scheme);
    notifyListeners();
  }

  void updateScheme(CalcScheme updated) {
    final index = _schemes.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      _schemes[index] = updated;
      notifyListeners();
    }
  }

  void deleteScheme(String id) {
    _schemes.removeWhere((s) => s.id == id);
    notifyListeners();
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

    return {
      'monthlyPayment': emi,
      'totalPayment': emi * n,
    };
  }
}
