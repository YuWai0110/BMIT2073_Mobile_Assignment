String? validateFullName(String? value) {
  if (value == null || value.trim().length < 3) {
    return 'Please enter your full name.';
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
    return 'Password must be at least 8 characters and include uppercase, lowercase and a number.';
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
  if (phone.isNotEmpty && !RegExp(r'^\d{10,11}$').hasMatch(phone)) {
    return 'Please enter a valid Malaysian phone number.';
  }
  return null;
}
