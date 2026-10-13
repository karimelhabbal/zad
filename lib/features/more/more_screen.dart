import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/repositories/mushaf_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_app_bar.dart';
import '../../widgets/zad_logo.dart';
import '../quran/quran_navigation.dart';
import '../shell/app_shell.dart';

/// The "more" tab: every secondary destination in one place, plus offline page
/// management and app information.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shell = AppShellState.of(context);
    final theme = Theme.of(context);
    final tokens = context.tokens;

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
        title: l10n.t('more.offline'),
        body: l10n.t('more.offlineBody'),
        icon: Icons.cloud_download_outlined,
        onTap: () => _showOfflineSheet(context),
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
                    trailing: const Icon(Icons.chevron_left_rounded, size: 18),
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

  Future<void> _showOfflineSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _OfflineSheet(),
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
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(height: ZadSpacing.sm),
          Text(
            l10n.t('app.values'),
            style: zadText(
              size: 12,
              weight: 600,
              family: ZadFonts.arabicUi,
              color: tokens.gold,
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          ZadBadge(
            label: l10n.t('app.versionNote'),
            icon: Icons.verified_outlined,
            color: tokens.gold,
          ),
        ],
      ),
    );
  }
}

/// Offline Mushaf page management: how many pages are stored, download them all
/// or clear the cache.
class _OfflineSheet extends StatefulWidget {
  const _OfflineSheet();

  @override
  State<_OfflineSheet> createState() => _OfflineSheetState();
}

class _OfflineSheetState extends State<_OfflineSheet> {
  int? _downloaded;
  int? _bytes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final repo = context.read<MushafRepository>();
    final count = await repo.downloadedCount();
    final bytes = await repo.cacheSizeBytes();
    if (!mounted) return;
    setState(() {
      _downloaded = count;
      _bytes = bytes;
    });
  }

  Future<void> _clear() async {
    final l10n = context.l10n;
    final confirmed = await showZadConfirm(
      context,
      title: l10n.t('quran.clearCache'),
      body: l10n.t('quran.cacheCleared'),
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    await context.read<MushafRepository>().clearCache();
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    showZadSnack(context, l10n.t('quran.cacheCleared'));
  }

  Future<void> _downloadAll() async {
    if (_busy) return;
    setState(() => _busy = true);
    final repo = context.read<MushafRepository>();
    await repo.downloadAll(
      onProgress: (done, _) {
        if (!mounted) return;
        setState(() => _downloaded = done);
      },
      shouldCancel: () => !mounted,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    await _refresh();
  }

  String _sizeLabel(int bytes) {
    if (bytes <= 0) return '0';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final count = _downloaded;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.cloud_download_outlined, size: 20, color: tokens.gold),
                const SizedBox(width: ZadSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.t('more.offline'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.sm),
            Text(l10n.t('more.offlineBody'), style: theme.textTheme.bodySmall),
            const SizedBox(height: ZadSpacing.md),
            ZadCard(
              padding: const EdgeInsets.all(ZadSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ZadRadius.full),
                    child: LinearProgressIndicator(
                      value: count == null
                          ? null
                          : (count / MushafRepository.totalPages).clamp(0.0, 1.0),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          l10n.t(
                            'quran.downloadedCount',
                            args: <String, Object?>{'n': l10n.n(count ?? 0)},
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      if (_bytes != null && _bytes! > 0)
                        ZadBadge(
                          label: _sizeLabel(_bytes!),
                          icon: Icons.sd_storage_outlined,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZadSpacing.md),
            Text(
              l10n.t('quran.downloadAllBody'),
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: ZadSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy || (count ?? 0) == 0 ? null : _clear,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(l10n.t('quran.clearCache')),
                  ),
                ),
                const SizedBox(width: ZadSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _downloadAll,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded, size: 18),
                    label: Text(l10n.t('quran.downloadAll')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              MushafRepository.primarySourceLabel,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
