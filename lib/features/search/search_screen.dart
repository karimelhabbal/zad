import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/quran_models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/quran_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_app_bar.dart';
import '../../widgets/zad_logo.dart';
import '../quran/quran_navigation.dart';

/// Full-screen Qur'an search over surah names *and* ayah text.
///
/// Every result navigates to the exact surah/ayah (or Mushaf page) that the
/// local dataset maps it to, so a search never dead-ends.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;

  /// The debounced query that results are actually computed from.
  String _applied = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // Repaint immediately so the clear button appears as the user types...
    setState(() {});
    // ...while the expensive ayah scan waits for a pause in typing.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _applied = value);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _query.clear();
    setState(() => _applied = '');
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quran = context.watch<QuranController>();

    return Scaffold(
      appBar: ZadAppBar(
        title: l10n.t('search.title'),
        showLogo: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              ZadSpacing.md,
              0,
              ZadSpacing.md,
              ZadSpacing.sm,
            ),
            child: TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (value) {
                _debounce?.cancel();
                setState(() => _applied = value);
                FocusScope.of(context).unfocus();
              },
              decoration: InputDecoration(
                hintText: l10n.t('search.hint'),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        tooltip: l10n.t('search.clear'),
                        onPressed: _clear,
                      ),
              ),
            ),
          ),
        ),
      ),
      body: _results(context, l10n, quran),
    );
  }

  Widget _results(
    BuildContext context,
    AppLocalizations l10n,
    QuranController quran,
  ) {
    if (quran.state == LoadState.loading) {
      return LoadingView(message: l10n.t('common.loading'));
    }
    final query = _applied.trim();
    if (query.isEmpty) {
      return EmptyView(
        icon: Icons.search_rounded,
        title: l10n.t('search.startTyping'),
      );
    }

    final surahs = quran.searchSurahs(query);
    final verses = quran.searchVerses(query);
    if (surahs.isEmpty && verses.isEmpty) {
      return EmptyView(
        icon: Icons.search_off_rounded,
        title: l10n.t('search.noResults'),
        body: l10n.t('search.noResultsBody'),
      );
    }

    final items = <Widget>[
      if (surahs.isNotEmpty) ...<Widget>[
        _SectionLabel(
          title: l10n.t('search.surahMatches'),
          count: surahs.length,
        ),
        for (final surah in surahs)
          _SurahResultTile(surah: surah, query: query),
        const SizedBox(height: ZadSpacing.md),
      ],
      if (verses.isNotEmpty) ...<Widget>[
        _SectionLabel(
          title: l10n.t('search.ayahMatches'),
          count: verses.length,
        ),
        for (final match in verses)
          _AyahResultTile(surah: match.$1, verse: match.$2, query: query),
      ],
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZadSpacing.md,
        ZadSpacing.sm,
        ZadSpacing.md,
        ZadSpacing.xl,
      ),
      // Swiping the results puts the keyboard away.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: items,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
      child: SectionHeader(
        title: title,
        subtitle: l10n.t(
          'search.resultsCount',
          args: <String, Object?>{'n': l10n.n(count)},
        ),
      ),
    );
  }
}

class _SurahResultTile extends StatelessWidget {
  const _SurahResultTile({required this.surah, required this.query});

  final Surah surah;
  final String query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ZadCard(
        padding: const EdgeInsets.symmetric(
          horizontal: ZadSpacing.md,
          vertical: ZadSpacing.sm,
        ),
        onTap: () => QuranNavigation.openReader(
          context,
          surah: surah.number,
          ayah: 1,
        ),
        child: Row(
          children: <Widget>[
            OctagonBadge(label: l10n.n(surah.number), size: 34),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${l10n.t('quran.surahPrefix')} ${surah.arabicName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: zadText(
                      size: 16,
                      weight: 600,
                      family: ZadFonts.classical,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    '${l10n.t('quran.ayahCount', args: {'n': l10n.n(surah.ayahCount)})} • '
                    '${l10n.t('quran.pageShort', args: {'n': l10n.n(surah.startPage)})}',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_back_rounded,
              size: 17,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _AyahResultTile extends StatelessWidget {
  const _AyahResultTile({
    required this.surah,
    required this.verse,
    required this.query,
  });

  final Surah surah;
  final QuranVerse verse;
  final String query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ZadCard(
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
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: quranVerseStyle(
                color: scheme.onSurface,
                size: 19,
                height: 1.9,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Icon(
                  Icons.menu_book_outlined,
                  size: 14,
                  color: tokens.gold,
                ),
                const SizedBox(width: 5),
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
      ),
    );
  }
}
