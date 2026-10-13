import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/quran_models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/quran_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_app_bar.dart';
import '../../widgets/zad_logo.dart';
import 'mushaf_reader_screen.dart';
import 'quran_audio.dart';

/// The existing text-reading interface, preserved and extended.
///
/// Verses flow continuously in the classical script with ornate ayah markers,
/// and each ayah is individually tappable for bookmarking, copying and sharing.
/// Switching to the Mushaf mode is a first-class action in the app bar.
class QuranReaderScreen extends StatefulWidget {
  const QuranReaderScreen({
    super.key,
    required this.surahNumber,
    this.ayahNumber = 1,
  });

  final int surahNumber;
  final int ayahNumber;

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  final ScrollController _scroll = ScrollController();
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  late int _surahNumber = widget.surahNumber;
  int? _highlightedAyah;
  bool _jumpApplied = false;

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quran = context.watch<QuranController>();
    final settings = context.watch<SettingsController>();
    final data = quran.data;

    if (data == null) {
      return Scaffold(
        appBar: ZadAppBar(title: l10n.t('quran.title'), showLogo: false),
        body: LoadingView(message: l10n.t('common.loading')),
      );
    }

    final surah = data.surah(_surahNumber);
    final scale = settings.settings.quranFontScale;
    final baseSize = 26 * scale;

    return Scaffold(
      appBar: ZadAppBar(
        title: '${l10n.t('quran.surahPrefix')} ${surah.arabicName}',
        subtitle: '${l10n.t('quran.juzShort', args: {'n': l10n.n(surah.startJuz)})} • '
            '${l10n.t('quran.pageShort', args: {'n': l10n.n(surah.startPage)})} • '
            '${l10n.t('quran.riwayah')}',
        showLogo: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: <Widget>[
          ZadIconButton(
            icon: Icons.auto_stories_outlined,
            tooltip: l10n.t('quran.mushafMode'),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => MushafReaderScreen(page: surah.startPage),
              ),
            ),
          ),
          ZadIconButton(
            icon: Icons.text_fields_rounded,
            tooltip: l10n.t('quran.fontSize'),
            onPressed: () => _showFontSheet(context, settings),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              // No top gap: the app bar already ends the header, and every
              // pixel here is reading space.
              padding: const EdgeInsets.fromLTRB(
                ZadSpacing.md,
                0,
                ZadSpacing.md,
                ZadSpacing.md,
              ),
              child: ZadCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZadSpacing.md,
                  vertical: ZadSpacing.sm,
                ),
                child: Column(
                  children: <Widget>[
                    _SurahHeader(surah: surah),
                    const SizedBox(height: ZadSpacing.sm),
                    if (surah.hasBismillah && surah.number != 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
                        child: Text(
                          l10n.t('quran.bismillah'),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: quranVerseStyle(
                            color: Theme.of(context).colorScheme.primary,
                            size: baseSize * 0.92,
                            height: 1.9,
                          ),
                        ),
                      ),
                    _buildSurahText(
                      context: context,
                      l10n: l10n,
                      quran: quran,
                      surah: surah,
                      fontSize: baseSize,
                    ),
                  ],
                ),
              ),
            ),
          ),
          RecitationBar(
            surahNumber: surah.number,
            surahLabel: surah.arabicName,
          ),
          _ReaderBottomBar(
            surah: surah,
            onPrevious: surah.number > 1
                ? () => _switchSurah(surah.number - 1)
                : null,
            onNext: surah.number < 114
                ? () => _switchSurah(surah.number + 1)
                : null,
            onSelectSurah: () => _showSurahPicker(context, quran),
            onJumpToAyah: () => _showAyahPicker(context, surah),
          ),
        ],
      ),
    );
  }

  /// Builds the continuous mushaf-style flow with ornate ayah markers.
  Widget _buildSurahText({
    required BuildContext context,
    required AppLocalizations l10n,
    required QuranController quran,
    required Surah surah,
    required double fontSize,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final spans = <InlineSpan>[];
    for (final verse in surah.verses) {
      final isTarget = verse.numberInSurah == _highlightedAyah;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _onAyahTapped(surah, verse);
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: '${verse.text} ',
          recognizer: recognizer,
          style: isTarget
              ? quranVerseStyle(
                  color: scheme.onSurface,
                  size: fontSize,
                  height: 2.1,
                ).copyWith(
                  backgroundColor: tokens.gold.withValues(alpha: 0.22),
                )
              : null,
        ),
      );
      spans.add(
        TextSpan(
          text: '﴿${_arabicDigits(verse.numberInSurah, l10n)}﴾ ',
          recognizer: recognizer,
          style: zadText(
            size: fontSize * 0.78,
            weight: 600,
            family: ZadFonts.classical,
            color: tokens.gold,
          ),
        ),
      );
    }

    final baseStyle = quranVerseStyle(
      color: scheme.onSurface,
      size: fontSize,
      height: 2.1,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text.rich(
        TextSpan(style: baseStyle, children: spans),
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
      ),
    );
  }

  void _onAyahTapped(Surah surah, QuranVerse verse) {
    setState(() => _highlightedAyah = verse.numberInSurah);
    final quran = context.read<QuranController>();
    quran.savePosition(
      surah: surah.number,
      ayah: verse.numberInSurah,
      page: verse.page,
      juz: verse.juz,
      mode: QuranDisplayMode.text,
    );
    _showAyahActions(context, surah, verse);
  }

  void _switchSurah(int number) {
    setState(() {
      _surahNumber = number;
      _highlightedAyah = 1;
      _jumpApplied = true;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _showAyahActions(
    BuildContext context,
    Surah surah,
    QuranVerse verse,
  ) async {
    final l10n = AppLocalizations.of(context);
    final quran = context.read<QuranController>();
    final bookmarked = quran.isBookmarked(surah.number, verse.numberInSurah);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.md,
            0,
            ZadSpacing.md,
            ZadSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '${l10n.t('quran.surahPrefix')} ${surah.arabicName} • '
                '${l10n.t('quran.ayah')} ${l10n.n(verse.numberInSurah)}',
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.titleSmall,
              ),
              const SizedBox(height: ZadSpacing.md),
              Text(
                verse.text,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: quranVerseStyle(
                  color: Theme.of(sheetContext).colorScheme.onSurface,
                  size: 20,
                ),
              ),
              const SizedBox(height: ZadSpacing.md),
              const ZadDivider(),
              const SizedBox(height: ZadSpacing.sm),
              _SheetAction(
                icon: bookmarked
                    ? Icons.bookmark_remove_outlined
                    : Icons.bookmark_add_outlined,
                label: bookmarked
                    ? l10n.t('quran.removeBookmark')
                    : l10n.t('quran.addBookmark'),
                onTap: () async {
                  await quran.toggleBookmark(
                    surah: surah.number,
                    ayah: verse.numberInSurah,
                    page: verse.page,
                    juz: verse.juz,
                  );
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                    showZadSnack(
                      context,
                      bookmarked
                          ? l10n.t('quran.bookmarkRemoved')
                          : l10n.t('quran.bookmarkAdded'),
                    );
                  }
                },
              ),
              _SheetAction(
                icon: Icons.copy_rounded,
                label: l10n.t('quran.copy'),
                onTap: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: '${verse.text}\n'
                          '${l10n.t('quran.surahPrefix')} ${surah.arabicName} — '
                          '${l10n.t('quran.ayah')} ${verse.numberInSurah}',
                    ),
                  );
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                    showZadSnack(context, l10n.t('quran.copied'));
                  }
                },
              ),
              _SheetAction(
                icon: Icons.share_outlined,
                label: l10n.t('quran.share'),
                onTap: () async {
                  await Share.share(
                    '${verse.text}\n'
                    '${l10n.t('quran.surahPrefix')} ${surah.arabicName} — '
                    '${l10n.t('quran.ayah')} ${verse.numberInSurah}\n'
                    '${l10n.t('app.name')}',
                  );
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
              ),
              _SheetAction(
                icon: Icons.auto_stories_outlined,
                label: '${l10n.t('quran.mushafMode')} • '
                    '${l10n.t('quran.pageShort', args: {'n': l10n.n(verse.page)})}',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MushafReaderScreen(page: verse.page),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFontSheet(
    BuildContext context,
    SettingsController settings,
  ) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.md,
            0,
            ZadSpacing.md,
            ZadSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.t('quran.fontSize'),
                style: Theme.of(sheetContext).textTheme.titleSmall,
              ),
              const SizedBox(height: ZadSpacing.sm),
              StatefulBuilder(
                builder: (context, setSheetState) => Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () async {
                        await settings.setQuranFontScale(
                          settings.settings.quranFontScale - 0.1,
                        );
                        setSheetState(() {});
                      },
                      icon: const Icon(Icons.text_decrease_rounded),
                    ),
                    Expanded(
                      child: Slider(
                        value: settings.settings.quranFontScale,
                        min: 0.8,
                        max: 1.8,
                        divisions: 10,
                        label: settings.settings.quranFontScale
                            .toStringAsFixed(1),
                        onChanged: (value) async {
                          await settings.setQuranFontScale(value);
                          setSheetState(() {});
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await settings.setQuranFontScale(
                          settings.settings.quranFontScale + 0.1,
                        );
                        setSheetState(() {});
                      },
                      icon: const Icon(Icons.text_increase_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSurahPicker(
    BuildContext context,
    QuranController quran,
  ) async {
    final l10n = AppLocalizations.of(context);
    final data = quran.data;
    if (data == null) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.7,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.md),
              child: Text(
                l10n.t('quran.goToSurah'),
                style: Theme.of(sheetContext).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: ZadSpacing.sm),
            Expanded(
              child: ListView.builder(
                itemCount: data.surahs.length,
                itemBuilder: (context, index) {
                  final surah = data.surahs[index];
                  return ListTile(
                    leading: OctagonBadge(label: l10n.n(surah.number), size: 32),
                    title: Text('${l10n.t('quran.surahPrefix')} ${surah.arabicName}'),
                    subtitle: Text(
                      l10n.t('quran.ayahCount', args: {'n': l10n.n(surah.ayahCount)}),
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(surah.number),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null) _switchSurah(selected);
  }

  Future<void> _showAyahPicker(BuildContext context, Surah surah) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: '1');
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('quran.jumpToAyah')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.t('quran.ayahNumber'),
            helperText: l10n.t('quran.invalidAyah', args: {
              'max': l10n.n(surah.ayahCount),
            }),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 1 || value > surah.ayahCount) return;
              Navigator.of(dialogContext).pop(value);
            },
            child: Text(l10n.t('common.go')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      if (!context.mounted) return;
      setState(() => _highlightedAyah = result);
      final verse = surah.verse(result);
      final quran = context.read<QuranController>();
      await quran.savePosition(
        surah: surah.number,
        ayah: result,
        page: verse.page,
        juz: verse.juz,
        mode: QuranDisplayMode.text,
      );
    }
  }

  static String _arabicDigits(int value, AppLocalizations l10n) =>
      l10n.n(value);

  @override
  void initState() {
    super.initState();
    _highlightedAyah = widget.ayahNumber;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_jumpApplied) return;
      _jumpApplied = true;
      final quran = context.read<QuranController>();
      final data = quran.data;
      if (data == null) return;
      final surah = data.surah(_surahNumber);
      final verse = surah.verse(widget.ayahNumber);
      quran.savePosition(
        surah: surah.number,
        ayah: verse.numberInSurah,
        page: verse.page,
        juz: verse.juz,
        mode: QuranDisplayMode.text,
      );
    });
  }
}

/// Ornamental surah title inside the reading surface.
///
/// Deliberately slim: the juz and page numbers used to be repeated here as
/// octagon badges even though the app bar subtitle already shows both, so they
/// are gone and the surah's fully vocalised name — which the app bar does *not*
/// show — is all that remains.
class _SurahHeader extends StatelessWidget {
  const _SurahHeader({required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ZadRadius.lg),
        border: Border.all(color: tokens.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            surah.fullName,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: zadText(
              size: 20,
              weight: 600,
              family: ZadFonts.classical,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            l10n.t('quran.ayahCount', args: {'n': l10n.n(surah.ayahCount)}),
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _ReaderBottomBar extends StatelessWidget {
  const _ReaderBottomBar({
    required this.surah,
    required this.onPrevious,
    required this.onNext,
    required this.onSelectSurah,
    required this.onJumpToAyah,
  });

  final Surah surah;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onSelectSurah;
  final VoidCallback onJumpToAyah;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return Container(
      padding: EdgeInsets.fromLTRB(
        ZadSpacing.md,
        ZadSpacing.sm,
        ZadSpacing.md,
        ZadSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: tokens.cardBorder)),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: l10n.t('azkar.previous'),
          ),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onSelectSurah,
              icon: const Icon(Icons.list_rounded, size: 17),
              label: Text(
                '${l10n.t('quran.surahPrefix')} ${surah.arabicName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
          ),
          const SizedBox(width: ZadSpacing.sm),
          IconButton(
            onPressed: onJumpToAyah,
            icon: const Icon(Icons.my_location_rounded),
            tooltip: l10n.t('quran.jumpToAyah'),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: l10n.t('azkar.next'),
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZadRadius.lg),
      ),
    );
  }
}
