import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/repositories/local_store.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_logo.dart';
import '../shell/app_shell.dart';

/// First-run tour of what Zad actually does.
///
/// Shown once, between the splash and the shell. It is deliberately
/// informational only — no permission is requested here, because a dialog that
/// arrives before the user knows what it is for is the usual way onboarding
/// gets skipped. Each screen that needs a permission asks for it in context.
///
/// Pass [replay] to open it again from settings: finishing then simply pops
/// back instead of replacing the route with the shell.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.replay = false});

  final bool replay;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const int _pageCount = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _pageCount - 1;

  Future<void> _finish() async {
    if (!widget.replay) {
      // Only mark it seen on the real first run; a replay must not rewrite the
      // flag on an install that already had it.
      await context.read<LocalStore>().setBool(
        LocalStore.keyOnboardingSeen,
        true,
      );
    }
    if (!mounted) return;
    if (widget.replay) {
      Navigator.of(context).maybePop();
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => const AppShell(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final pages = <_OnboardingPage>[
      _OnboardingPage(
        icon: Icons.auto_awesome_rounded,
        title: l10n.t('onboarding.welcomeTitle'),
        body: l10n.t('onboarding.welcomeBody'),
        points: <String>[
          l10n.t('onboarding.welcomePoint1'),
          l10n.t('onboarding.welcomePoint2'),
        ],
        showLogo: true,
      ),
      _OnboardingPage(
        icon: Icons.auto_stories_outlined,
        title: l10n.t('onboarding.quranTitle'),
        body: l10n.t('onboarding.quranBody'),
        points: <String>[
          l10n.t('onboarding.quranPoint1'),
          l10n.t('onboarding.quranPoint2'),
          l10n.t('onboarding.quranPoint3'),
        ],
      ),
      _OnboardingPage(
        icon: Icons.graphic_eq_rounded,
        title: l10n.t('onboarding.audioTitle'),
        body: l10n.t('onboarding.audioBody'),
        points: <String>[
          l10n.t('onboarding.audioPoint1'),
          l10n.t('onboarding.audioPoint2'),
        ],
      ),
      _OnboardingPage(
        icon: Icons.explore_outlined,
        title: l10n.t('onboarding.prayerTitle'),
        body: l10n.t('onboarding.prayerBody'),
        points: <String>[
          l10n.t('onboarding.prayerPoint1'),
          l10n.t('onboarding.prayerPoint2'),
        ],
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZadSpacing.sm,
                vertical: ZadSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  if (widget.replay)
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: l10n.t('common.close'),
                    ),
                  const Spacer(),
                  if (!_isLast && !widget.replay)
                    TextButton(
                      onPressed: _finish,
                      child: Text(l10n.t('onboarding.skip')),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) =>
                    _PageView(page: pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZadSpacing.lg,
                ZadSpacing.sm,
                ZadSpacing.lg,
                ZadSpacing.md,
              ),
              child: Column(
                children: <Widget>[
                  _Dots(count: pages.length, index: _index),
                  const SizedBox(height: ZadSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 50),
                      ),
                      child: Text(
                        _isLast
                            ? l10n.t('onboarding.start')
                            : l10n.t('onboarding.next'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.points,
    this.showLogo = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<String> points;
  final bool showLogo;
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  if (page.showLogo)
                    const ZadLogo(size: 108)
                  else
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tokens.gold.withValues(alpha: 0.14),
                        border: Border.all(
                          color: tokens.gold.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(page.icon, size: 38, color: tokens.gold),
                    ),
                  const SizedBox(height: ZadSpacing.lg),
                  Text(
                    page.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: ZadSpacing.sm),
                  Text(
                    page.body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.lg),
                  ZadCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZadSpacing.md,
                      vertical: ZadSpacing.sm,
                    ),
                    child: Column(
                      children: <Widget>[
                        for (var i = 0; i < page.points.length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(height: ZadSpacing.sm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 17,
                                  color: tokens.gold,
                                ),
                              ),
                              const SizedBox(width: ZadSpacing.sm),
                              Expanded(
                                child: Text(
                                  page.points[i],
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == index ? tokens.gold : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(ZadRadius.full),
            ),
          ),
      ],
    );
  }
}
