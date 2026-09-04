import 'package:flutter/material.dart';

class AppSnackBar {
  AppSnackBar._();

  static void success(BuildContext context, String message) {
    _show(context, message, Colors.green.shade700, Icons.check_circle);
  }

  static void error(BuildContext context, String message) {
    _show(context, message, Colors.red.shade700, Icons.error);
  }

  static void _show(
    BuildContext context,
    String message,
    Color background,
    IconData icon,
  ) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
