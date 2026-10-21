import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/settings_models.dart';
import 'prayer_times_service.dart';

/// Texts used for the scheduled notifications.
///
/// They are passed in rather than resolved inside the service so the service
/// stays free of `BuildContext`: the app rebuilds its schedule whenever the
/// locale changes, and this keeps the last scheduled batch in the language the
/// user actually saw.
class NotificationTexts {
  const NotificationTexts({
    required this.prayerTitle,
    required this.prayerBody,
    required this.morningTitle,
    required this.morningBody,
    required this.eveningTitle,
    required this.eveningBody,
    required this.channelPrayer,
    required this.channelAdhkar,
  });

  /// Title of a prayer reminder, given the prayer.
  final String Function(PrayerSlot slot) prayerTitle;

  /// Body of a prayer reminder, given the time it is announcing.
  final String Function(DateTime time) prayerBody;

  final String morningTitle;
  final String morningBody;
  final String eveningTitle;
  final String eveningBody;
  final String channelPrayer;
  final String channelAdhkar;
}

/// Schedules the prayer-time and adhkar reminders with the OS.
///
/// **Failure policy.** Everything here is best-effort. Notifications are a
/// convenience on top of a fully working app: if the platform refuses, the
/// plugin is missing, the user denied the permission or the time-zone lookup
/// fails, the app must keep working silently. Every entry point therefore
/// swallows its own errors and reports a boolean instead of throwing.
///
/// **Why explicit dates rather than a repeating alarm.** Prayer times drift by
/// a minute or two every day, so a daily repeat pinned to one clock time would
/// slowly walk away from the real time. A rolling window of concrete instants
/// is rescheduled on every launch (and again by the plugin's boot receiver),
/// which keeps the times exact without needing a background isolate.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  /// How many days ahead are scheduled at once.
  static const int horizonDays = 7;

  static const int _prayerBaseId = 1000;
  static const int _morningId = 200;
  static const int _eveningId = 201;

  /// Room for one id per prayer per day inside a single day block.
  static const int _idsPerDay = 8;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;
  bool _available = false;

  /// Sets up the plugin and the time-zone database. Safe to call repeatedly.
  Future<bool> initialise() async {
    if (_initialised) return _available;
    _initialised = true;
    if (kIsWeb) return _available = false;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_zad'),
        ),
      );
      tz_data.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      _available = true;
    } catch (_) {
      // A missing platform implementation or an unknown zone name only costs
      // us the reminders, never the app.
      _available = false;
    }
    return _available;
  }

  /// Asks for the OS notification permission (Android 13+).
  ///
  /// Returns `true` when notifications may be posted. On older Android
  /// versions, where the permission does not exist, the call reports `true`.
  Future<bool> requestPermission() async {
    if (!await initialise()) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return true;
      final granted = await android.requestNotificationsPermission();
      return granted ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Rebuilds the whole schedule from the current settings.
  ///
  /// Cancels everything Zad owns first, so it is idempotent: calling it on
  /// every launch cannot pile up duplicate alarms.
  Future<void> sync({
    required AppSettings settings,
    required ResolvedLocation location,
    required NotificationTexts texts,
    DateTime? now,
  }) async {
    final wantsPrayer = settings.prayerNotifications;
    final wantsMorning = settings.morningReminder;
    final wantsEvening = settings.eveningReminder;
    if (!wantsPrayer && !wantsMorning && !wantsEvening) {
      await cancelAll();
      return;
    }
    if (!await initialise()) return;

    await cancelAll();

    // Adhkar reminders need no coordinates, so they are scheduled even when
    // the location is unavailable — only the prayer times are skipped.
    if (wantsMorning) {
      await _scheduleDaily(
        id: _morningId,
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
        title: texts.morningTitle,
        body: texts.morningBody,
        channelId: 'zad_adhkar',
        channelName: texts.channelAdhkar,
      );
    }
    if (wantsEvening) {
      await _scheduleDaily(
        id: _eveningId,
        // The evening reminder is the mirror of the morning one: whatever the
        // user picked for the morning, the evening lands twelve hours later,
        // which is the Maghrib-ish end of the day without hard-coding a time.
        hour: (settings.reminderHour + 12) % 24,
        minute: settings.reminderMinute,
        title: texts.eveningTitle,
        body: texts.eveningBody,
        channelId: 'zad_adhkar',
        channelName: texts.channelAdhkar,
      );
    }

    if (!wantsPrayer || !location.isOk) return;

    final service = const PrayerTimesService();
    final start = now ?? DateTime.now();
    for (var day = 0; day < horizonDays; day++) {
      final date = start.add(Duration(days: day));
      final schedule = service.compute(
        latitude: location.latitude!,
        longitude: location.longitude!,
        settings: settings,
        date: date,
      );
      if (schedule == null) continue;
      for (final slot in PrayerSlot.values) {
        if (!slot.isObligatory) continue;
        final time = schedule.timeOf(slot);
        if (time == null || !time.isAfter(start)) continue;
        await _schedule(
          id: _prayerBaseId + day * _idsPerDay + slot.index,
          when: time,
          title: texts.prayerTitle(slot),
          body: texts.prayerBody(time),
          channelId: 'zad_prayer',
          channelName: texts.channelPrayer,
        );
      }
    }
  }

  Future<void> cancelAll() async {
    if (!await initialise()) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {
      // Nothing to undo if the platform channel is unavailable.
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    await _schedule(
      id: id,
      when: next,
      title: title,
      body: body,
      channelId: channelId,
      channelName: channelName,
    );
  }

  Future<void> _schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {
    try {
      final scheduled = tz.TZDateTime.from(when, tz.local);
      if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) return;
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelName,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(body),
          ),
        ),
        // Inexact on purpose: exact alarms need a special Android 14+
        // permission that users routinely refuse, and a prayer reminder that
        // may arrive a few minutes late is far better than one that silently
        // never arrives because the permission was denied.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // A single failed alarm must not abort the rest of the batch.
    }
  }
}
