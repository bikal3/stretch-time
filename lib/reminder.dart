import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'app_state.dart';
import 'workout.dart';

/// Daily "time to stretch" notification, phones only.
final remindersSupported =
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

final _plugin = FlutterLocalNotificationsPlugin();
Future<void>? _ready;
Future<void> _queue = Future.value();

Future<void> _init() => _ready ??= _plugin.initialize(
  settings: const InitializationSettings(
    android: AndroidInitializationSettings('ic_stat_reminder'),
    // Asked for when the reminder is switched on, not at launch.
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  ),
);

/// Shows the system permission prompt if needed. False if denied.
Future<bool> requestReminderPermission() async {
  try {
    await _init();
    final granted = defaultTargetPlatform == TargetPlatform.android
        ? await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission()
        : await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true);
    return granted ?? false;
  } catch (e) {
    debugPrint('reminder permission: $e');
    return false;
  }
}

/// Replaces all pending reminders to match [s] and today's [log].
/// Queued, so a quick off/on can't interleave.
Future<void> syncReminder(Settings s, Map<String, int> log) =>
    _queue = _queue.then((_) => _sync(s, log));

// ponytail: 30 one-shots, re-armed on every app start, so reminders stop
// after 30 days without opening the app. A repeating notification can't skip
// today on iOS; move to background refresh if that ceiling ever matters.
Future<void> _sync(Settings s, Map<String, int> log) async {
  if (!remindersSupported) return;
  try {
    await _init();
    await _plugin.cancelAll();
    if (!s.reminder) return;
    final now = DateTime.now();
    final first = nextReminder(
      now,
      s.reminderMins,
      log.containsKey(dayKey(now)),
    );
    for (var i = 0; i < 30; i++) {
      final at = DateTime(
        first.year,
        first.month,
        first.day + i,
        first.hour,
        first.minute,
      );
      await _plugin.zonedSchedule(
        id: i,
        title: 'Time to stretch',
        body: 'Keep your streak going',
        // An absolute instant, so the device's time zone name isn't needed.
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('reminder', 'Daily reminder'),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  } catch (e) {
    // A reminder that can't be scheduled must never break a workout.
    debugPrint('reminder: $e');
  }
}
