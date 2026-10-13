import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/hijri_date.dart';
import '../../data/services/prayer_times_service.dart';
import '../../l10n/app_localizations.dart';
import '../../state/azkar_controller.dart';
import '../../state/prayer_controller.dart';
import '../../state/quran_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/tasbeeh_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_app_bar.dart';
import '../../widgets/zad_logo.dart';
import '../quran/quran_navigation.dart';
import '../shell/app_shell.dart';

/// The home dashboard: greeting, next prayer with a live countdown, the daily
/// Quran portion, quick access and the verse of the day.
///
/// Every value on this screen comes from real application state — prayer times
/// from the astronomical calculation, the Quran portion from the saved reading
/// position, and the counters from local storage.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    final quran = context.watch<QuranController>();
    final settings = context.watch<SettingsController>();

    final hijri = HijriDate.fromGregorian(DateTime.now());
    final locationLabel = prayer.locationSummary.isNotEmpty
        ? prayer.locationSummary
        : (settings.settings.location.cityName ?? '');

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: ZadAppBar(
        title: l10n.t('app.name'),
        subtitle: <String>[
          if (locationLabel.isNotEmpty) locationLabel,
          hijri.format(l10n.isArabic, l10n.n),
        ].join(' • '),
        actions: <Widget>[
          ZadIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: l10n.t('settings.notifications'),
            onPressed: () => _showNotificationsInfo(context),
          ),
          ZadIconButton(
            icon: Icons.search_rounded,
            tooltip: l10n.t('common.search'),
            // Opens the real Qur'an search (surah names + ayah text) instead of
            // merely switching tabs.
            onPressed: () => QuranNavigation.openSearch(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<PrayerController>().refresh(),
        child: ListView(
          // The shell publishes the dock + navigation-bar clearance here.
          padding: EdgeInsets.fromLTRB(
            ZadSpacing.md,
            ZadSpacing.sm,
            ZadSpacing.md,
            MediaQuery.of(context).padding.bottom + ZadSpacing.md,
          ),
          children: <Widget>[
            const _GreetingCard(),
            const SizedBox(height: ZadSpacing.md),
            _PrayerHeroCard(prayer: prayer),
            const SizedBox(height: ZadSpacing.md),
            const _TodayStats(),
            const SizedBox(height: ZadSpacing.lg),
            _DailyWirdCard(quran: quran),
            const SizedBox(height: ZadSpacing.lg),
            _QuickAccess(),
            const SizedBox(height: ZadSpacing.lg),
            _VerseOfDayCard(quran: quran),
          ],
        ),
      ),
    );
  }

  void _showNotificationsInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showZadSnack(context, l10n.t('settings.notificationsNote'));
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? l10n.t('home.greetingMorning')
        : (hour < 17 ? l10n.t('home.greetingAfternoon') : l10n.t('home.greetingEvening'));

    return ZadCard(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.md,
        vertical: ZadSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainerHigh,
              border: Border.all(color: context.tokens.cardBorder),
            ),
            child: Icon(
              hour < 12
                  ? Icons.wb_twilight
                  : (hour < 17 ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined),
              size: 22,
              color: context.tokens.gold,
            ),
          ),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.t('home.salam'),
                  style: theme.textTheme.headlineSmall?.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 2),
                Text(
                  '$greeting، ${l10n.t('home.subtitle')}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The emerald prayer horizon card: next prayer, live countdown, day progress
/// and the six daily milestones.
class _PrayerHeroCard extends StatelessWidget {
  const _PrayerHeroCard({required this.prayer});

  final PrayerController prayer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (prayer.state == PrayerState.loading && prayer.schedule == null) {
      return _HeroShell(
        child: SizedBox(
          height: 168,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Color(0xFFB5EFD3),
                  ),
                ),
                const SizedBox(height: ZadSpacing.md),
                Text(
                  l10n.t('prayer.calculating'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFB5EFD3),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (prayer.state == PrayerState.permissionDenied ||
        prayer.state == PrayerState.needsLocation) {
      final denied = prayer.state == PrayerState.permissionDenied;
      return _HeroShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _heroTitle(context, l10n.t('prayer.title')),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              denied
                  ? l10n.t('prayer.permissionDenied')
                  : l10n.t('home.locationNeeded'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFDFEDE6),
              ),
            ),
            const SizedBox(height: ZadSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: () => prayer.refresh(requestPermission: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEDBF7A),
                      foregroundColor: const Color(0xFF2B1F05),
                    ),
                    child: Text(l10n.t('home.enableLocation')),
                  ),
                ),
                const SizedBox(width: ZadSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => prayer.openAppSettings(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEDBF7A),
                      side: const BorderSide(color: Color(0xFFEDBF7A)),
                    ),
                    child: Text(l10n.t('prayer.openSettings')),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final schedule = prayer.schedule;
    if (schedule == null) {
      return _HeroShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _heroTitle(context, l10n.t('home.prayerError')),
            const SizedBox(height: ZadSpacing.md),
            FilledButton(
              onPressed: () => prayer.refresh(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEDBF7A),
                foregroundColor: const Color(0xFF2B1F05),
              ),
              child: Text(l10n.t('common.retry')),
            ),
          ],
        ),
      );
    }

    final next = schedule.next;
    final current = schedule.current;

    return _HeroShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.mosque_outlined,
                size: 20,
                color: Color(0xFFEDBF7A),
              ),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: Text(
                  '${l10n.t('home.nextPrayer')}: '
                  '${l10n.t(next?.labelKey ?? 'prayer.fajr')}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFFEDBF7A),
                  ),
                ),
              ),
              ZadBadge(
                label: l10n.t(
                  'prayer.method.${context.read<SettingsController>().settings.calculationMethod.name}',
                ),
                color: const Color(0xFFEDBF7A),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.md),
          Text(
            l10n.t('home.remaining'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFF9FC0B1),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.duration(prayer.remaining),
            style: zadText(
              size: 40,
              weight: 700,
              height: 1.15,
              family: ZadFonts.arabicUi,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: ZadSpacing.sm),
          Row(
            children: <Widget>[
              Icon(
                Icons.place_outlined,
                size: 13,
                color: const Color(0xFF9FC0B1),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  current == null
                      ? l10n.t('prayer.times')
                      : l10n.t(
                          'home.currentPrayer',
                          args: <String, Object?>{
                            'prayer': l10n.t(current.labelKey),
                          },
                        ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF9FC0B1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(ZadRadius.full),
            child: LinearProgressIndicator(
              value: prayer.dayProgress,
              minHeight: 4,
              backgroundColor: const Color(0x33FFFFFF),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEDBF7A)),
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          const ZadDivider(),
          const SizedBox(height: ZadSpacing.sm),
          Row(
            children: <Widget>[
              for (final slot in PrayerSlot.values)
                Expanded(
                  child: _PrayerMilestone(
                    slot: slot,
                    time: schedule.timeOf(slot),
                    isNext: slot == next,
                    isCurrent: slot == current,
                  ),
                ),
            ],
          ),
          const SizedBox(height: ZadSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => QuranNavigation.openPrayerTimes(context),
              icon: const Icon(Icons.schedule_outlined, size: 16),
              label: Text(l10n.t('prayer.title')),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEDBF7A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroTitle(BuildContext context, String text) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      color: const Color(0xFFEDBF7A),
    ),
  );
}

class _HeroShell extends StatelessWidget {
  const _HeroShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZadSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: tokens.heroGradient,
        ),
        borderRadius: BorderRadius.circular(ZadRadius.xl),
        border: Border.all(color: tokens.gold.withValues(alpha: 0.35)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tokens.ambientShadow,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          PositionedDirectional(
            top: -12,
            end: -12,
            child: Opacity(
              opacity: 0.16,
              child: const KhatamWatermark(
                size: 120,
                child: SizedBox(width: 120, height: 120),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _PrayerMilestone extends StatelessWidget {
  const _PrayerMilestone({
    required this.slot,
    required this.time,
    required this.isNext,
    required this.isCurrent,
  });

  final PrayerSlot slot;
  final DateTime? time;
  final bool isNext;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = isNext || isCurrent;
    final icon = switch (slot) {
      PrayerSlot.fajr => Icons.wb_twilight,
      PrayerSlot.sunrise => Icons.wb_sunny_outlined,
      PrayerSlot.dhuhr => Icons.light_mode_outlined,
      PrayerSlot.asr => Icons.brightness_5_outlined,
      PrayerSlot.maghrib => Icons.wb_twilight_outlined,
      PrayerSlot.isha => Icons.nights_stay_outlined,
    };

    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFEDBF7A).withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(ZadRadius.md),
            border: active
                ? Border.all(color: const Color(0x66EDBF7A))
                : null,
          ),
          child: Icon(
            icon,
            size: 15,
            color: active ? const Color(0xFFEDBF7A) : const Color(0xFF8FAEA0),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.t(slot.labelKey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: zadText(
            size: 9,
            weight: active ? 700 : 500,
            family: ZadFonts.arabicUi,
            color: active ? const Color(0xFFEDBF7A) : const Color(0xFF8FAEA0),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          time == null
              ? '--:--'
              : l10n.clock(time!),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: zadText(
            size: 10,
            weight: 600,
            family: ZadFonts.latinUi,
            color: active ? Colors.white : const Color(0xFFCFE0D7),
          ),
        ),
      ],
    );
  }
}

/// Today's adhkar, tasbeeh and Quran counters — all from real local state.
class _TodayStats extends StatelessWidget {
  const _TodayStats();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final azkar = context.watch<AzkarController>();
    final tasbeeh = context.watch<TasbeehController>();
    final quran = context.watch<QuranController>();

    final pagesRead = quran.hasReadingHistory ? quran.position.page : 0;

    return Row(
      children: <Widget>[
        Expanded(
          child: StatTile(
            label: l10n.t('home.dhikrToday'),
            value: '${l10n.n(azkar.totalCompleted)}/${l10n.n(azkar.totalItems)}',
            icon: Icons.auto_awesome_outlined,
          ),
        ),
        const SizedBox(width: ZadSpacing.sm),
        Expanded(
          child: StatTile(
            label: l10n.t('home.tasbeehToday'),
            value: l10n.n(tasbeeh.totalToday),
            unit: l10n.t('home.times'),
            icon: Icons.adjust,
          ),
        ),
        const SizedBox(width: ZadSpacing.sm),
        Expanded(
          child: StatTile(
            label: l10n.t('home.quranPagesToday'),
            value: l10n.n(pagesRead),
            unit: '/ ${l10n.n(604)}',
            icon: Icons.menu_book_outlined,
          ),
        ),
      ],
    );
  }
}

/// The daily Quran portion card, driven by the saved reading position.
class _DailyWirdCard extends StatelessWidget {
  const _DailyWirdCard({required this.quran});

  final QuranController quran;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final data = quran.data;
    final hasHistory = quran.hasReadingHistory;
    final surah = quran.lastSurah;

    if (data == null) {
      return const ZadCard(
        child: SizedBox(height: 96, child: LoadingView()),
      );
    }

    final page = hasHistory ? quran.position.page : 1;
    final juz = hasHistory ? quran.position.juz : 1;
    final ayah = hasHistory ? quran.position.ayah : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: l10n.t('home.dailyWird'),
          icon: Icons.bookmark_border_rounded,
          action: ZadBadge(label: l10n.t('quran.juzNumber', args: {'n': l10n.n(juz)})),
        ),
        const SizedBox(height: ZadSpacing.sm),
        ZadCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!hasHistory)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.t('home.noReadingYet'),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.t('home.noReadingYetBody'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                )
              else
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${l10n.t('quran.surahPrefix')} ${surah?.arabicName ?? ''}',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${l10n.t('quran.ayah')} ${l10n.n(ayah)} • '
                            '${l10n.t('home.pageOf', args: {'page': l10n.n(page)})}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    OctagonBadge(label: l10n.n(page), size: 38),
                  ],
                ),
              const SizedBox(height: ZadSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => QuranNavigation.openReader(
                        context,
                        surah: hasHistory ? quran.position.surah : 1,
                        ayah: hasHistory ? quran.position.ayah : 1,
                      ),
                      icon: const Icon(Icons.menu_book_rounded, size: 18),
                      label: Text(
                        hasHistory
                            ? l10n.t('home.continueReading')
                            : l10n.t('home.startReading'),
                      ),
                    ),
                  ),
                  const SizedBox(width: ZadSpacing.sm),
                  IconButton(
                    onPressed: () => QuranNavigation.openMushaf(
                      context,
                      page: page,
                    ),
                    icon: const Icon(Icons.auto_stories_outlined),
                    tooltip: l10n.t('quran.mushafMode'),
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerHigh,
                      minimumSize: const Size(52, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ZadRadius.md),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAccess extends StatelessWidget {
  const _QuickAccess();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shell = AppShellState.of(context);

    final items = <_QuickItem>[
      _QuickItem(
        label: l10n.t('home.quickQuran'),
        body: l10n.t('home.quickQuranBody'),
        icon: Icons.menu_book_outlined,
        onTap: () => shell?.select(1),
      ),
      _QuickItem(
        label: l10n.t('home.quickAzkar'),
        body: l10n.t('home.quickAzkarBody'),
        icon: Icons.auto_awesome_outlined,
        onTap: () => shell?.select(2),
      ),
      _QuickItem(
        label: l10n.t('home.quickTasbeeh'),
        body: l10n.t('home.quickTasbeehBody'),
        icon: Icons.adjust,
        onTap: () => shell?.select(3),
      ),
      _QuickItem(
        label: l10n.t('home.quickQibla'),
        body: l10n.t('home.quickQiblaBody'),
        icon: Icons.explore_outlined,
        onTap: () => QuranNavigation.openQibla(context),
      ),
      _QuickItem(
        label: l10n.t('prayer.title'),
        body: l10n.t('more.prayerBody'),
        icon: Icons.schedule_outlined,
        onTap: () => QuranNavigation.openPrayerTimes(context),
      ),
      _QuickItem(
        label: l10n.t('quran.bookmarks'),
        body: l10n.t('more.bookmarksBody'),
        icon: Icons.bookmark_border_rounded,
        onTap: () => QuranNavigation.openBookmarks(context),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: l10n.t('home.quickAccess'),
          icon: Icons.bolt_outlined,
        ),
        const SizedBox(height: ZadSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 520 ? 4 : 3;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: ZadSpacing.sm,
              crossAxisSpacing: ZadSpacing.sm,
              childAspectRatio: 0.92,
              children: <Widget>[
                for (final item in items) _QuickTile(item: item),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _QuickItem {
  const _QuickItem({
    required this.label,
    required this.body,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String body;
  final IconData icon;
  final VoidCallback onTap;
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.item});

  final _QuickItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ZadCard(
      padding: const EdgeInsets.all(ZadSpacing.sm + 2),
      onTap: item.onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(ZadRadius.md),
              border: Border.all(color: context.tokens.cardBorder),
            ),
            child: Icon(item.icon, size: 20, color: scheme.primary),
          ),
          const SizedBox(height: ZadSpacing.sm),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

/// Verse of the day. The Quranic text is taken verbatim from the bundled
/// verified Mushaf text — never paraphrased.
class _VerseOfDayCard extends StatelessWidget {
  const _VerseOfDayCard({required this.quran});

  final QuranController quran;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final data = quran.data;
    if (data == null) return const SizedBox.shrink();

    final verse = data.verseOfTheDay(DateTime.now());
    final surah = verse.$1;
    final ayah = verse.$2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: l10n.t('home.verseOfDay'),
          icon: Icons.format_quote_rounded,
        ),
        const SizedBox(height: ZadSpacing.sm),
        ZadCard(
          padding: const EdgeInsets.all(ZadSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                ayah.text,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: quranVerseStyle(color: scheme.onSurface, size: 22),
              ),
              const SizedBox(height: ZadSpacing.md),
              const ZadDivider(),
              const SizedBox(height: ZadSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${l10n.t('quran.surahPrefix')} ${surah.arabicName} • '
                      '${l10n.t('quran.ayah')} ${l10n.n(ayah.numberInSurah)} • '
                      '${l10n.t('quran.pageShort', args: {'n': l10n.n(ayah.page)})}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => QuranNavigation.openMushaf(
                      context,
                      page: ayah.page,
                    ),
                    icon: const Icon(Icons.auto_stories_outlined, size: 19),
                    tooltip: l10n.t('quran.openMushaf'),
                  ),
                ],
              ),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                l10n.t('quran.edition'),
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
