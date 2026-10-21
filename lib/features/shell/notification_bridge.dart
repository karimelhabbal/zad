import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/notification_service.dart';
import '../../l10n/app_localizations.dart';
import '../../state/prayer_controller.dart';
import '../../state/settings_controller.dart';

/// Keeps the OS notification schedule in step with the app's settings.
///
/// It sits just under `MaterialApp`, so it has both the localisation and the
/// controllers. `PrayerController` notifies once per second (the countdown),
/// so the sync is driven by a *signature* of everything that actually affects
/// the schedule rather than by the notification itself: the schedule is only
/// rebuilt when one of those inputs really changed, and at most once per
/// second.
class NotificationBridge extends StatefulWidget {
  const NotificationBridge({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationBridge> createState() => _NotificationBridgeState();
}

class _NotificationBridgeState extends State<NotificationBridge> {
  SettingsController? _settings;
  PrayerController? _prayer;
  Timer? _debounce;
  String? _lastSignature;
  bool _disposed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.read<SettingsController>();
    final prayer = context.read<PrayerController>();
    if (identical(settings, _settings) && identical(prayer, _prayer)) return;
    _settings?.removeListener(_onChanged);
    _prayer?.removeListener(_onChanged);
    _settings = settings..addListener(_onChanged);
    _prayer = prayer..addListener(_onChanged);
    _schedule();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _settings?.removeListener(_onChanged);
    _prayer?.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (_disposed) return;
    _debounce?.cancel();
    // Coalesce bursts: a settings change notifies several times in a row, and
    // the location resolution arrives a moment later.
    _debounce = Timer(const Duration(milliseconds: 600), _schedule);
  }

  Future<void> _schedule() async {
    if (_disposed || !mounted) return;
    final settings = context.read<SettingsController>().settings;
    final prayer = context.read<PrayerController>();
    final location = prayer.location;

    final signature = <Object?>[
      settings.prayerNotifications,
      settings.morningReminder,
      settings.eveningReminder,
      settings.reminderHour,
      settings.reminderMinute,
      settings.calculationMethod,
      settings.asrMadhab,
      settings.highLatitude,
      settings.localeCode,
      location.latitude,
      location.longitude,
      location.cityName,
    ].join('|');

    // Nothing that affects the schedule changed.
    if (signature == _lastSignature) return;
    _lastSignature = signature;

    if (!settings.prayerNotifications &&
        !settings.morningReminder &&
        !settings.eveningReminder) {
      await NotificationService.instance.cancelAll();
      return;
    }

    final l10n = AppLocalizations.of(context);
    final city = location.cityName;
    await NotificationService.instance.sync(
      settings: settings,
      location: location,
      texts: NotificationTexts(
        prayerTitle: (slot) => l10n.t(
          'notif.prayerTitle',
          args: <String, Object?>{'prayer': l10n.t(slot.labelKey)},
        ),
        prayerBody: (time) => l10n.t(
          'notif.prayerBody',
          args: <String, Object?>{
            'time': l10n.clock(time),
            'city': city == null || city.isEmpty
                ? l10n.t('notif.deviceTime')
                : city,
          },
        ),
        morningTitle: l10n.t('notif.morningTitle'),
        morningBody: l10n.t('notif.morningBody'),
        eveningTitle: l10n.t('notif.eveningTitle'),
        eveningBody: l10n.t('notif.eveningBody'),
        channelPrayer: l10n.t('notif.channelPrayer'),
        channelAdhkar: l10n.t('notif.channelAdhkar'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
