import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_app_bar.dart';
import '../../widgets/zad_logo.dart';
import '../quran/quran_navigation.dart';
import '../shell/app_shell.dart';
import 'audio_downloads_screen.dart';

/// The "more" tab: every secondary destination in one place, plus the audio
/// download manager and app information.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shell = AppShellState.of(context);
    final theme = Theme.of(context);
    final tokens = context.tokens;
    // "Forward" points the other way in RTL; hard-coding chevron_left only
    // looked right because the app ships in Arabic first.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final forwardChevron = Icon(
      isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
      size: 18,
    );

    final destinations = <_Destination>[
      _Destination(
        title: l10n.t('more.quran'),
        body: l10n.t('more.quranBody'),
        icon: Icons.menu_book_outlined,
        onTap: () => shell?.select(1),
      ),
      _Destination(
        title: l10n.t('more.azkar'),
        body: l10n.t('more.azkarBody'),
        icon: Icons.auto_awesome_outlined,
        onTap: () => shell?.select(2),
      ),
      _Destination(
        title: l10n.t('more.tasbeeh'),
        body: l10n.t('more.tasbeehBody'),
        icon: Icons.blur_circular_rounded,
        onTap: () => shell?.select(3),
      ),
      _Destination(
        title: l10n.t('more.prayer'),
        body: l10n.t('more.prayerBody'),
        icon: Icons.schedule_outlined,
        onTap: () => QuranNavigation.openPrayerTimes(context),
      ),
      _Destination(
        title: l10n.t('more.qibla'),
        body: l10n.t('more.qiblaBody'),
        icon: Icons.explore_outlined,
        onTap: () => QuranNavigation.openQibla(context),
      ),
      _Destination(
        title: l10n.t('more.bookmarks'),
        body: l10n.t('more.bookmarksBody'),
        icon: Icons.bookmark_border_rounded,
        onTap: () => QuranNavigation.openBookmarks(context),
      ),
      _Destination(
        title: l10n.t('more.settings'),
        body: l10n.t('more.settingsBody'),
        icon: Icons.settings_outlined,
        onTap: () => QuranNavigation.openSettings(context),
      ),
      _Destination(
        title: l10n.t('more.audioDownloads'),
        body: l10n.t('more.audioDownloadsBody'),
        icon: Icons.download_for_offline_outlined,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AudioDownloadsScreen()),
        ),
      ),
    ];

    return Scaffold(
      appBar: ZadAppBar(
        title: l10n.t('more.title'),
        subtitle: l10n.t('app.tagline'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          ZadSpacing.md,
          ZadSpacing.md,
          ZadSpacing.md,
          MediaQuery.of(context).padding.bottom + ZadSpacing.md,
        ),
        children: <Widget>[
          const _AppCard(),
          const SizedBox(height: ZadSpacing.lg),
          SectionHeader(
            title: l10n.t('more.personal'),
            icon: Icons.grid_view_rounded,
          ),
          const SizedBox(height: ZadSpacing.sm),
          ZadCard(
            padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
            child: Column(
              children: <Widget>[
                for (var i = 0; i < destinations.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 1, indent: ZadSpacing.md),
                  SettingsTile(
                    icon: destinations[i].icon,
                    title: destinations[i].title,
                    subtitle: destinations[i].body,
                    trailing: forwardChevron,
                    onTap: destinations[i].onTap,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: ZadSpacing.lg),
          SectionHeader(
            title: l10n.t('settings.about'),
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: ZadSpacing.sm),
          ZadCard(
            padding: const EdgeInsets.all(ZadSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.t('settings.sourcesBody'),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: ZadSpacing.md),
                const ZadDivider(),
                const SizedBox(height: ZadSpacing.md),
                Row(
                  children: <Widget>[
                    Icon(Icons.lock_outline_rounded, size: 16, color: tokens.gold),
                    const SizedBox(width: ZadSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.t('settings.privacyBody'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.title,
    required this.body,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String body;
  final IconData icon;
  final VoidCallback onTap;
}

class _AppCard extends StatelessWidget {
  const _AppCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
      ),
      child: Column(
        children: <Widget>[
          const ZadLogo(size: 74),
          const SizedBox(height: ZadSpacing.md),
          Text(
            l10n.t('app.description'),
            textAlign: TextAlign.center,
            style: zadText(
              size: 13,
              weight: 400,
              family: ZadFonts.arabicUi,
              color: tokens.heroOn.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(height: ZadSpacing.sm),
          Text(
            l10n.t('app.values'),
            style: zadText(
              size: 12,
              weight: 600,
              family: ZadFonts.arabicUi,
              color: tokens.heroGold,
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          ZadBadge(
            label: l10n.t('app.versionNote'),
            icon: Icons.verified_outlined,
            color: tokens.gold,
            foreground: tokens.heroGold,
          ),
        ],
      ),
    );
  }
}
