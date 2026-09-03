import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract interface class OprNotificationService {
  Future<void> showOprAlert({
    required String notificationId,
    required String body,
  });
}

class LocalNotificationService implements OprNotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'opr_alert';
  static const channelName = 'OPR Alerts';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin.initialize(settings: settings);

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: 'Alerts when an OPR trigger rule is satisfied',
          importance: Importance.high,
        ),
      );
      await android?.requestNotificationsPermission();
      _isInitialized = true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Local notification initialization failed: $error');
      }
    }
  }

  @override
  Future<void> showOprAlert({
    required String notificationId,
    required String body,
  }) async {
    if (!_isInitialized || kIsWeb || !Platform.isAndroid) return;

    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Alerts when an OPR trigger rule is satisfied',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      await _plugin.show(
        id: notificationId.hashCode & 0x7fffffff,
        title: 'BNM SME Platform',
        body: body,
        notificationDetails: details,
        payload: notificationId,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Local notification display failed: $error');
      }
    }
  }
}
