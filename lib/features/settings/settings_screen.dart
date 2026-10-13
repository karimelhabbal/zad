import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/quran_models.dart';
import '../../data/models/settings_models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/azkar_controller.dart';
import '../../state/prayer_controller.dart';
import '../../state/quran_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/tasbeeh_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_app_bar.dart';
import '../prayer/prayer_times_screen.dart';

/// Application settings: appearance, language, Quran reading preferences,
/// prayer-time calculation, reminders, location and data management.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<SettingsController>();
    final prayer = context.watch<PrayerController>();
    final values = settings.settings;

    return Scaffold(
      appBar: ZadAppBar(
        title: l10n.t('settings.title'),
        subtitle: l10n.t('app.versionNote'),
        showLogo: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_forward_rounded),
          tooltip: l10n.t('common.close'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ZadSpacing.md,
          ZadSpacing.md,
          ZadSpacing.md,
          ZadSpacing.xl,
        ),
        children: <Widget>[
          // ----------------------------------------------------- appearance --
          SectionHeader(
            title: l10n.t('settings.appearance'),
            icon: Icons.palette_outlined,
          ),
          const SizedBox(height: ZadSpacing.sm),
          ZadCard(
            padding: const EdgeInsets.all(ZadSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _FieldLabel(
                  icon: Icons.brightness_6_outlined,
                  label: l10n.t('settings.theme'),
                ),
                const SizedBox(height: ZadSpacing.sm),
                Wrap(
                  spacing: ZadSpacing.sm,
                  runSpacing: ZadSpacing.sm,
                  children: <Widget>[
                    ZadFilterChip(
                      label: l10n.t('settings.themeLight'),
                      selected: values.themeMode == AppThemeMode.light,
                      onTap: () => settings.setThemeMode(AppThemeMode.light),
                    ),
                    ZadFilterChip(
                      label: l10n.t('settings.themeDark'),
                      selected: values.themeMode == AppThemeMode.dark,
                      onTap: () => settings.setThemeMode(AppThemeMode.dark),
                    ),
                    ZadFilterChip(
                      label: l10n.t('settings.themeSystem'),
                      selected: values.themeMode == AppThemeMode.system,
                      onTap: () => settings.setThemeMode(AppThemeMode.system),
                    ),
                  ],
                ),
                const SizedBox(height: ZadSpacing.md),
                _FieldLabel(
                  icon: Icons.translate_rounded,
                  label: l10n.t('settings.language'),
                ),
                const SizedBox(height: ZadSpacing.sm),
                Wrap(
                  spacing: ZadSpacing.sm,
                  runSpacing: ZadSpacing.sm,
                  children: <Widget>[
                    ZadFilterChip(
                      label: l10n.t('settings.arabic'),
                      selected: values.localeCode == 'ar',
                      onTap: () => settings.setLocale('ar'),
                    ),
                    ZadFilterChip(
                      label: l10n.t('settings.english'),
                      selected: values.localeCode == 'en',
                      onTap: () => settings.setLocale('en'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: ZadSpacing.lg),

          // ---------------------------------------------------------- Quran --
          SectionHeader(
            title: l10n.t('settings.quranSection'),
            icon: Icons.menu_book_outlined,
          ),
          const SizedBox(height: ZadSpacing.sm),
          ZadCard(
            padding: const EdgeInsets.all(ZadSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _FieldLabel(
                  icon: Icons.format_size_rounded,
                  label: l10n.t('settings.quranFontSize'),
                ),
                Row(
                  children: <Widget>[
                    Text(
                      l10n.n(values.quranFontScale),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Expanded(
                      child: Slider(
                        value: values.quranFontScale.clamp(0.8, 1.8),
                        min: 0.8,
                        max: 1.8,
                        divisions: 10,
                        label: values.quranFontScale.toStringAsFixed(1),
                        onChanged: settings.setQuranFontScale,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZadSpacing.sm),
                _FieldLabel(
                  icon: Icons.auto_stories_outlined,
                  label: l10n.t('settings.defaultDisplayMode'),
                ),
                const SizedBox(height: ZadSpacing.sm),
                Wrap(
                  spacing: ZadSpacing.sm,
                  runSpacing: ZadSpacing.sm,
                  children: <Widget>[
                    ZadFilterChip(
                      label: l10n.t('quran.textMode'),
                      selected:
                          values.quranDisplayMode == QuranDisplayMode.text,
                      onTap: () => settings.setQuranDisplayMode(
                        QuranDisplayMode.text,
                      ),
                    ),
                    ZadFilterChip(
                      label: l10n.t('quran.mushafMode'),
                      selected:
                          values.quranDisplayMode == QuranDisplayMode.mushaf,
                      onTap: () => settings.setQuranDisplayMode(
                        QuranDisplayMode.mushaf,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: ZadSpacing.lg),

          // -------------------------------------------------------- prayer --
          SectionHeader(
            title: l10n.t('settings.prayerSection'),
            icon: Icons.schedule_outlined,
          ),
          const SizedBox(height: ZadSpacing.sm),
          ZadCard(
            padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
            child: Column(
              children: <Widget>[
                SettingsTile(
                  icon: Icons.calculate_outlined,
                  title: l10n.t('settings.calculationMethod'),
                  subtitle: l10n.t(values.calculationMethod.labelKey),
                  trailing: const Icon(Icons.chevron_left_rounded, size: 18),
                  onTap: () => _pickCalculationMethod(context, settings),
                ),
                const Divider(height: 1, indent: ZadSpacing.md),
                SettingsTile(
                  icon: Icons.balance_rounded,
                  title: l10n.t('settings.asrMadhab'),
                  subtitle: l10n.t(
                    values.asrMadhab == AsrMadhab.hanafi
                        ? 'prayer.madhabHanafi'
                        : 'prayer.madhabStandard',
                  ),
                  trailing: const Icon(Icons.chevron_left_rounded, size: 18),
                  onTap: () => _pickMadhab(context, settings),
                ),
                const Divider(height: 1, indent: ZadSpacing.md),
                SettingsTile(
                  icon: Icons.height_rounded,
                  title: l10n.t('settings.highLatitude'),
                  subtitle: l10n.t(values.highLatitude.labelKey),
                  trailing: const Icon(Icons.chevron_left_rounded, size: 18),
                  onTap: () => _pickHighLatitude(context, settings),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZadSpacing.lg),

          // --------------------------------------------------- notifications --
          SectionHeader(
            title: l10n.t('settings.notifications'),
            icon: Icons.notifications_none_rounded,
          ),
          const SizedBox(height: ZadSpacing.sm),
          ZadCard(
            padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  value: values.prayerNotifications,
                  onChanged: settings.setPrayerNotifications,
                  title: Text(l10n.t('settings.prayerNotifications')),
                  subtitle: Text(l10n.t('settings.prayerNotificationsBody')),
                  secondary: const Icon(Icons.mosque_outlined, size: 20),
                ),
                const Divider(height: 1, indent: ZadSpacing.md),
                SwitchListTile(
                  value: values.morningReminder,
                  onChanged: settings.setMorningReminder,
                  title: Text(l10n.t('settings.morningReminder')),
                  secondary: const Icon(Icons.wb_twilight_rounded, size: 20),
                ),
                const Divider(height: 1, indent: ZadSpacing.md),
                SwitchListTile(
                  value: values.eveningReminder,
                  onChanged: settings.setEveningReminder,
                  title: Text(l10n.t('settings.eveningReminder')),
                  secondary: const Icon(Icons.nights_stay_outlined, size: 20),
                ),
                const Divider(height: 1, indent: ZadSpacing.md),
                SettingsTile(
                  icon: Icons.alarm_rounded,
                  title: l10n.t('settings.reminderTime'),
                  trailing: Text(
                    l10n.timeOfDay(
                      TimeOfDay(
                        hour: values.reminderHour,
                        minute: values.reminderMinute,
                      ),
                    ),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  onTap: () => _pickReminderTime(context, settings),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    ZadSpacing.md,
                    ZadSpacing.xs,
                    ZadSpacing.md,
                    ZadSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: context.tokens.gold,
                      ),
                      const SizedBox(width: ZadSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.t('settings.notificationsNote'),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZadSpacing.lg),

          // -------------------------------------------------------- location --
          SectionHeader(
            title: l10n.t('settings.locationSection'),
            icon: Icons.my_location_rounded,
          ),
          const SizedBox(height: ZadSpacing.sm),
          ZadCard(
            padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  value: values.location.useDeviceLocation,
                  onChanged: (value) async {
                    await settings.setUseDeviceLocation(value);
                    if (!context.mounted) return;
                    await prayer.refresh(requestPermission: value);
                  },
                  title: Text(l10n.t('settings.useGps')),
                  subtitle: Text(l10n.t('settings.useGpsBody')),
                  secondary: const Icon(Icons.gps_fixed_rounded, size: 20),
                ),
                const Divider(height: 1, indent: ZadSpacing.md),
                SettingsTile(
                  icon: Icons.edit_location_alt_outlined,
                  title: l10n.t('settings.manualLocation'),
                  subtitle: prayer.locationSummary.isEmpty
                      ? l10n.t('common.notAvailable')
                      : prayer.locationSummary,
                  trailing: const Icon(Icons.chevron_left_rounded, size: 18),
                  onTap: () => showLocationSheet(context),
                ),
                if (prayer.location.isOk) ...<Widget>[
                  const Divider(height: 1, indent: ZadSpacing.md),
                  SettingsTile(
                    icon: Icons.pin_drop_outlined,
                    title: l10n.t('settings.currentCoordinates'),
                    subtitle:
                        '${prayer.location.latitude!.toStringAsFixed(4)}, '
                        '${prayer.location.longitude!.toStringAsFixed(4)}',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: ZadSpacing.lg),

          // ------------------------------------------------------------ tasbeeh --
          SectionHeader(
            title: l10n.t('tasbeeh.title'),
            icon: Icons.blur_circular_rounded,
          ),
          const SizedBox(height: ZadSpacing.sm),
          ZadCard(
            padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  value: values.tasbeehVibration,
                  onChanged: settings.setTasbeehVibration,
                  title: Text(l10n.t('tasbeeh.vibration')),
                  subtitle: Text(l10n.t('tasbeeh.vibrationBody')),
                  secondary: const Icon(Icons.vibration_rounded, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZadSpacing.lg),

          // ------------------------------------------------------------- about --
          SectionHeader(
            title: l10n.t('settings.about'),
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: ZadSpacing.sm),
          ZadCard(
            padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
            child: Column(
              children: <Widget>[
                SettingsTile(
                  icon: Icons.apps_rounded,
                  title: l10n.t('settings.aboutApp'),
                  subtitle: l10n.t('settings.aboutAppBody'),
                ),
                const Divider(height: 1, indent: ZadSpacing.md),
                SettingsTile(
                  icon: Icons.numbers_rounded,
                  title: l10n.t('settings.version'),
                  subtitle: appVersion,
                ),
                const Divider(height: 1, indent: ZadSpacing.md),
                SettingsTile(
                  icon: Icons.verified_outlined,
                  title: l10n.t('settings.sources'),
                  subtitle: l10n.t('settings.sourcesBody'),
                ),
                const Divider(height: 1, indent: ZadSpacing.md),
                SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  title: l10n.t('settings.privacy'),
                  subtitle: l10n.t('settings.privacyBody'),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZadSpacing.lg),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _resetAppData(context, settings),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(l10n.t('settings.resetApp')),
            ),
          ),
          const SizedBox(height: ZadSpacing.sm),
          Text(
            l10n.t('settings.resetAppBody'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Future<void> _pickCalculationMethod(
    BuildContext context,
    SettingsController settings,
  ) async {
    final l10n = AppLocalizations.of(context);
    final picked = await _pickOption<PrayerCalculationMethod>(
      context,
      title: l10n.t('settings.calculationMethod'),
      current: settings.settings.calculationMethod,
      options: PrayerCalculationMethod.values,
      labelOf: (method) => l10n.t(method.labelKey),
    );
    if (picked == null) return;
    await settings.setCalculationMethod(picked);
    if (!context.mounted) return;
    await context.read<PrayerController>().recompute();
  }

  Future<void> _pickMadhab(
    BuildContext context,
    SettingsController settings,
  ) async {
    final l10n = AppLocalizations.of(context);
    final picked = await _pickOption<AsrMadhab>(
      context,
      title: l10n.t('settings.asrMadhab'),
      current: settings.settings.asrMadhab,
      options: AsrMadhab.values,
      labelOf: (madhab) => l10n.t(
        madhab == AsrMadhab.hanafi
            ? 'prayer.madhabHanafi'
            : 'prayer.madhabStandard',
      ),
    );
    if (picked == null) return;
    await settings.setAsrMadhab(picked);
    if (!context.mounted) return;
    await context.read<PrayerController>().recompute();
  }

  Future<void> _pickHighLatitude(
    BuildContext context,
    SettingsController settings,
  ) async {
    final l10n = AppLocalizations.of(context);
    final picked = await _pickOption<HighLatitudeOption>(
      context,
      title: l10n.t('settings.highLatitude'),
      current: settings.settings.highLatitude,
      options: HighLatitudeOption.values,
      labelOf: (option) => l10n.t(option.labelKey),
    );
    if (picked == null) return;
    await settings.setHighLatitude(picked);
    if (!context.mounted) return;
    await context.read<PrayerController>().recompute();
  }

  Future<void> _pickReminderTime(
    BuildContext context,
    SettingsController settings,
  ) async {
    final values = settings.settings;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: values.reminderHour,
        minute: values.reminderMinute,
      ),
    );
    if (picked == null) return;
    await settings.setReminderTime(picked.hour, picked.minute);
  }

  Future<void> _resetAppData(
    BuildContext context,
    SettingsController settings,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showZadConfirm(
      context,
      title: l10n.t('settings.resetApp'),
      body: l10n.t('settings.resetAppBody'),
      confirmLabel: l10n.t('settings.resetAppConfirm'),
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final quran = context.read<QuranController>();
    final azkar = context.read<AzkarController>();
    final tasbeeh = context.read<TasbeehController>();
    final prayer = context.read<PrayerController>();

    await settings.resetAppData();
    quran.reloadPersisted();
    azkar.reloadPersisted();
    await tasbeeh.reloadPersisted();
    await prayer.refresh();

    if (!context.mounted) return;
    showZadSnack(context, l10n.t('settings.resetDone'));
  }
}

/// Simple single-choice sheet shared by the settings pickers.
Future<T?> _pickOption<T>(
  BuildContext context, {
  required String title,
  required T current,
  required List<T> options,
  required String Function(T) labelOf,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.66,
        child: Column(
          children: <Widget>[
            const SizedBox(height: ZadSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.md),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final selected = option == current;
                  return ListTile(
                    selected: selected,
                    leading: Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: Text(labelOf(option)),
                    onTap: () => Navigator.of(sheetContext).pop(option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: ZadSpacing.sm),
        Text(label, style: theme.textTheme.labelLarge),
      ],
    );
  }
}
