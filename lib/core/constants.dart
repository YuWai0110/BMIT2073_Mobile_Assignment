import 'package:flutter/material.dart';

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

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryRed,
        primary: AppColors.primaryRed,
        secondary: AppColors.accentBlue,
        surface: Colors.white,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.backgroundGrey,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentBlue,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.primaryRed,
        unselectedItemColor: AppColors.mediumGrey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightGrey, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accentBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.mediumGrey),
        floatingLabelStyle: const TextStyle(color: AppColors.accentBlue),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentBlue,
          side: const BorderSide(color: AppColors.accentBlue),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightGrey,
        thickness: 1,
      ),
    );
  }
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
