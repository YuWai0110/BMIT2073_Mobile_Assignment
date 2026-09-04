import 'package:flutter/widgets.dart';

String? validateFullName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) {
    return 'Please enter your full name.';
  }
  if (name.characters.length < 2 || name.characters.length > 30) {
    return 'Full name must be between 2 and 30 characters.';
  }
  return null;
}

String? validateRegistrationCompany(String? value) {
  if ((value?.trim().characters.length ?? 0) > 50) {
    return 'Company name cannot exceed 50 characters.';
  }
  return null;
}

String? validateEmailAddress(String? value) {
  final email = value?.trim() ?? '';
  final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  if (!emailPattern.hasMatch(email)) {
    return 'Please enter a valid email address.';
  }
  return null;
}

String? validateRegistrationPassword(String? value) {
  final password = value ?? '';
  final isValid =
      password.length >= 8 &&
      RegExp(r'[A-Z]').hasMatch(password) &&
      RegExp(r'[a-z]').hasMatch(password) &&
      RegExp(r'\d').hasMatch(password);
  if (!isValid) {
    return 'Password must contain at least 8 characters, one uppercase letter, one lowercase letter, and one number.';
  }
  return null;
}

String? validatePasswordConfirmation(String? value, String password) {
  if (value != password) {
    return 'Passwords do not match.';
  }
  return null;
}

String? validateMalaysianPhone(String? value) {
  final phone = value?.trim() ?? '';
  if (phone.isEmpty) return null;
  final compact = phone.replaceAll(RegExp(r'[-\s]'), '');
  final local = compact.startsWith('+60')
      ? '0${compact.substring(3)}'
      : compact;
  if (!RegExp(r'^0[1-9][0-9]{8,9}$').hasMatch(local)) {
    return 'Please enter a valid Malaysian phone number.';
  }
  return null;
}
