import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:sixam_mart_delivery/util/app_constants.dart';

/// Temporizador de contacto cliente: hora de término en pared + notificación local
/// (el estado vuelve a calcularse al reabrir; la alarma con app “matada” es lo mejor
/// razonable sin leer el registro de llamadas, que complica la política de las tiendas).
class DmContactTimerHelper {
  DmContactTimerHelper._();

  static bool _tzReady = false;

  static int notificationIdFor(int orderId) {
    // Rango fijo, evita chocar con otras notifs de la app
    return 0x2E000000 ^ (orderId & 0x0FFFFFFF);
  }

  static Future<void> ensureLocalTimezone() async {
    if (_tzReady) {
      return;
    }
    tzdata.initializeTimeZones();
    if (kIsWeb) {
      _tzReady = true;
      return;
    }
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('[DmContactTimer] getLocalTimezone: $e');
      try {
        tz.setLocalLocation(tz.getLocation('America/Mexico_City'));
      } catch (e2) {
        debugPrint('[DmContactTimer] fallback Mexico_City: $e2');
      }
    }
    _tzReady = true;
  }

  static Future<void> scheduleCountdownEndNotification(
    FlutterLocalNotificationsPlugin fln, {
    required int orderId,
    required int deadlineMs,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) {
      return;
    }
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (deadlineMs <= now) {
      return;
    }
    await ensureLocalTimezone();
    final DateTime local = DateTime.fromMillisecondsSinceEpoch(deadlineMs);
    final tz.TZDateTime scheduled = tz.TZDateTime.from(local, tz.local);
    final int notifId = notificationIdFor(orderId);
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      '6ammart',
      AppConstants.appName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const DarwinNotificationDetails darwin = DarwinNotificationDetails();
    const NotificationDetails details = NotificationDetails(
      android: android,
      iOS: darwin,
    );
    try {
      await fln.cancel(notifId);
      await fln.zonedSchedule(
        notifId,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: null,
      );
    } catch (e) {
      debugPrint('[DmContactTimer] zonedSchedule: $e');
    }
  }

  static Future<void> cancelEndNotification(
    FlutterLocalNotificationsPlugin fln, {
    required int orderId,
  }) async {
    if (kIsWeb) {
      return;
    }
    try {
      await fln.cancel(notificationIdFor(orderId));
    } catch (e) {
      debugPrint('[DmContactTimer] cancel: $e');
    }
  }
}
