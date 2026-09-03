import 'package:flutter/material.dart';

export 'theme/app_theme.dart';

class AppColors {
  AppColors._();

  static const Color primaryRed = Color(0xFFB71C1C);
  static const Color primaryRedLight = Color(0xFFEF5350);
  static const Color primaryRedDark = Color(0xFF7F0000);

  static const Color accentBlue = Color(0xFF1565C0);
  static const Color accentBlueLight = Color(0xFF5E92F3);
  static const Color accentBlueDark = Color(0xFF003C8F);

  static const Color darkGrey = Color(0xFF37474F);
  static const Color mediumGrey = Color(0xFF607D8B);
  static const Color lightGrey = Color(0xFFECEFF1);
  static const Color backgroundGrey = Color(0xFFF5F5F5);

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color error = Color(0xFFC62828);

  static const Color bankerTeal = Color(0xFF00695C);
}

InputDecoration appInputDecoration({
  required String label,
  String? hint,
  IconData? prefixIcon,
  Widget? suffix,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
    suffix: suffix,
  );
}
