import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _baseNotificationId = 4000;
  static const int _scheduledDays = 90;
  static const String _channelId = 'daily_verse_channel';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    await _configureLocalTimeZone();
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    final androidGranted = await androidImpl?.requestNotificationsPermission();
    final iosGranted =
        await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);

    return (androidGranted ?? true) && (iosGranted ?? true);
  }

  Future<void> scheduleDailyRandomMiddayVerses({
    required List<Map<String, dynamic>> verses,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    if (verses.isEmpty) {
      return;
    }

    await cancelDailyVerseNotifications();

    final random = Random();
    final now = tz.TZDateTime.now(tz.local);

    for (var i = 0; i < _scheduledDays; i++) {
      final verse = verses[random.nextInt(verses.length)];
      final scheduled = _nextMidday(now, i);

      final ref =
          '${verse['book_name']} ${verse['chapter']}:${verse['verse']}';
      final text = (verse['text'] as String? ?? '').replaceAll('\n', ' ').trim();
      final body = text.length > 220 ? '${text.substring(0, 217)}...' : text;

      await _plugin.zonedSchedule(
        _baseNotificationId + i,
        'Daily Verse - $ref',
        body,
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Daily Verse Notifications',
            channelDescription: 'Daily random Bible verse at midday.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelDailyVerseNotifications() async {
    for (var i = 0; i < _scheduledDays; i++) {
      await _plugin.cancel(_baseNotificationId + i);
    }
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      final location = tz.getLocation(timezone);
      tz.setLocalLocation(location);
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  tz.TZDateTime _nextMidday(tz.TZDateTime now, int dayOffset) {
    final base = tz.TZDateTime(tz.local, now.year, now.month, now.day, 12);
    final next = base.isAfter(now) ? base : base.add(const Duration(days: 1));
    return next.add(Duration(days: dayOffset));
  }
}
