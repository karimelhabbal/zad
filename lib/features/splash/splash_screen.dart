import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';
import '../../state/azkar_controller.dart';
import '../../state/prayer_controller.dart';
import '../../state/quran_controller.dart';
import '../../state/tasbeeh_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_logo.dart';
import '../shell/app_shell.dart';

/// Branded splash: shows the Zad mark while the bundled Quran text and adhkar
/// content are prepared, then hands over to the app shell.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  bool _ready = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final quran = context.read<QuranController>();
    final azkar = context.read<AzkarController>();
    final tasbeeh = context.read<TasbeehController>();
    final prayer = context.read<PrayerController>();

    final started = DateTime.now();
    try {
      await quran.initialise();
      final data = quran.data;
      if (data == null) {
        throw StateError('Quran dataset failed to load');
      }
      await azkar.initialise(data);
      await tasbeeh.initialise(azkar.categories);
      // Warm the prayer schedule without triggering a permission dialog.
      unawaited(prayer.refresh());
    } catch (e) {
      _failure = e.toString();
    }
    // The native Android launch screen already shows the brand, so the Flutter
    // splash only has to bridge the dataset load. A long artificial hold here
    // would read as a second, duplicate splash.
    const minimum = Duration(milliseconds: 450);
    final elapsed = DateTime.now().difference(started);
    if (elapsed < minimum) {
      await Future<void>.delayed(minimum - elapsed);
    }
    if (!mounted) return;
    setState(() => _ready = true);
  }

  void _enter() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => const AppShell(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final quran = context.watch<QuranController>();
    final data = quran.data;
    final verse = data?.verseOfTheDay(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ZadSpacing.lg,
                        vertical: ZadSpacing.lg,
                      ),
                      child: FadeTransition(
                        opacity: _fade,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            ScaleTransition(
                              scale: _scale,
                              child: const ZadLogo(size: 132),
                            ),
                            const SizedBox(height: ZadSpacing.lg),
                            Text(
                              l10n.t('app.name'),
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontSize: 38,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: ZadSpacing.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Expanded(child: ZadDivider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: ZadSpacing.sm,
                                  ),
                                  child: Text(
                                    l10n.t('app.tagline'),
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: context.tokens.gold,
                                    ),
                                  ),
                                ),
                                const Expanded(child: ZadDivider()),
                              ],
                            ),
                            const SizedBox(height: ZadSpacing.md),
                            Text(
                              l10n.t('app.description'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: ZadSpacing.xl),
                            if (verse != null)
                              ZadCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: ZadSpacing.md,
                                  vertical: ZadSpacing.lg,
                                ),
                                child: Column(
                                  children: <Widget>[
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: <Widget>[
                                        Icon(
                                          Icons.menu_book_outlined,
                                          size: 15,
                                          color: context.tokens.gold,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          l10n.t('home.verseOfDay'),
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color: context.tokens.gold,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: ZadSpacing.md),
                                    Text(
                                      verse.$2.text,
                                      textAlign: TextAlign.center,
                                      textDirection: TextDirection.rtl,
                                      style: quranVerseStyle(
                                        color: scheme.onSurface,
                                        size: 22,
                                        height: 2.0,
                                      ),
                                    ),
                                    const SizedBox(height: ZadSpacing.sm),
                                    Text(
                                      '${l10n.t('quran.surahPrefix')} '
                                      '${verse.$1.arabicName} • '
                                      '${l10n.t('quran.ayah')} '
                                      '${l10n.n(verse.$2.numberInSurah)}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: ZadSpacing.lg),
                            if (_failure != null)
                              ErrorView(
                                body: l10n.t('common.error'),
                                onRetry: () {
                                  setState(() => _failure = null);
                                  _bootstrap();
                                },
                              )
                            else if (!_ready)
                              Column(
                                children: <Widget>[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      ZadRadius.full,
                                    ),
                                    child: LinearProgressIndicator(
                                      minHeight: 4,
                                      backgroundColor:
                                          scheme.surfaceContainerHighest,
                                    ),
                                  ),
                                  const SizedBox(height: ZadSpacing.md),
                                  Text(
                                    l10n.t('splash.preparing'),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              )
                            else
                              Column(
                                children: <Widget>[
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: _enter,
                                      icon: const Icon(
                                        Icons.arrow_back,
                                        size: 20,
                                      ),
                                      label: Text(l10n.t('app.enter')),
                                    ),
                                  ),
                                  const SizedBox(height: ZadSpacing.md),
                                  ZadBadge(
                                    label: l10n.t('splash.certified'),
                                    icon: Icons.verified_outlined,
                                  ),
                                ],
                              ),
                            const SizedBox(height: ZadSpacing.xl),
                            Text(
                              l10n.t('app.versionNote'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall,
                            ),
                            const SizedBox(height: ZadSpacing.xs),
                            Text(
                              l10n.t('app.values'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
