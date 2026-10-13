import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/quran_models.dart';
import '../../data/models/settings_models.dart';
import '../../data/repositories/mushaf_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../state/quran_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_app_bar.dart';
import 'quran_reader_screen.dart';

/// Night treatment for a Mushaf page.
///
/// The page is white paper with black ink. Inverting it maps 255 → 0 and
/// 0 → 255, which is what a night reader wants, but a plain inversion turns the
/// black ink into glaring pure white. Scaling by 0.92 and shifting by 234.6
/// instead maps white paper to exactly 0 — a true black page, so an OLED panel
/// draws no light at all — and black ink to 235, a soft off-white. The gold
/// rules of the illuminated pages invert along with everything else and read as
/// a muted blue-grey, which is the one visible cost of the treatment.
const List<double> _nightMatrix = <double>[
  -0.92, 0, 0, 0, 234.6, //
  0, -0.92, 0, 0, 234.6, //
  0, 0, -0.92, 0, 234.6, //
  0, 0, 0, 1, 0, //
];

/// Keeps the page as printed and drops the paper to about 60% brightness, so it
/// reads as a dimmed sheet rather than as a light source. Less aggressive than
/// the night treatment, and the one to pick if inverted ink feels wrong.
const List<double> _dimMatrix = <double>[
  0.6, 0, 0, 0, 0, //
  0, 0.6, 0, 0, 0, //
  0, 0, 0.6, 0, 0, //
  0, 0, 0, 1, 0, //
];

ColorFilter? _filterFor(MushafPageTreatment treatment) => switch (treatment) {
  MushafPageTreatment.asPrinted => null,
  MushafPageTreatment.dim => const ColorFilter.matrix(_dimMatrix),
  // `auto` is resolved before this is called, so it can never arrive here.
  MushafPageTreatment.invert ||
  MushafPageTreatment.auto => const ColorFilter.matrix(_nightMatrix),
};

/// The authentic Madinah Mushaf reader.
///
/// Every page shown here is a real scan of the printed 604-page Madinah Mushaf
/// (Hafs 'an Asim, 15 lines per page) fetched from a public CDN mirror and
/// cached on the device. The app never fabricates or re-simulates a Mushaf page
/// with ordinary Arabic text.
class MushafReaderScreen extends StatefulWidget {
  const MushafReaderScreen({super.key, required this.page});

  final int page;

  @override
  State<MushafReaderScreen> createState() => _MushafReaderScreenState();
}

class _MushafReaderScreenState extends State<MushafReaderScreen> {
  static const int _totalPages = MushafRepository.totalPages;

  late final PageController _controller = PageController(
    initialPage: widget.page.clamp(1, _totalPages) - 1,
  );

  late int _page = widget.page.clamp(1, _totalPages);

  /// Immersive reading: the bottom dock can be hidden with a centre tap.
  bool _chrome = true;

  /// Pinch-zoom is opt-in so that horizontal swiping keeps working.
  bool _zoom = false;

  int _downloaded = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _persistPosition(_page);
      _refreshDownloaded();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  QuranController get _quran => context.read<QuranController>();

  MushafRepository get _repo => context.read<MushafRepository>();

  QuranData? get _data => _quran.data;

  (Surah, QuranVerse)? get _firstVerse => _quran.firstVerseOfPage(_page);

  int get _currentSurahNumber =>
      _firstVerse?.$1.number ?? _data?.surahForPage(_page).number ?? 1;

  int get _currentAyah => _firstVerse?.$2.numberInSurah ?? 1;

  int get _currentJuz => _data?.juzForPage(_page) ?? 1;

  Surah? get _currentSurah =>
      _firstVerse?.$1 ?? _data?.surahForPage(_page);

  String _surahLabel(AppLocalizations l10n) {
    final surah = _currentSurah;
    if (surah == null) return '';
    return l10n.isArabic ? surah.arabicName : surah.englishName;
  }

  // ------------------------------------------------------------ position ---

  /// Records the reading position in the same store the text reader uses, so
  /// switching display modes never loses the user's place.
  Future<void> _persistPosition(int page) async {
    final data = _data;
    if (data == null) return;
    final first = _quran.firstVerseOfPage(page);
    await _quran.savePosition(
      surah: first?.$1.number ?? data.surahForPage(page).number,
      ayah: first?.$2.numberInSurah ?? 1,
      page: page,
      juz: data.juzForPage(page),
      mode: QuranDisplayMode.mushaf,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _page = index + 1);
    _persistPosition(_page);
  }

  void _goToPage(int page) {
    final target = page.clamp(1, _totalPages);
    if (target == _page) return;
    _controller.animateToPage(
      target - 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _step(int delta) => _goToPage(_page + delta);

  // ------------------------------------------------------------ bookmark ---

  Future<void> _toggleBookmark() async {
    final l10n = context.l10n;
    final surah = _currentSurahNumber;
    final ayah = _currentAyah;
    final wasBookmarked = _quran.isBookmarked(surah, ayah);
    await _quran.toggleBookmark(
      surah: surah,
      ayah: ayah,
      page: _page,
      juz: _currentJuz,
    );
    if (!mounted) return;
    showZadSnack(
      context,
      l10n.t(
        wasBookmarked ? 'quran.bookmarkRemoved' : 'quran.bookmarkAdded',
      ),
    );
  }

  // --------------------------------------------------------------- cache ---

  Future<void> _refreshDownloaded() async {
    final count = await _repo.downloadedCount();
    if (!mounted) return;
    setState(() => _downloaded = count);
  }

  Future<void> _downloadAll() async {
    final l10n = context.l10n;
    final confirmed = await showZadConfirm(
      context,
      title: l10n.t('quran.downloadAll'),
      body: l10n.t('quran.downloadAllBody'),
      confirmLabel: l10n.t('common.apply'),
    );
    if (!confirmed || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DownloadDialog(repository: _repo),
    );
    await _refreshDownloaded();
  }

  Future<void> _clearCache() async {
    final l10n = context.l10n;
    final confirmed = await showZadConfirm(
      context,
      title: l10n.t('quran.clearCache'),
      body: l10n.t('quran.cacheCleared'),
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _repo.clearCache();
    await _refreshDownloaded();
    if (!mounted) return;
    showZadSnack(context, l10n.t('quran.cacheCleared'));
  }

  Future<void> _showSourceInfo() async {
    final l10n = context.l10n;
    await _refreshDownloaded();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('quran.mushafSource')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.t('quran.edition')),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              l10n.t('quran.riwayah'),
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              MushafRepository.primarySourceLabel,
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            Text(
              MushafRepository.primarySourceUrl,
              style: Theme.of(dialogContext).textTheme.labelSmall,
            ),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              MushafRepository.fallbackSourceLabel,
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            Text(
              MushafRepository.fallbackSourceUrl,
              style: Theme.of(dialogContext).textTheme.labelSmall,
            ),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              l10n.t(
                'quran.downloadedCount',
                args: <String, Object?>{'n': l10n.n(_downloaded)},
              ),
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
          ],
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.t('common.close')),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- appearance ---

  /// Lets the reader choose how the page photograph is rendered.
  ///
  /// The page stays visible behind the sheet, so each option can be judged
  /// against the real text rather than described — which is the only way to
  /// decide whether inverted ink reads well for you.
  Future<void> _showAppearancePicker() async {
    final l10n = context.l10n;
    final controller = context.read<SettingsController>();
    final current = controller.settings.mushafPageTreatment;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selected = await showModalBottomSheet<MushafPageTreatment>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZadSpacing.md,
                ZadSpacing.md,
                ZadSpacing.md,
                ZadSpacing.xs,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.t('quran.pageAppearance'),
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
            ),
            for (final option in MushafPageTreatment.values)
              ListTile(
                leading: Icon(
                  option == current
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: option == current
                      ? context.tokens.gold
                      : Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
                title: Text(l10n.t(option.labelKey)),
                subtitle: option == MushafPageTreatment.auto
                    ? Text(
                        l10n.t(
                          isDark
                              ? 'quran.treatment.invert'
                              : 'quran.treatment.asPrinted',
                        ),
                        style: Theme.of(sheetContext).textTheme.labelSmall,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
            const SizedBox(height: ZadSpacing.sm),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;
    await controller.setMushafPageTreatment(selected);
  }

  // ----------------------------------------------------------- navigation ---

  Future<void> _showNavigator() async {
    final l10n = context.l10n;
    final data = _data;
    if (data == null) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DefaultTabController(
        length: 3,
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.72,
          child: Column(
            children: <Widget>[
              const SizedBox(height: ZadSpacing.sm),
              TabBar(
                tabs: <Widget>[
                  Tab(text: l10n.t('quran.pages')),
                  Tab(text: l10n.t('quran.surahs')),
                  Tab(text: l10n.t('quran.juz')),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    _PageTab(
                      current: _page,
                      totalPages: _totalPages,
                      data: data,
                    ),
                    _SurahTab(current: _currentSurahNumber, data: data),
                    _JuzTab(current: _currentJuz, data: data),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    _goToPage(selected);
  }

  Future<void> _switchToTextMode() async {
    final surah = _currentSurahNumber;
    final ayah = _currentAyah;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => QuranReaderScreen(
          surahNumber: surah,
          ayahNumber: ayah,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final bookmarked = _quran.isBookmarked(_currentSurahNumber, _currentAyah);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ZadAppBar(
        title: _surahLabel(l10n).isEmpty
            ? l10n.t('quran.mushaf')
            : _surahLabel(l10n),
        subtitle:
            '${l10n.t('quran.juzHeader', args: <String, Object?>{'juz': l10n.n(_currentJuz)})}'
            ' • '
            '${l10n.t('quran.pageShort', args: <String, Object?>{'n': l10n.n(_page)})}',
        showLogo: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_forward_rounded),
          tooltip: l10n.t('common.close'),
        ),
        actions: <Widget>[
          ZadIconButton(
            icon: _zoom ? Icons.zoom_out_map : Icons.zoom_in_map,
            tooltip: l10n.t('quran.fontSize'),
            onPressed: () => setState(() => _zoom = !_zoom),
          ),
          ZadIconButton(
            icon: bookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            tooltip: l10n.t(
              bookmarked ? 'quran.removeBookmark' : 'quran.addBookmark',
            ),
            onPressed: _toggleBookmark,
          ),
          PopupMenuButton<_MushafAction>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: l10n.t('nav.more'),
            onSelected: (action) {
              switch (action) {
                case _MushafAction.navigate:
                  _showNavigator();
                case _MushafAction.textMode:
                  _switchToTextMode();
                case _MushafAction.appearance:
                  _showAppearancePicker();
                case _MushafAction.download:
                  _downloadAll();
                case _MushafAction.clearCache:
                  _clearCache();
                case _MushafAction.source:
                  _showSourceInfo();
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<_MushafAction>>[
              PopupMenuItem<_MushafAction>(
                value: _MushafAction.navigate,
                child: _MenuRow(
                  icon: Icons.explore_outlined,
                  label: l10n.t('quran.goTo'),
                ),
              ),
              PopupMenuItem<_MushafAction>(
                value: _MushafAction.textMode,
                child: _MenuRow(
                  icon: Icons.article_outlined,
                  label: l10n.t('quran.textMode'),
                ),
              ),
              PopupMenuItem<_MushafAction>(
                value: _MushafAction.appearance,
                child: _MenuRow(
                  icon: Icons.contrast_rounded,
                  label: l10n.t('quran.pageAppearance'),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<_MushafAction>(
                value: _MushafAction.download,
                child: _MenuRow(
                  icon: Icons.download_outlined,
                  label: l10n.t('quran.downloadAll'),
                ),
              ),
              PopupMenuItem<_MushafAction>(
                value: _MushafAction.clearCache,
                child: _MenuRow(
                  icon: Icons.delete_outline,
                  label: l10n.t('quran.clearCache'),
                ),
              ),
              PopupMenuItem<_MushafAction>(
                value: _MushafAction.source,
                child: _MenuRow(
                  icon: Icons.verified_outlined,
                  label: l10n.t('quran.mushafSource'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: PageView.builder(
              controller: _controller,
              itemCount: _totalPages,
              physics: _zoom
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final page = index + 1;
                return _MushafPageView(
                  key: ValueKey<int>(page),
                  page: page,
                  repository: _repo,
                  zoom: _zoom,
                  onPrevious: () => _step(-1),
                  onNext: () => _step(1),
                  onCentreTap: () => setState(() => _chrome = !_chrome),
                );
              },
            ),
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: AnimatedSlide(
              offset: _chrome ? Offset.zero : const Offset(0, 1.35),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _MushafBottomBar(
                page: _page,
                totalPages: _totalPages,
                title: _surahLabel(l10n),
                subtitle: l10n.t(
                  'quran.pageIndicator',
                  args: <String, Object?>{'page': l10n.n(_page)},
                ),
                onPrevious: () => _step(-1),
                onNext: () => _step(1),
                onSeek: _goToPage,
                onOpenNavigator: _showNavigator,
                accent: tokens.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MushafAction { navigate, textMode, appearance, download, clearCache, source }

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: ZadSpacing.sm + 2),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// One Mushaf page, loaded from the on-device cache or downloaded on demand.
class _MushafPageView extends StatefulWidget {
  const _MushafPageView({
    super.key,
    required this.page,
    required this.repository,
    required this.zoom,
    required this.onPrevious,
    required this.onNext,
    required this.onCentreTap,
  });

  final int page;
  final MushafRepository repository;
  final bool zoom;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCentreTap;

  @override
  State<_MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends State<_MushafPageView> {
  late Future<File> _future = widget.repository.ensurePage(widget.page);

  @override
  void didUpdateWidget(covariant _MushafPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) {
      _future = widget.repository.ensurePage(widget.page);
    }
  }

  void _retry() {
    setState(() {
      _future = widget.repository.ensurePage(widget.page, forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.surfaceContainerLow,
      child: FutureBuilder<File>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return LoadingView(message: l10n.t('quran.mushafLoading'));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return ErrorView(
              title: l10n.t('quran.mushafError'),
              body: l10n.t('quran.mushafErrorBody'),
              onRetry: _retry,
            );
          }
          final file = snapshot.data!;
          final treatment = context
              .watch<SettingsController>()
              .settings
              .mushafPageTreatment
              .resolve(isDark: Theme.of(context).brightness == Brightness.dark);
          Widget image = Padding(
            padding: const EdgeInsets.all(6),
            child: Image.file(
              file,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (context, error, stack) => ErrorView(
                title: l10n.t('quran.mushafError'),
                body: l10n.t('quran.mushafErrorBody'),
                onRetry: _retry,
              ),
            ),
          );
          // The filter wraps the image, not the gesture layer, so taps, swipes
          // and pinch-zoom keep working exactly as before.
          final filter = _filterFor(treatment);
          if (filter != null) {
            image = ColorFiltered(colorFilter: filter, child: image);
          }

          if (widget.zoom) {
            return InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: image,
            );
          }

          final rtl = Directionality.of(context) == TextDirection.rtl;
          return LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final third = constraints.maxWidth / 3;
                  final dx = details.localPosition.dx;
                  if (dx < third) {
                    // Leading edge in the reading direction.
                    rtl ? widget.onNext() : widget.onPrevious();
                  } else if (dx > third * 2) {
                    rtl ? widget.onPrevious() : widget.onNext();
                  } else {
                    widget.onCentreTap();
                  }
                },
                child: image,
              );
            },
          );
        },
      ),
    );
  }
}

/// Bottom dock: page scrubber plus previous / next navigation.
class _MushafBottomBar extends StatelessWidget {
  const _MushafBottomBar({
    required this.page,
    required this.totalPages,
    required this.title,
    required this.subtitle,
    required this.onPrevious,
    required this.onNext,
    required this.onSeek,
    required this.onOpenNavigator,
    required this.accent,
  });

  final int page;
  final int totalPages;
  final String title;
  final String subtitle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onSeek;
  final VoidCallback onOpenNavigator;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Material(
      color: tokens.navigationFill,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: tokens.cardBorder),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ZadSpacing.md,
              2,
              ZadSpacing.md,
              ZadSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    activeTrackColor: accent,
                    thumbColor: accent,
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6.5,
                    ),
                  ),
                  child: Slider(
                    value: page.toDouble(),
                    min: 1,
                    max: totalPages.toDouble(),
                    onChanged: (value) => onSeek(value.round()),
                  ),
                ),
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: onPrevious,
                      tooltip: null,
                      icon: Icon(
                        rtl
                            ? Icons.chevron_right_rounded
                            : Icons.chevron_left_rounded,
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: onOpenNavigator,
                        borderRadius: BorderRadius.circular(ZadRadius.md),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: ZadSpacing.sm,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: zadText(
                                  size: 14,
                                  weight: 600,
                                  family: ZadFonts.arabicUi,
                                  color: scheme.onSurface,
                                ),
                              ),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onNext,
                      tooltip: null,
                      icon: Icon(
                        rtl
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Progress dialog for the offline Mushaf download.
class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.repository});

  final MushafRepository repository;

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  int _done = 0;
  int _failures = 0;
  bool _finished = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  Future<void> _run() async {
    final failures = await widget.repository.downloadAll(
      onProgress: (done, _) {
        if (!mounted) return;
        setState(() => _done = done);
      },
      shouldCancel: () => _cancelled || !mounted,
    );
    if (!mounted) return;
    setState(() {
      _failures = failures;
      _finished = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ratio = _done / MushafRepository.totalPages;

    return AlertDialog(
      title: Text(l10n.t('quran.downloadAll')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(ZadRadius.full),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          Text(
            l10n.t(
              'quran.downloading',
              args: <String, Object?>{
                'done': l10n.n(_done),
                'total': l10n.n(MushafRepository.totalPages),
              },
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_finished && _failures > 0) ...<Widget>[
            const SizedBox(height: ZadSpacing.sm),
            Text(
              l10n.t('quran.mushafErrorBody'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        if (!_finished)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.t('common.cancel')),
          )
        else
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.t('common.done')),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- pickers ---

class _PageTab extends StatelessWidget {
  const _PageTab({
    required this.current,
    required this.totalPages,
    required this.data,
  });

  final int current;
  final int totalPages;
  final QuranData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GridView.builder(
      padding: const EdgeInsets.all(ZadSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: ZadSpacing.sm,
        mainAxisSpacing: ZadSpacing.sm,
        childAspectRatio: 0.85,
      ),
      itemCount: totalPages,
      itemBuilder: (context, index) {
        final page = index + 1;
        final surah = data.surahForPage(page);
        final isJuzStart = data.meta.juzStartPage.containsValue(page);
        final isCurrent = page == current;
        return InkWell(
          onTap: () => Navigator.of(context).pop(page),
          borderRadius: BorderRadius.circular(ZadRadius.md),
          child: Container(
            decoration: BoxDecoration(
              color: isCurrent
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              borderRadius: BorderRadius.circular(ZadRadius.md),
              border: Border.all(
                color: isCurrent
                    ? Colors.transparent
                    : context.tokens.cardBorder,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  l10n.n(page),
                  style: zadText(
                    size: 15,
                    weight: isCurrent ? 700 : 500,
                    family: ZadFonts.arabicUi,
                    color: isCurrent
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isJuzStart
                      ? l10n.t(
                          'quran.juzShort',
                          args: <String, Object?>{'n': l10n.n(surah.startJuz)},
                        )
                      : surah.arabicName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SurahTab extends StatelessWidget {
  const _SurahTab({required this.current, required this.data});

  final int current;
  final QuranData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: ZadSpacing.sm),
      itemCount: data.surahs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final surah = data.surahs[index];
        return ListTile(
          leading: SizedBox(
            width: 34,
            child: Text(
              l10n.n(surah.number),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          title: Text(
            l10n.isArabic ? surah.arabicName : surah.englishName,
            style: zadText(
              size: 16,
              weight: 600,
              family: ZadFonts.arabicUi,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            '${l10n.t('quran.ayahCount', args: <String, Object?>{'n': l10n.n(surah.ayahCount)})}'
            ' • '
            '${l10n.t('quran.pageShort', args: <String, Object?>{'n': l10n.n(surah.startPage)})}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          selected: surah.number == current,
          onTap: () => Navigator.of(context).pop(surah.startPage),
        );
      },
    );
  }
}

class _JuzTab extends StatelessWidget {
  const _JuzTab({required this.current, required this.data});

  final int current;
  final QuranData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: ZadSpacing.sm),
      itemCount: 30,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final juz = index + 1;
        final start = data.meta.juzStartPage[juz] ?? 1;
        final surah = data.surahForPage(start);
        return ListTile(
          leading: Icon(
            Icons.bookmarks_outlined,
            size: 20,
            color: context.tokens.gold,
          ),
          title: Text(l10n.t('quran.juzShort', args: <String, Object?>{'n': l10n.n(juz)})),
          subtitle: Text(
            '${surah.arabicName} • ${l10n.t('quran.pageShort', args: <String, Object?>{'n': l10n.n(start)})}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          selected: juz == current,
          onTap: () => Navigator.of(context).pop(start),
        );
      },
    );
  }
}
