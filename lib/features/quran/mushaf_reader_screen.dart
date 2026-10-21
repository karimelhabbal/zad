import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart' hide Surah;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/quran_models.dart';
import '../../data/models/settings_models.dart';
import '../../data/services/mushaf_font_service.dart';
import '../../l10n/app_localizations.dart';
import '../../state/quran_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_app_bar.dart';
import 'mushaf_about_screen.dart';
import 'quran_audio.dart';
import 'quran_reader_screen.dart';

/// The paper colour the page is drawn on.
///
/// Light mode is a warm cream, the colour of the printed Mushaf's stock; dark
/// mode is a very dark green-black rather than pure black, so the Tajweed ink
/// keeps its contrast without glowing on an OLED panel.
const Color _paperLight = Color(0xFFFBF6EE);
const Color _paperDark = Color(0xFF0C1310);

/// How far the page sits from the screen edge. The frame is drawn on this
/// boundary, so the paper shows a hairline of margin outside it.
const double _frameInset = 10;

/// The authentic Madinah Mushaf reader, drawn from QCF fonts.
///
/// Every page is rendered as text with the King Fahd Complex page font for that
/// exact page — one font per page, 604 of them — so the page is sharp at any
/// screen density, fills the screen edge to edge, and needs no page image and
/// no network request. The text is the package's Uthmani data, used as-is: this
/// reader never edits, re-orders or normalises a single character.
class MushafReaderScreen extends StatefulWidget {
  const MushafReaderScreen({super.key, required this.page});

  /// 1-based Mushaf page to open on.
  final int page;

  @override
  State<MushafReaderScreen> createState() => _MushafReaderScreenState();
}

class _MushafReaderScreenState extends State<MushafReaderScreen> {
  static const int _totalPages = MushafFontService.totalPages;

  late final int _initialPage = widget.page.clamp(1, _totalPages);

  late final PageController _controller = PageController(
    initialPage: _initialPage - 1,
  );

  late int _page = _initialPage;

  /// Page data + the font for [_initialPage]; the reader waits on this before
  /// it builds, so the first page never flashes fallback glyphs.
  late Future<void> _boot;

  /// Immersive reading: chrome (top bar + bottom dock) hides on centre tap.
  bool _chrome = true;

  /// True while a distant page's font is being loaded after a jump.
  bool _jumping = false;

  /// Live value of the page slider while the user drags it.
  double? _scrub;

  @override
  void initState() {
    super.initState();
    // Hide the status and navigation bars; a swipe from the edge brings them
    // back temporarily (immersiveSticky) without leaving the page.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // The page is laid out for portrait. In landscape the page widget switches
    // to a two-page spread, which halves the height each page gets and makes
    // the Mushaf read badly — so the reader holds the device upright and hands
    // the orientation back when it closes.
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    _boot = MushafFontService.ensurePage(_initialPage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _persistPosition(_page);
      MushafFontService.preloadAround(_page);
    });
  }

  @override
  void dispose() {
    // Hand the system bars and the orientation back to the rest of the app.
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _controller.dispose();
    super.dispose();
  }

  QuranController get _quran => context.read<QuranController>();

  QuranData? get _data => _quran.data;

  /// First verse of [_page], memoised: the lookup scans the whole dataset, and
  /// the label, juz and bookmark code all ask for it on every rebuild.
  int _cachedPage = -1;
  (Surah, QuranVerse)? _cachedFirstVerse;

  (Surah, QuranVerse)? get _firstVerse {
    if (_cachedPage != _page) {
      _cachedPage = _page;
      _cachedFirstVerse = _quran.firstVerseOfPage(_page);
    }
    return _cachedFirstVerse;
  }

  int get _currentSurahNumber =>
      _firstVerse?.$1.number ?? _data?.surahForPage(_page).number ?? 1;

  int get _currentAyah => _firstVerse?.$2.numberInSurah ?? 1;

  int get _currentJuz => _data?.juzForPage(_page) ?? 1;

  Surah? get _currentSurah => _firstVerse?.$1 ?? _data?.surahForPage(_page);

  String _surahLabel(AppLocalizations l10n) {
    final surah = _currentSurah;
    if (surah == null) return '';
    return l10n.isArabic ? surah.arabicName : surah.englishName;
  }

  // ------------------------------------------------------------ position ---

  /// Records the reading position in the same store the text reader uses, so
  /// switching display modes never loses the user's place. This is what the
  /// app reopens on next launch.
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

  void _onPageChanged(int pageNumber) {
    if (!mounted) return;
    setState(() => _page = pageNumber.clamp(1, _totalPages));
    _persistPosition(_page);
    MushafFontService.preloadAround(_page);
  }

  /// Jumps to [page], loading that page's font first when it is not ready.
  Future<void> _jumpTo(int page) async {
    final target = page.clamp(1, _totalPages);
    if (target == _page) return;
    final needsLoad = !MushafFontService.isPageReady(target);
    if (needsLoad) setState(() => _jumping = true);
    await MushafFontService.ensurePage(target);
    if (!mounted) return;
    if (needsLoad) setState(() => _jumping = false);
    if (!_controller.hasClients) return;
    _controller.jumpToPage(target - 1);
    MushafFontService.preloadAround(target);
  }

  void _step(int delta) {
    final target = (_page + delta).clamp(1, _totalPages);
    if (target == _page) return;
    // Adjacent pages are already preloaded: slide them. Anything further is a
    // jump, because animating across dozens of pages reads as a stuck screen.
    if ((target - _page).abs() <= 3 && MushafFontService.isPageReady(target)) {
      _controller.animateToPage(
        target - 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _jumpTo(target);
    }
  }

  // ------------------------------------------------------------ bookmark ---

  Future<void> _toggleBookmarkAt(int surah, int ayah) async {
    final l10n = context.l10n;
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

  Future<void> _toggleBookmark() =>
      _toggleBookmarkAt(_currentSurahNumber, _currentAyah);

  void _onAyahLongPress(int surah, int verse, LongPressStartDetails details) {
    HapticFeedback.mediumImpact();
    _toggleBookmarkAt(surah, verse);
  }

  // ------------------------------------------------------------ settings ---

  Future<void> _toggleTajweed() async {
    final controller = context.read<SettingsController>();
    await controller.setMushafTajweed(!controller.settings.mushafTajweed);
  }

  Future<void> _toggleTheme() async {
    final controller = context.read<SettingsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await controller.setThemeMode(
      isDark ? AppThemeMode.light : AppThemeMode.dark,
    );
  }

  Future<void> _openAbout() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MushafAboutScreen()),
    );
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
    await _jumpTo(selected);
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

  // -------------------------------------------------------------- gestures --

  void _handleTap(TapUpDetails details, double width) {
    if (_jumping) return;
    final third = width / 3;
    final dx = details.localPosition.dx;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    if (dx < third) {
      // Leading edge in the reading direction turns forward.
      rtl ? _step(1) : _step(-1);
    } else if (dx > third * 2) {
      rtl ? _step(-1) : _step(1);
    } else {
      setState(() => _chrome = !_chrome);
    }
  }

  /// Bookmarked ayahs on the visible page are tinted, so a saved place is
  /// visible in the page itself rather than only in a list.
  List<HighlightVerse> _highlights(
    List<QuranBookmark> bookmarks,
    Color tint,
  ) {
    if (bookmarks.isEmpty) return const <HighlightVerse>[];
    return <HighlightVerse>[
      for (final bookmark in bookmarks)
        if (bookmark.page == _page)
          HighlightVerse(
            surah: bookmark.surah,
            verseNumber: bookmark.ayah,
            page: bookmark.page,
            color: tint,
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = isDark ? _paperDark : _paperLight;
    final settings = context.watch<SettingsController>().settings;
    // Watched so a bookmark added on this page tints the ayah immediately.
    final quran = context.watch<QuranController>();
    final bookmarked = quran.isBookmarked(_currentSurahNumber, _currentAyah);

    return Scaffold(
      backgroundColor: paper,
      body: Stack(
        children: <Widget>[
          // The page sits inside the frame: `_frameInset` of paper shows
          // outside the hairline, so the line never crosses a line of text and
          // nothing is cropped — the page is laid out in the remaining box.
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(_frameInset),
                child: FutureBuilder<void>(
                  future: _boot,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return _PaperLoading(
                        paper: paper,
                        message: l10n.t('quran.mushafLoading'),
                      );
                    }
                    if (snapshot.hasError) {
                      return _PaperError(
                        paper: paper,
                        title: l10n.t('quran.mushafError'),
                        body: l10n.t('quran.mushafErrorBody'),
                        onRetry: () => setState(() {
                          _boot = MushafFontService.ensurePage(_page);
                        }),
                      );
                    }
                    return QuranPageView(
                      pageController: _controller,
                      highlights: _highlights(
                        quran.bookmarks,
                        tokens.gold.withValues(alpha: 0.22),
                      ),
                      isDarkMode: isDark,
                      isTajweed: settings.mushafTajweed,
                      // The page's own paper colour, so any sub-pixel remainder
                      // around the fitted lines is the same cream, not a panel.
                      pageBackgroundColor: paper,
                      enableTwoPageLayout: true,
                      deferNewPages: true,
                      onPageChanged: _onPageChanged,
                      onLongPress: _onAyahLongPress,
                    );
                  },
                ),
              ),
            ),
          ),

          // Tap layer: thirds turn pages, the middle toggles the chrome. It is
          // translucent, so swipes still reach the PageView underneath.
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) =>
                    _handleTap(details, constraints.maxWidth),
                child: const SizedBox.expand(),
              ),
            ),
          ),

          if (_jumping)
            Positioned.fill(
              child: ColoredBox(
                color: paper.withValues(alpha: 0.72),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),

          // Chrome — hidden by a centre tap, so the page is never obstructed.
          PositionedDirectional(
            start: 0,
            end: 0,
            top: 0,
            child: _SlideAway(
              visible: _chrome,
              offset: const Offset(0, -1.4),
              child: _MushafTopBar(
                title: _surahLabel(l10n).isEmpty
                    ? l10n.t('quran.mushaf')
                    : _surahLabel(l10n),
                subtitle: l10n.t(
                  'quran.pageIndicator',
                  args: <String, Object?>{'page': l10n.n(_page)},
                ),
                paper: paper,
                onClose: () => Navigator.of(context).maybePop(),
                tajweed: settings.mushafTajweed,
                bookmarked: bookmarked,
                onTajweed: _toggleTajweed,
                onTheme: _toggleTheme,
                onBookmark: _toggleBookmark,
                onGoTo: _showNavigator,
                onAbout: _openAbout,
                onTextMode: _switchToTextMode,
              ),
            ),
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: _SlideAway(
              visible: _chrome,
              offset: const Offset(0, 1.4),
              child: _MushafBottomBar(
                paper: paper,
                page: _page,
                totalPages: _totalPages,
                scrub: _scrub,
                surah: _currentSurah,
                ayah: _currentAyah,
                subtitle: l10n.t(
                  'quran.pageShort',
                  args: <String, Object?>{'n': l10n.n(_page)},
                ),
                onScrub: (value) => setState(() => _scrub = value),
                onScrubEnd: (value) {
                  setState(() => _scrub = null);
                  _jumpTo(value.round());
                },
                onPrevious: () => _step(-1),
                onNext: () => _step(1),
                onOpenNavigator: _showNavigator,
              ),
            ),
          ),

          // The frame goes last so it is never washed out by the chrome's
          // paper-coloured scrim; its inset keeps it clear of every control.
          Positioned.fill(
            child: IgnorePointer(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(_frameInset),
                  child: LayoutBuilder(
                    builder: (context, constraints) => CustomPaint(
                      painter: _PageFramePainter(
                        twoPage: constraints.maxWidth >= _twoPageMinWidth,
                        color: tokens.gold.withValues(
                          alpha: isDark ? 0.38 : 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The width at which `QuranPageView` switches to a two-page spread
/// (`quran_page_view.dart`: `constraints.maxWidth >= 750`). Mirrored here so
/// the frame can split exactly where the two pages meet.
///
/// Kept in step with [_frameInset]: the page widget is laid out inside the
/// inset, so this is compared against the *inner* width.
const double _twoPageMinWidth = 750;

/// Draws a hairline frame on the page boundary, and — when the reader shows a
/// spread — one frame per page, so the right page is visibly separate from the
/// left one.
///
/// It is painted over the inset page area, never inside it: the line lands in
/// the paper margin, so it can never cross a line of Uthmani text, and nothing
/// is cropped — the page is simply laid out in the box inside the frame.
class _PageFramePainter extends CustomPainter {
  const _PageFramePainter({required this.twoPage, required this.color});

  final bool twoPage;
  final Color color;

  /// Half the gap between the two frames of a spread. Two hairlines 6px apart
  /// read as the gutter of an open book without drawing a third line.
  static const double _spineGap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;

    const radius = Radius.circular(3);
    const half = 0.5; // keep the 1px stroke fully inside the box

    if (!twoPage) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(half, half, size.width - half, size.height - half),
          radius,
        ),
        stroke,
      );
      return;
    }

    final middle = size.width / 2;
    // Right page first: this is an RTL Mushaf, so the right-hand page is the
    // one read first.
    final pages = <Rect>[
      Rect.fromLTRB(middle + _spineGap, half, size.width - half, size.height - half),
      Rect.fromLTRB(half, half, middle - _spineGap, size.height - half),
    ];
    for (final page in pages) {
      canvas.drawRRect(RRect.fromRectAndRadius(page, radius), stroke);
    }
  }

  @override
  bool shouldRepaint(_PageFramePainter oldDelegate) =>
      oldDelegate.twoPage != twoPage || oldDelegate.color != color;
}

/// Slides a chrome layer off-screen when the reader is immersed.
class _SlideAway extends StatelessWidget {
  const _SlideAway({
    required this.visible,
    required this.offset,
    required this.child,
  });

  final bool visible;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : offset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: child,
        ),
      ),
    );
  }
}

/// Top chrome: reading position, appearance toggles, bookmark and menu.
class _MushafTopBar extends StatelessWidget {
  const _MushafTopBar({
    required this.title,
    required this.subtitle,
    required this.paper,
    required this.onClose,
    required this.tajweed,
    required this.bookmarked,
    required this.onTajweed,
    required this.onTheme,
    required this.onBookmark,
    required this.onGoTo,
    required this.onAbout,
    required this.onTextMode,
  });

  final String title;
  final String subtitle;
  final Color paper;
  final VoidCallback onClose;
  final bool tajweed;
  final bool bookmarked;
  final VoidCallback onTajweed;
  final VoidCallback onTheme;
  final VoidCallback onBookmark;
  final VoidCallback onGoTo;
  final VoidCallback onAbout;
  final VoidCallback onTextMode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            paper.withValues(alpha: 0.98),
            paper.withValues(alpha: 0.86),
            paper.withValues(alpha: 0),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ZadSpacing.xs,
            ZadSpacing.xs,
            ZadSpacing.xs,
            0,
          ),
          child: Row(
            children: <Widget>[
              IconButton(
                onPressed: onClose,
                tooltip: l10n.t('common.close'),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: zadText(
                        size: 15,
                        weight: 700,
                        family: ZadFonts.arabicUi,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onTajweed,
                tooltip: l10n.t('quran.tajweed'),
                isSelected: tajweed,
                icon: const Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome, color: tokens.gold),
              ),
              IconButton(
                onPressed: onTheme,
                tooltip: l10n.t('quran.appearance'),
                icon: Icon(
                  theme.brightness == Brightness.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
              ),
              IconButton(
                onPressed: onBookmark,
                tooltip: l10n.t(
                  bookmarked ? 'quran.removeBookmark' : 'quran.addBookmark',
                ),
                icon: Icon(
                  bookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: bookmarked ? tokens.gold : null,
                ),
              ),
              PopupMenuButton<_MushafAction>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: l10n.t('nav.more'),
                onSelected: (action) {
                  switch (action) {
                    case _MushafAction.navigate:
                      onGoTo();
                    case _MushafAction.textMode:
                      onTextMode();
                    case _MushafAction.about:
                      onAbout();
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
                    value: _MushafAction.about,
                    child: _MenuRow(
                      icon: Icons.verified_outlined,
                      label: l10n.t('quran.aboutMushaf'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MushafAction { navigate, textMode, about }

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

/// Bottom chrome: the listen affordance, page scrubber and previous / next.
class _MushafBottomBar extends StatelessWidget {
  const _MushafBottomBar({
    required this.paper,
    required this.page,
    required this.totalPages,
    required this.scrub,
    required this.surah,
    required this.ayah,
    required this.subtitle,
    required this.onScrub,
    required this.onScrubEnd,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenNavigator,
  });

  final Color paper;
  final int page;
  final int totalPages;
  final double? scrub;

  /// The surah this page belongs to; `null` until the dataset is loaded.
  final Surah? surah;

  /// First ayah on this page — the ayah the listen sheet pre-selects.
  final int ayah;

  final String subtitle;
  final ValueChanged<double> onScrub;
  final ValueChanged<double> onScrubEnd;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onOpenNavigator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[
            paper.withValues(alpha: 0.98),
            paper.withValues(alpha: 0.86),
            paper.withValues(alpha: 0),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ZadSpacing.md,
            ZadSpacing.lg,
            ZadSpacing.md,
            ZadSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (surah case final Surah current)
                ListenBar(surah: current, initialAyah: ayah),
              const SizedBox(height: ZadSpacing.xs),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.5,
                  activeTrackColor: tokens.gold,
                  thumbColor: tokens.gold,
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6.5,
                  ),
                ),
                child: Slider(
                  value: (scrub ?? page.toDouble()).clamp(
                    1,
                    totalPages.toDouble(),
                  ),
                  min: 1,
                  max: totalPages.toDouble(),
                  onChanged: onScrub,
                  onChangeEnd: onScrubEnd,
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
                              subtitle,
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
                              AppLocalizations.of(context).t('quran.goTo'),
                              maxLines: 1,
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
    );
  }
}

/// Loading state drawn on the page's own paper colour, so the transition into
/// the first page is a fade of ink rather than a flash of another surface.
class _PaperLoading extends StatelessWidget {
  const _PaperLoading({required this.paper, required this.message});

  final Color paper;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: paper,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: ZadSpacing.md),
            Text(message, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _PaperError extends StatelessWidget {
  const _PaperError({
    required this.paper,
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final Color paper;
  final String title;
  final String body;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: paper,
      child: ErrorView(title: title, body: body, onRetry: onRetry),
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
          title: Text(
            l10n.t('quran.juzShort', args: <String, Object?>{'n': l10n.n(juz)}),
          ),
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
