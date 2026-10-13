import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/quran_models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/quran_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_app_bar.dart';
import 'quran_reader_screen.dart';

/// Every ayah the reader has saved, with the Mushaf page and juz for context.
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quran = context.watch<QuranController>();

    return Scaffold(
      appBar: ZadAppBar(
        title: l10n.t('quran.bookmarks'),
        showLogo: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_forward_rounded),
          tooltip: l10n.t('common.close'),
        ),
        actions: <Widget>[
          if (quran.bookmarks.isNotEmpty)
            ZadIconButton(
              icon: Icons.delete_sweep_outlined,
              tooltip: l10n.t('common.clear'),
              onPressed: () async {
                final confirmed = await showZadConfirm(
                  context,
                  title: l10n.t('common.clear'),
                  body: l10n.t('quran.noBookmarksBody'),
                  destructive: true,
                );
                if (!confirmed || !context.mounted) return;
                await quran.clearBookmarks();
                if (!context.mounted) return;
                showZadSnack(context, l10n.t('quran.bookmarkRemoved'));
              },
            ),
        ],
      ),
      body: quran.bookmarks.isEmpty
          ? EmptyView(
              icon: Icons.bookmark_border_rounded,
              title: l10n.t('quran.noBookmarks'),
              body: l10n.t('quran.noBookmarksBody'),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                ZadSpacing.md,
                ZadSpacing.md,
                ZadSpacing.md,
                ZadSpacing.xl,
              ),
              itemCount: quran.bookmarks.length,
              separatorBuilder: (_, _) => const SizedBox(height: ZadSpacing.sm),
              itemBuilder: (context, index) {
                final bookmark = quran.bookmarks[index];
                return _BookmarkTile(
                  bookmark: bookmark,
                  onOpen: () => _open(context, bookmark),
                  onDelete: () => quran.removeBookmark(bookmark),
                );
              },
            ),
    );
  }

  Future<void> _open(BuildContext context, QuranBookmark bookmark) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuranReaderScreen(
          surahNumber: bookmark.surah,
          ayahNumber: bookmark.ayah,
        ),
      ),
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  const _BookmarkTile({
    required this.bookmark,
    required this.onOpen,
    required this.onDelete,
  });

  final QuranBookmark bookmark;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quran = context.read<QuranController>();
    final surah = quran.data?.surah(bookmark.surah);
    final verse = surah?.verse(bookmark.ayah);
    final name = surah == null
        ? ''
        : (l10n.isArabic ? surah.arabicName : surah.englishName);

    return ZadCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(ZadSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.bookmark_rounded,
                size: 17,
                color: context.tokens.gold,
              ),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: Text(
                  '${l10n.t('quran.surahPrefix')} $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              ZadBadge(
                label: l10n.t(
                  'quran.ayahCount',
                  args: <String, Object?>{'n': l10n.n(bookmark.ayah)},
                ),
                icon: Icons.tag,
              ),
              IconButton(
                onPressed: onDelete,
                iconSize: 18,
                tooltip: l10n.t('quran.removeBookmark'),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          if (verse != null) ...<Widget>[
            const SizedBox(height: ZadSpacing.sm),
            Text(
              verse.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
              style: quranVerseStyle(
                color: Theme.of(context).colorScheme.onSurface,
                size: 18,
                height: 1.9,
              ),
            ),
          ],
          const SizedBox(height: ZadSpacing.sm),
          Row(
            children: <Widget>[
              ZadBadge(
                label: l10n.t(
                  'quran.juzShort',
                  args: <String, Object?>{'n': l10n.n(bookmark.juz)},
                ),
                icon: Icons.layers_outlined,
              ),
              const SizedBox(width: ZadSpacing.sm),
              ZadBadge(
                label: l10n.t(
                  'quran.pageShort',
                  args: <String, Object?>{'n': l10n.n(bookmark.page)},
                ),
                icon: Icons.menu_book_outlined,
              ),
              const Spacer(),
              Text(
                l10n.t('home.continueReading'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Icon(
                Icons.arrow_back_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
