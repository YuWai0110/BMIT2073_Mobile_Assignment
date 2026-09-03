import 'package:shared_preferences/shared_preferences.dart';

class NotificationDeliveryGuard {
  Future<void> _pending = Future.value();

  Future<void> deliverOnce(String eventId, Future<void> Function() deliver) {
    final result = _pending.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      final key = 'opr_notification_delivered:$eventId';
      if (preferences.getBool(key) == true) return;
      if (!await preferences.setBool(key, true)) {
        throw StateError('Unable to record notification delivery');
      }
      try {
        await deliver();
      } catch (_) {
        await preferences.remove(key);
        rethrow;
      }
    });
    _pending = result.catchError((Object _) {});
    return result;
  }
}
