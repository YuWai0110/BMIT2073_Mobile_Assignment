import 'package:flutter/widgets.dart';

String? validateLoanCompany(String? value) {
  final company = value?.trim() ?? '';
  if (company.isEmpty) return 'Company name is required.';
  if (company.characters.length > 50) {
    return 'Company name cannot exceed 50 characters.';
  }
  return null;
}

int? parseLoanAmountCents(String value) {
  final text = value.trim();
  if (!RegExp(r'^[0-9]+\.[0-9]{2}$').hasMatch(text)) return null;
  return int.tryParse(text.replaceAll('.', ''));
}

String? validateLoanAmount(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Loan amount is required.';
  final cents = parseLoanAmountCents(text);
  if (cents == null) return 'Enter amount in RM format (e.g. 5000.00).';
  if (cents < 500000) return 'Minimum loan amount is RM 5,000.00.';
  if (cents > 60000000) return 'Maximum loan amount is RM 600,000.00.';
  return null;
}
