import 'dart:convert';

class AiAdvisorInput {
  final String equipmentName;
  final double equipmentPrice;
  final int quantity;
  final double loanAmount;
  final double interestRate;
  final double repaymentYears;
  final double monthlyEmi;
  final double currentOpr;

  const AiAdvisorInput({
    required this.equipmentName,
    required this.equipmentPrice,
    required this.quantity,
    required this.loanAmount,
    required this.interestRate,
    required this.repaymentYears,
    required this.monthlyEmi,
    required this.currentOpr,
  });

  Map<String, Object> toJson() {
    return {
      'equipment_name': equipmentName,
      'equipment_price': equipmentPrice,
      'quantity': quantity,
      'loan_amount': loanAmount,
      'interest_rate': interestRate,
      'repayment_years': repaymentYears,
      'monthly_emi': monthlyEmi,
      'current_opr': currentOpr,
    };
  }
}

class AiRecommendation {
  final String riskLevel;
  final String summary;
  final String recommendation;
  final String cashflowAdvice;
  final double confidence;

  const AiRecommendation({
    required this.riskLevel,
    required this.summary,
    required this.recommendation,
    required this.cashflowAdvice,
    required this.confidence,
  });

  factory AiRecommendation.fromJsonString(String source) {
    final normalized = _extractJson(source);
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map<String, dynamic>) {
        throw const AiResponseFormatException();
      }
      return AiRecommendation.fromJson(decoded);
    } on FormatException {
      throw const AiResponseFormatException();
    }
  }

  factory AiRecommendation.fromJson(Map<String, dynamic> json) {
    final confidence = _readConfidence(json['confidence']);
    final riskLevel = _readText(json['risk_level']);
    final summary = _readText(json['summary']);
    final recommendation = _readText(json['recommendation']);
    final cashflowAdvice = _readText(json['cashflow_advice']);

    if (confidence == null ||
        riskLevel == null ||
        summary == null ||
        recommendation == null ||
        cashflowAdvice == null) {
      throw const AiResponseFormatException();
    }

    return AiRecommendation(
      riskLevel: riskLevel,
      summary: summary,
      recommendation: recommendation,
      cashflowAdvice: cashflowAdvice,
      confidence: confidence,
    );
  }
}

class AiResponseFormatException implements Exception {
  const AiResponseFormatException();
}

String _extractJson(String source) {
  final trimmed = source.trim();
  final start = trimmed.indexOf('{');
  final end = trimmed.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const AiResponseFormatException();
  }
  return trimmed.substring(start, end + 1);
}

String? _readText(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

double? _readConfidence(Object? value) {
  final raw = switch (value) {
    num number => number.toDouble(),
    String text => double.tryParse(text.replaceAll('%', '').trim()),
    _ => null,
  };
  if (raw == null) return null;
  final normalized = raw <= 1 ? raw * 100 : raw;
  if (normalized < 0 || normalized > 100) return null;
  return normalized;
}
