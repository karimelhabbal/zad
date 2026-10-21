import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/settings_models.dart';
import '../../data/services/location_service.dart';
import '../../data/services/prayer_times_service.dart';
import '../../l10n/app_localizations.dart';
import '../../state/prayer_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_app_bar.dart';

/// Real prayer times computed astronomically from the device location (or a
/// manually chosen city) — never a static timetable.
///
/// The same [PrayerController] feeds the home dashboard, so both screens always
/// show identical data.
class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prayer = context.read<PrayerController>();
      prayer.startTicker();
      if (prayer.state == PrayerState.idle) {
        prayer.refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prayer = context.watch<PrayerController>();

    return Scaffold(
      appBar: ZadAppBar(
        title: l10n.t('prayer.title'),
        subtitle: prayer.locationSummary.isEmpty
            ? l10n.t('prayer.calculating')
            : prayer.locationSummary,
        showLogo: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_forward_rounded),
          tooltip: l10n.t('common.close'),
        ),
        actions: <Widget>[
          ZadIconButton(
            icon: Icons.edit_location_alt_outlined,
            tooltip: l10n.t('prayer.manualLocation'),
            onPressed: () => showLocationSheet(context),
          ),
          ZadIconButton(
            icon: Icons.refresh_rounded,
            tooltip: l10n.t('common.retry'),
            onPressed: () => prayer.refresh(requestPermission: true),
          ),
        ],
      ),
      body: _body(context, l10n, prayer),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    PrayerController prayer,
  ) {
    switch (prayer.state) {
      case PrayerState.permissionDenied:
        return PermissionView(
          title: l10n.t('prayer.permissionDenied'),
          body: l10n.t('prayer.permissionDeniedBody'),
          primaryLabel: l10n.t('prayer.manualLocation'),
          onPrimary: () => showLocationSheet(context),
          secondaryLabel: l10n.t('prayer.openSettings'),
          onSecondary: () => prayer.openAppSettings(),
        );
      case PrayerState.needsLocation:
        return PermissionView(
          title: l10n.t('home.locationNeeded'),
          body: l10n.t('home.locationNeededBody'),
          icon: Icons.location_searching_rounded,
          primaryLabel: l10n.t('settings.useMyLocation'),
          onPrimary: () => prayer.refresh(requestPermission: true),
          secondaryLabel: l10n.t('prayer.manualLocation'),
          onSecondary: () => showLocationSheet(context),
        );
      case PrayerState.error:
        return ErrorView(
          title: l10n.t('prayer.error'),
          body: l10n.t('prayer.errorBody'),
          onRetry: () => prayer.refresh(requestPermission: true),
        );
      case PrayerState.idle:
      case PrayerState.loading:
      case PrayerState.ready:
        break;
    }

    final schedule = prayer.schedule;
    if (schedule == null) {
      return prayer.state == PrayerState.ready
          ? ErrorView(
              title: l10n.t('prayer.error'),
              body: l10n.t('prayer.errorBody'),
              onRetry: () => prayer.refresh(requestPermission: true),
            )
          : LoadingView(message: l10n.t('prayer.calculating'));
    }

    final settings = context.watch<SettingsController>();
    final next = schedule.next;
    final current = schedule.current;
    final nextTime = schedule.nextTime;

    return RefreshIndicator(
      onRefresh: () => prayer.refresh(requestPermission: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          ZadSpacing.md,
          ZadSpacing.md,
          ZadSpacing.md,
          ZadSpacing.xl,
        ),
        children: <Widget>[
          _NextPrayerHero(
            nextLabel: l10n.t(next?.labelKey ?? 'prayer.fajr'),
            nextTime: nextTime,
            remaining: prayer.remaining,
            progress: prayer.dayProgress,
            methodLabel: l10n.t(settings.settings.calculationMethod.labelKey),
          ),
          const SizedBox(height: ZadSpacing.lg),
          SectionHeader(
            title: l10n.t('prayer.times'),
            icon: Icons.schedule_rounded,
            action: ZadBadge(
              label: l10n.t('prayer.timezone'),
              icon: Icons.public_rounded,
            ),
          ),
          const SizedBox(height: ZadSpacing.sm),
          ZadCard(
            padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
            child: Column(
              children: <Widget>[
                for (var i = 0; i < PrayerSlot.values.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 1, indent: ZadSpacing.md),
                  _PrayerRow(
                    slot: PrayerSlot.values[i],
                    time: schedule.timeOf(PrayerSlot.values[i]),
                    isNext: PrayerSlot.values[i] == next,
                    isCurrent: PrayerSlot.values[i] == current,
                    now: prayer.now,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          _TomorrowFajrCard(prayer: prayer, settings: settings.settings),
          const SizedBox(height: ZadSpacing.lg),
          SectionHeader(
            title: l10n.t('prayer.location'),
            icon: Icons.my_location_rounded,
            action: TextButton(
              onPressed: () => showLocationSheet(context),
              child: Text(l10n.t('common.edit')),
            ),
          ),
          const SizedBox(height: ZadSpacing.sm),
          ZadCard(
            padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
            child: Column(
              children: <Widget>[
                _InfoRow(
                  icon: Icons.place_outlined,
                  label: l10n.t('prayer.currentLocation'),
                  value: prayer.locationSummary.isEmpty
                      ? l10n.t('common.notAvailable')
                      : prayer.locationSummary,
                ),
                const Divider(height: 1, indent: ZadSpacing.md),
                _InfoRow(
                  icon: Icons.gps_fixed_rounded,
                  label: l10n.t('settings.coordinates'),
                  value: prayer.location.isOk
                      ? '${prayer.location.latitude!.toStringAsFixed(4)}, '
                            '${prayer.location.longitude!.toStringAsFixed(4)}'
                      : l10n.t('common.notAvailable'),
                ),
                const Divider(height: 1, indent: ZadSpacing.md),
                _InfoRow(
                  icon: Icons.calculate_outlined,
                  label: l10n.t('prayer.method'),
                  value: l10n.t(settings.settings.calculationMethod.labelKey),
                ),
                const Divider(height: 1, indent: ZadSpacing.md),
                _InfoRow(
                  icon: Icons.balance_rounded,
                  label: l10n.t('prayer.madhab'),
                  value: l10n.t(
                    settings.settings.asrMadhab == AsrMadhab.hanafi
                        ? 'prayer.madhabHanafi'
                        : 'prayer.madhabStandard',
                  ),
                ),
                if (settings.settings.highLatitude != HighLatitudeOption.none) ...[
                  const Divider(height: 1, indent: ZadSpacing.md),
                  _InfoRow(
                    icon: Icons.height_rounded,
                    label: l10n.t('prayer.highLatitude'),
                    value: l10n.t(settings.settings.highLatitude.labelKey),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          Text(
            l10n.t('settings.sourcesBody'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// Opens the shared manual-location sheet. Used from here, the Qibla screen and
/// settings so the behaviour is identical everywhere.
Future<void> showLocationSheet(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _LocationSheet(),
  );
  if (!context.mounted) return;
  // Recompute after the sheet closes with whatever the user chose.
  final prayer = context.read<PrayerController>();
  await prayer.refresh(requestPermission: true);
  if (!context.mounted) return;
  showZadSnack(context, l10n.t('settings.locationSaved'));
}

class _NextPrayerHero extends StatelessWidget {
  const _NextPrayerHero({
    required this.nextLabel,
    required this.nextTime,
    required this.remaining,
    required this.progress,
    required this.methodLabel,
  });

  final String nextLabel;
  final DateTime? nextTime;
  final Duration remaining;
  final double progress;
  final String methodLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.all(ZadSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: tokens.heroGradient,
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(ZadRadius.xxl),
        border: Border.all(color: tokens.gold.withValues(alpha: 0.35)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tokens.ambientShadow,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.mosque_rounded, size: 20, color: tokens.gold),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: Text(
                  '${l10n.t('prayer.next')}: $nextLabel',
                  style: zadText(
                    size: 16,
                    weight: 600,
                    family: ZadFonts.arabicUi,
                    color: tokens.gold,
                  ),
                ),
              ),
              if (nextTime != null)
                ZadBadge(
                  label: l10n.clock(nextTime!),
                  color: tokens.gold,
                  foreground: tokens.heroGold,
                ),
            ],
          ),
          const SizedBox(height: ZadSpacing.md),
          Text(
            l10n.t('prayer.remainingTime'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: tokens.heroMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.duration(remaining),
            style: zadText(
              size: 40,
              weight: 700,
              height: 1.15,
              family: ZadFonts.arabicUi,
              color: tokens.heroOn,
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(ZadRadius.full),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: tokens.heroTrack,
              valueColor: AlwaysStoppedAnimation<Color>(tokens.gold),
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          Text(
            methodLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: tokens.heroMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.slot,
    required this.time,
    required this.isNext,
    required this.isCurrent,
    required this.now,
  });

  final PrayerSlot slot;
  final DateTime? time;
  final bool isNext;
  final bool isCurrent;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;
    final active = isNext || isCurrent;
    final icon = switch (slot) {
      PrayerSlot.fajr => Icons.wb_twilight_rounded,
      PrayerSlot.sunrise => Icons.wb_sunny_rounded,
      PrayerSlot.dhuhr => Icons.light_mode_rounded,
      PrayerSlot.asr => Icons.brightness_5_rounded,
      PrayerSlot.maghrib => Icons.wb_twilight_rounded,
      PrayerSlot.isha => Icons.nights_stay_rounded,
    };

    final elapsed = (isCurrent && time != null) ? now.difference(time!) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.md,
        vertical: ZadSpacing.sm + 2,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: active
                  ? scheme.primaryContainer.withValues(alpha: 0.32)
                  : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(ZadRadius.md),
              border: active ? Border.all(color: tokens.cardBorder) : null,
            ),
            child: Icon(
              icon,
              size: 19,
              color: active ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.t(slot.labelKey),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: active ? scheme.primary : scheme.onSurface,
                  ),
                ),
                if (isNext)
                  Text(
                    l10n.t('prayer.next'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: tokens.gold,
                    ),
                  )
                else if (elapsed != null && !elapsed.isNegative)
                  Text(
                    '${l10n.t('prayer.elapsed')} ${l10n.duration(elapsed)}',
                    style: theme.textTheme.labelSmall,
                  ),
              ],
            ),
          ),
          Text(
            time == null
                ? '--:--'
                : l10n.clock(time!),
            style: zadText(
              size: active ? 20 : 18,
              weight: active ? 700 : 500,
              family: ZadFonts.arabicUi,
              color: active ? scheme.primary : scheme.onSurface,
            ),
          ),
          if (isNext)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: ZadSpacing.sm),
              child: Icon(Icons.chevron_left_rounded, size: 18, color: tokens.gold),
            ),
        ],
      ),
    );
  }
}

class _TomorrowFajrCard extends StatelessWidget {
  const _TomorrowFajrCard({required this.prayer, required this.settings});

  final PrayerController prayer;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final location = prayer.location;
    if (!location.isOk) return const SizedBox.shrink();

    final tomorrow = const PrayerTimesService().tomorrowFajr(
      latitude: location.latitude!,
      longitude: location.longitude!,
      settings: settings,
    );

    return ZadCard(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.md,
        vertical: ZadSpacing.sm + 4,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.nights_stay_outlined,
            size: 19,
            color: context.tokens.gold,
          ),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Text(
              l10n.t('prayer.tomorrowFajr'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Text(
            tomorrow == null
                ? '--:--'
                : l10n.clock(tomorrow),
            style: zadText(
              size: 18,
              weight: 600,
              family: ZadFonts.arabicUi,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.md,
        vertical: ZadSpacing.sm + 4,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(width: ZadSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}

/// Manual location: search a city by name or enter coordinates directly.
class _LocationSheet extends StatefulWidget {
  const _LocationSheet();

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  final TextEditingController _city = TextEditingController();
  final TextEditingController _latitude = TextEditingController();
  final TextEditingController _longitude = TextEditingController();

  Timer? _debounce;
  List<GeoPlace> _results = const <GeoPlace>[];
  bool _searching = false;
  bool _searched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final location = context.read<SettingsController>().settings.location;
    if (location.latitude != null) {
      _latitude.text = location.latitude!.toStringAsFixed(4);
    }
    if (location.longitude != null) {
      _longitude.text = location.longitude!.toStringAsFixed(4);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _city.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  void _onCityChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = const <GeoPlace>[];
        _searched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() => _searching = true);
    final results = await context.read<PrayerController>().searchCity(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
      _searched = true;
    });
  }

  Future<void> _applyCity(GeoPlace place) async {
    final settings = context.read<SettingsController>();
    await settings.setManualLocation(
      latitude: place.latitude,
      longitude: place.longitude,
      cityName: place.name,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _applyCoordinates() async {
    final l10n = context.l10n;
    final invalid = PrayerLocation.validateCoordinates(
      _latitude.text,
      _longitude.text,
    );
    if (invalid != null) {
      setState(() => _error = l10n.t('prayer.invalidCoordinates'));
      return;
    }
    setState(() => _error = null);
    await context.read<SettingsController>().setManualLocation(
      latitude: double.parse(_latitude.text.trim()),
      longitude: double.parse(_longitude.text.trim()),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _useDeviceLocation() async {
    await context.read<SettingsController>().setUseDeviceLocation(true);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final useDevice = context
        .watch<SettingsController>()
        .settings
        .location
        .useDeviceLocation;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: <Widget>[
            const SizedBox(height: ZadSpacing.sm),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                ZadSpacing.md,
                0,
                ZadSpacing.md,
                ZadSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.t('prayer.manualLocation'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: ZadSpacing.sm),
                  Wrap(
                    spacing: ZadSpacing.sm,
                    runSpacing: ZadSpacing.sm,
                    children: <Widget>[
                      ZadFilterChip(
                        label: l10n.t('prayer.locationDevice'),
                        selected: useDevice,
                        onTap: _useDeviceLocation,
                      ),
                      ZadFilterChip(
                        label: l10n.t('prayer.locationManual'),
                        selected: !useDevice,
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: ZadSpacing.md),
                  TextField(
                    controller: _city,
                    onChanged: _onCityChanged,
                    decoration: InputDecoration(
                      hintText: l10n.t('settings.citySearchHint'),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(ZadSpacing.lg),
                        child: Text(
                          _searched
                              ? l10n.t('settings.noCityResults')
                              : l10n.t('prayer.cityHint'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final place = _results[index];
                        return ListTile(
                          leading: Icon(
                            Icons.place_outlined,
                            size: 20,
                            color: scheme.primary,
                          ),
                          title: Text(place.name),
                          subtitle: Text(
                            '${place.latitude.toStringAsFixed(3)}, '
                            '${place.longitude.toStringAsFixed(3)}'
                            '${place.country == null ? '' : ' • ${place.country}'}',
                            style: theme.textTheme.labelSmall,
                          ),
                          onTap: () => _applyCity(place),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(ZadSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.t('prayer.useCoordinates'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: ZadSpacing.sm),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _latitude,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.\-]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: l10n.t('prayer.latitude'),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: ZadSpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: _longitude,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.\-]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: l10n.t('prayer.longitude'),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    l10n.t('prayer.coordinatesHint'),
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: ZadSpacing.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(l10n.t('common.cancel')),
                        ),
                      ),
                      const SizedBox(width: ZadSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed: _applyCoordinates,
                          child: Text(l10n.t('prayer.useCoordinates')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
