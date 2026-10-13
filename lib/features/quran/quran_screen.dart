import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/hijri_date.dart';
import '../../data/models/quran_models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/quran_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_app_bar.dart';
import '../../widgets/zad_logo.dart';
import 'quran_audio.dart';
import 'quran_navigation.dart';

/// The Quran hub: surah / juz / page navigation, search, the display-mode
/// selector and the "continue reading" card.
class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  /// The debounced query the result lists are actually built from.
  ///
  /// An ayah scan normalises all 6236 verses (~36 ms on a desktop, several
  /// times that on a phone), so running it on every keystroke would drop
  /// frames. The field itself still repaints immediately.
  String _appliedQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _appliedQuery = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quran = context.watch<QuranController>();
    final hijri = HijriDate.fromGregorian(DateTime.now());

    return Scaffold(
      appBar: ZadAppBar(
        title: l10n.t('quran.title'),
        subtitle: <String>[
          l10n.t('quran.riwayah'),
          hijri.format(l10n.isArabic, l10n.n),
        ].join(' • '),
        actions: <Widget>[
          ZadIconButton(
            icon: Icons.graphic_eq_rounded,
            tooltip: l10n.t('audio.title'),
            onPressed: () {
              final data = quran.data;
              if (data == null) return;
              final surah = quran.hasReadingHistory
                  ? (quran.lastSurah ?? data.surah(1))
                  : data.surah(1);
              showRecitationSheet(
                context,
                surahNumber: surah.number,
                surahLabel: surah.arabicName,
              );
            },
          ),
          ZadIconButton(
            icon: Icons.bookmark_border_rounded,
            tooltip: l10n.t('quran.bookmarks'),
            badge: quran.bookmarks.isEmpty
                ? null
                : l10n.n(quran.bookmarks.length),
            onPressed: () => QuranNavigation.openBookmarks(context),
          ),
        ],
      ),
      body: quran.state == LoadState.loading
          ? LoadingView(message: l10n.t('common.loading'))
          : quran.state == LoadState.error
          ? ErrorView(
              body: quran.error,
              onRetry: () => context.read<QuranController>().initialise(),
            )
          : _body(context, l10n, quran),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    QuranController quran,
  ) {
    final settings = context.watch<SettingsController>();
    final mode = settings.settings.quranDisplayMode;

    return Column(
      children: <Widget>[
        Padding(
          // Trimmed top gutter — the app bar already provides separation.
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.md,
            ZadSpacing.xs,
            ZadSpacing.md,
            ZadSpacing.sm,
          ),
          child: Column(
            children: <Widget>[
              _ModeSelector(
                mode: mode,
                onChanged: (value) =>
                    context.read<SettingsController>().setQuranDisplayMode(value),
              ),
              const SizedBox(height: ZadSpacing.sm),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: (_) {
                  _debounce?.cancel();
                  setState(() => _appliedQuery = _search.text);
                  FocusScope.of(context).unfocus();
                },
                decoration: InputDecoration(
                  hintText: l10n.t('quran.searchHint'),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          tooltip: l10n.t('search.clear'),
                          onPressed: () {
                            _debounce?.cancel();
                            _search.clear();
                            FocusScope.of(context).unfocus();
                            setState(() => _appliedQuery = '');
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
        _ContinueCard(quran: quran, mode: mode),
        const SizedBox(height: ZadSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.md),
          child: _TabSelector(controller: _tabs),
        ),
        const SizedBox(height: ZadSpacing.sm),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: <Widget>[
              _SurahSearchTab(query: _appliedQuery, mode: mode),
              _JuzList(mode: mode),
              _PageGrid(mode: mode),
            ],
          ),
        ),
      ],
    );
  }
}

/// Segmented control that switches between the app's text reading view and the
/// separate Madinah Mushaf mode. This preserves the existing reading interface
/// while adding the Mushaf as an additional mode.
class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final QuranDisplayMode mode;
  final ValueChanged<QuranDisplayMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    Widget item(QuranDisplayMode value, IconData icon, String label) {
      final selected = value == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? scheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(ZadRadius.md),
              border: Border.all(
                color: selected ? tokens.gold.withValues(alpha: 0.5) : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 17,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: zadText(
                      size: 13,
                      weight: selected ? 700 : 500,
                      family: Theme.of(context).textTheme.labelLarge?.fontFamily,
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ZadRadius.lg),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Row(
        children: <Widget>[
          item(QuranDisplayMode.text, Icons.notes_rounded, l10n.t('quran.textMode')),
          item(
            QuranDisplayMode.mushaf,
            Icons.auto_stories_outlined,
            l10n.t('quran.mushafMode'),
          ),
        ],
      ),
    );
  }
}

class _TabSelector extends StatelessWidget {
  const _TabSelector({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(ZadRadius.full),
        ),
        child: Row(
          children: <Widget>[
            _tab(context, 0, l10n.t('quran.surahs'), l10n.n(114)),
            _tab(context, 1, l10n.t('quran.juz'), l10n.n(30)),
            _tab(context, 2, l10n.t('quran.pages'), l10n.n(604)),
          ],
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int index, String label, String count) {
    final scheme = Theme.of(context).colorScheme;
    final selected = controller.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(ZadRadius.full),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '($count)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Continue reading" hero card driven by the saved reading position.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.quran, required this.mode});

  final QuranController quran;
  final QuranDisplayMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final data = quran.data;
    if (data == null) return const SizedBox.shrink();

    final hasHistory = quran.hasReadingHistory;
    final surah = hasHistory ? quran.lastSurah : data.surah(1);
    final page = hasHistory ? quran.position.page : 1;
    final juz = hasHistory ? quran.position.juz : 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(ZadSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: tokens.heroGradient,
          ),
          borderRadius: BorderRadius.circular(ZadRadius.xl),
          border: Border.all(color: tokens.gold.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    hasHistory
                        ? l10n.t('quran.continueFrom')
                        : l10n.t('home.startReading'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF9FC0B1),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.t('quran.surahPrefix')} ${surah?.arabicName ?? ''}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.t('quran.juzNumber', args: {'n': l10n.n(juz)})} • '
                    '${l10n.t('quran.pageShort', args: {'n': l10n.n(page)})}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFCFE0D7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: ZadSpacing.sm),
            FilledButton(
              onPressed: () {
                if (mode == QuranDisplayMode.mushaf) {
                  QuranNavigation.openMushaf(context, page: page);
                } else {
                  QuranNavigation.openReader(
                    context,
                    surah: surah?.number ?? 1,
                    ayah: hasHistory ? quran.position.ayah : 1,
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEDBF7A),
                foregroundColor: const Color(0xFF2B1F05),
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Row(
                children: <Widget>[
                  Text(l10n.t('quran.goTo')),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_back, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Surahs" tab.
///
/// With an empty query it lists all 114 surahs. With a query it shows surah
/// name matches *and* real ayah-text matches, each of which navigates to the
/// exact surah/ayah it came from.
class _SurahSearchTab extends StatelessWidget {
  const _SurahSearchTab({required this.query, required this.mode});

  /// Matches the controller default; kept here so the header can say whether
  /// more matches exist without a second scan on every query.
  static const int verseLimit = 60;

  final String query;
  final QuranDisplayMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quran = context.watch<QuranController>();
    final trimmed = query.trim();
    final surahs = quran.searchSurahs(trimmed);
    final verses = trimmed.isEmpty
        ? const <(Surah, QuranVerse)>[]
        : quran.searchVerses(trimmed, limit: verseLimit);

    if (trimmed.isEmpty) {
      return ListView.separated(
        padding: _listPadding(context),
        itemCount: surahs.length,
        separatorBuilder: (_, _) => const SizedBox(height: ZadSpacing.sm),
        itemBuilder: (context, index) =>
            _SurahRow(surah: surahs[index], mode: mode),
      );
    }

    if (surahs.isEmpty && verses.isEmpty) {
      return EmptyView(
        icon: Icons.search_off_rounded,
        title: l10n.t('search.noResults'),
        body: l10n.t('search.noResultsBody'),
      );
    }

    // Only pay for the uncapped count when the cap was actually hit.
    final capped = verses.length >= verseLimit;
    final total = capped ? quran.countVerseMatches(trimmed) : verses.length;

    return ListView(
      padding: _listPadding(context),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: <Widget>[
        if (surahs.isNotEmpty) ...<Widget>[
          _ResultsHeader(
            title: l10n.t('search.surahMatches'),
            count: surahs.length,
          ),
          for (final surah in surahs)
            Padding(
              padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
              child: _SurahRow(surah: surah, mode: mode),
            ),
          const SizedBox(height: ZadSpacing.sm),
        ],
        if (verses.isNotEmpty) ...<Widget>[
          _ResultsHeader(
            title: l10n.t('search.ayahMatches'),
            count: total,
            shown: verses.length,
          ),
          for (final match in verses)
            Padding(
              padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
              child: _AyahMatchRow(surah: match.$1, verse: match.$2),
            ),
        ],
      ],
    );
  }

  /// Clears the floating dock and the Android navigation bar.
  static EdgeInsets _listPadding(BuildContext context) => EdgeInsets.fromLTRB(
    ZadSpacing.md,
    0,
    ZadSpacing.md,
    MediaQuery.of(context).padding.bottom + ZadSpacing.md,
  );
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.title,
    required this.count,
    this.shown,
  });

  final String title;
  final int count;

  /// How many of [count] are actually rendered, when the list was capped.
  final int? shown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final n = l10n.n(count);
    final truncated = shown != null && shown! < count;
    final subtitle = truncated
        ? l10n.t(
            'search.showingOf',
            args: <String, Object?>{
              'shown': l10n.n(shown!),
              'total': n,
            },
          )
        : l10n.t('search.resultsCount', args: <String, Object?>{'n': n});

    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
      child: SectionHeader(title: title, subtitle: subtitle),
    );
  }
}

/// One ayah-text search hit; tapping opens the reader at that exact ayah.
class _AyahMatchRow extends StatelessWidget {
  const _AyahMatchRow({required this.surah, required this.verse});

  final Surah surah;
  final QuranVerse verse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ZadCard(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.md,
        vertical: ZadSpacing.sm,
      ),
      onTap: () => QuranNavigation.openReader(
        context,
        surah: surah.number,
        ayah: verse.numberInSurah,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            verse.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: quranVerseStyle(
              color: scheme.onSurface,
              size: 18,
              height: 1.9,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${l10n.t('quran.surahPrefix')} ${surah.arabicName} • '
                  '${l10n.t('search.ayahLabel', args: {'n': l10n.n(verse.numberInSurah)})} • '
                  '${l10n.t('quran.pageShort', args: {'n': l10n.n(verse.page)})}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ),
              Icon(
                Icons.arrow_back_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SurahRow extends StatelessWidget {
  const _SurahRow({required this.surah, required this.mode});

  final Surah surah;
  final QuranDisplayMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final quran = context.watch<QuranController>();

    return ZadCard(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.md,
        vertical: ZadSpacing.sm + 2,
      ),
      onTap: () {
        if (mode == QuranDisplayMode.mushaf) {
          QuranNavigation.openMushaf(context, page: surah.startPage);
        } else {
          QuranNavigation.openReader(context, surah: surah.number, ayah: 1);
        }
      },
      child: Row(
        children: <Widget>[
          OctagonBadge(label: l10n.n(surah.number), size: 36),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        '${l10n.t('quran.surahPrefix')} ${surah.arabicName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: zadText(
                          size: 17,
                          weight: 600,
                          family: ZadFonts.classical,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ZadBadge(
                      label: surah.isMeccan
                          ? l10n.t('quran.meccan')
                          : l10n.t('quran.medinan'),
                      color: scheme.outline,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${l10n.t('quran.ayahCount', args: {'n': l10n.n(surah.ayahCount)})} • '
                  '${l10n.t('quran.pageShort', args: {'n': l10n.n(surah.startPage)})}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: ZadSpacing.sm),
          Column(
            children: <Widget>[
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => QuranNavigation.openBookmarks(context),
                icon: Icon(
                  quran.bookmarks.any((b) => b.surah == surah.number)
                      ? Icons.bookmark
                      : Icons.bookmark_border_rounded,
                  size: 18,
                  color: quran.bookmarks.any((b) => b.surah == surah.number)
                      ? context.tokens.gold
                      : scheme.onSurfaceVariant,
                ),
                tooltip: l10n.t('quran.bookmarks'),
              ),
              Text(
                l10n.n(surah.startPage),
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JuzList extends StatelessWidget {
  const _JuzList({required this.mode});

  final QuranDisplayMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quran = context.watch<QuranController>();
    final data = quran.data;
    if (data == null) return const SizedBox.shrink();

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        ZadSpacing.md,
        0,
        ZadSpacing.md,
        MediaQuery.of(context).padding.bottom + ZadSpacing.md,
      ),
      itemCount: 30,
      separatorBuilder: (_, _) => const SizedBox(height: ZadSpacing.sm),
      itemBuilder: (context, index) {
        final juz = index + 1;
        final page = data.meta.juzStartPage[juz] ?? 1;
        final first = quran.firstVerseOfJuz(juz);
        return ZadCard(
          padding: const EdgeInsets.symmetric(
            horizontal: ZadSpacing.md,
            vertical: ZadSpacing.sm + 2,
          ),
          onTap: () {
            if (mode == QuranDisplayMode.mushaf) {
              QuranNavigation.openMushaf(context, page: page);
            } else if (first != null) {
              QuranNavigation.openReader(
                context,
                surah: first.$1.number,
                ayah: first.$2.numberInSurah,
              );
            }
          },
          child: Row(
            children: <Widget>[
              OctagonBadge(label: l10n.n(juz), size: 36),
              const SizedBox(width: ZadSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.t('quran.juzNumber', args: <String, Object?>{
                        'n': l10n.n(juz),
                      }),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      first == null
                          ? l10n.t('quran.pageShort', args: {'n': l10n.n(page)})
                          : '${l10n.t('quran.surahPrefix')} ${first.$1.arabicName} • '
                                '${l10n.t('quran.ayah')} ${l10n.n(first.$2.numberInSurah)}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              Text(
                l10n.t('quran.pageShort', args: <String, Object?>{
                  'n': l10n.n(page),
                }),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PageGrid extends StatelessWidget {
  const _PageGrid({required this.mode});

  final QuranDisplayMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quran = context.watch<QuranController>();
    final data = quran.data;
    if (data == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        ZadSpacing.md,
        0,
        ZadSpacing.md,
        MediaQuery.of(context).padding.bottom + ZadSpacing.md,
      ),
      itemCount: data.meta.totalPages,
      itemBuilder: (context, index) {
        final page = index + 1;
        final surah = data.surahForPage(page);
        final isJuzStart = data.meta.juzStartPage.containsValue(page);
        final juz = data.juzForPage(page);

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: ZadCard(
            padding: const EdgeInsets.symmetric(
              horizontal: ZadSpacing.md,
              vertical: ZadSpacing.sm,
            ),
            onTap: () => QuranNavigation.openMushaf(context, page: page),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 44,
                  child: Text(
                    l10n.n(page),
                    style: zadText(
                      size: 15,
                      weight: 700,
                      family: ZadFonts.latinUi,
                      color: scheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${l10n.t('quran.surahPrefix')} ${surah.arabicName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (isJuzStart)
                  ZadBadge(
                    label: l10n.t('quran.juzNumber', args: {'n': l10n.n(juz)}),
                  ),
                const SizedBox(width: 6),
                Icon(
                  Icons.auto_stories_outlined,
                  size: 17,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
