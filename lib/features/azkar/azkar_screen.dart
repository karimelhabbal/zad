import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/azkar_models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/azkar_controller.dart';
import '../../state/quran_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_app_bar.dart';
import 'azkar_icons.dart';
import 'azkar_reader_screen.dart';

/// The adhkar hub: today's wird progress plus every category from the bundled,
/// sourced adhkar collection.
class AzkarScreen extends StatefulWidget {
  const AzkarScreen({super.key});

  @override
  State<AzkarScreen> createState() => _AzkarScreenState();
}

class _AzkarScreenState extends State<AzkarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  void _ensureLoaded() {
    final azkar = context.read<AzkarController>();
    if (azkar.isReady) return;
    final quran = context.read<QuranController>();
    final data = quran.data;
    if (data == null) return;
    azkar.initialise(data);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final azkar = context.watch<AzkarController>();
    final tokens = context.tokens;

    return Scaffold(
      appBar: ZadAppBar(
        title: l10n.t('azkar.title'),
        subtitle: l10n.t('azkar.subtitle'),
      ),
      body: switch (azkar.state) {
        LoadState.idle || LoadState.loading => LoadingView(
          message: l10n.t('common.loading'),
        ),
        LoadState.error => ErrorView(
          body: azkar.error,
          onRetry: () {
            final quran = context.read<QuranController>();
            final data = quran.data;
            if (data != null) azkar.initialise(data);
          },
        ),
        LoadState.ready => RefreshIndicator(
          onRefresh: () async {
            final quran = context.read<QuranController>();
            final data = quran.data;
            if (data != null) await azkar.initialise(data);
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              ZadSpacing.md,
              ZadSpacing.md,
              ZadSpacing.md,
              MediaQuery.of(context).padding.bottom + ZadSpacing.md,
            ),
            children: <Widget>[
              _WirdHero(
                completed: azkar.totalCompleted,
                total: azkar.totalItems,
                onContinue: () => _continueWird(azkar),
              ),
              const SizedBox(height: ZadSpacing.lg),
              SectionHeader(
                title: l10n.t('azkar.categories'),
                icon: Icons.grid_view_rounded,
                subtitle: l10n.t(
                  'azkar.completedOf',
                  args: <String, Object?>{
                    'done': l10n.n(azkar.totalCompleted),
                    'total': l10n.n(azkar.totalItems),
                  },
                ),
              ),
              const SizedBox(height: ZadSpacing.md),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: ZadSpacing.md,
                      mainAxisSpacing: ZadSpacing.md,
                      childAspectRatio: 0.92,
                    ),
                itemCount: azkar.categories.length,
                itemBuilder: (context, index) {
                  final category = azkar.categories[index];
                  return _CategoryCard(
                    category: category,
                    completed: azkar.completedCount(category),
                    progress: azkar.categoryProgress(category),
                    accent: tokens.gold,
                    onTap: () => _openCategory(category),
                  );
                },
              ),
              const SizedBox(height: ZadSpacing.lg),
              const _SourceNote(),
            ],
          ),
        ),
      },
    );
  }

  Future<void> _continueWird(AzkarController azkar) async {
    final next = azkar.firstUnfinished;
    if (next == null) {
      final first = azkar.categories.isEmpty ? null : azkar.categories.first;
      if (first == null) return;
      await _openCategory(first);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AzkarReaderScreen(
          categoryId: next.$1.id,
          initialIndex: next.$2,
        ),
      ),
    );
  }

  Future<void> _openCategory(ZikrCategory category) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AzkarReaderScreen(categoryId: category.id),
      ),
    );
  }
}

class _WirdHero extends StatelessWidget {
  const _WirdHero({
    required this.completed,
    required this.total,
    required this.onContinue,
  });

  final int completed;
  final int total;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final ratio = total == 0 ? 0.0 : completed / total;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: tokens.heroGradient,
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(ZadRadius.xxl),
        border: Border.all(color: tokens.gold.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(ZadSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_awesome_rounded, size: 18, color: tokens.gold),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: Text(
                  l10n.t('azkar.progress'),
                  style: zadText(
                    size: 15,
                    weight: 600,
                    family: ZadFonts.arabicUi,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '${l10n.n(completed)} / ${l10n.n(total)}',
                style: zadText(
                  size: 15,
                  weight: 700,
                  family: ZadFonts.arabicUi,
                  color: tokens.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(ZadRadius.full),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation<Color>(tokens.gold),
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          Text(
            l10n.t(
              'azkar.completedOf',
              args: <String, Object?>{
                'done': l10n.n(completed),
                'total': l10n.n(total),
              },
            ),
            style: zadText(
              size: 12,
              weight: 400,
              family: ZadFonts.arabicUi,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.surface,
                foregroundColor: scheme.primary,
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(l10n.t('azkar.continueReading')),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.completed,
    required this.progress,
    required this.accent,
    required this.onTap,
  });

  final ZikrCategory category;
  final int completed;
  final double progress;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ZadCard(
      onTap: onTap,
      padding: const EdgeInsets.all(ZadSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(ZadRadius.md),
                ),
                child: Icon(
                  azkarIcon(category.icon),
                  size: 19,
                  color: scheme.primary,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 34,
                height: 34,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    CircularProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      strokeWidth: 3,
                      backgroundColor: scheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                    Text(
                      l10n.n(completed),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.sm + 2),
          Text(
            category.title.resolve(l10n.isArabic),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            category.subtitle.resolve(l10n.isArabic),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
          const Spacer(),
          Row(
            children: <Widget>[
              Icon(
                Icons.format_list_numbered_rounded,
                size: 13,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                l10n.t(
                  'azkar.itemsCount',
                  args: <String, Object?>{'n': l10n.n(category.itemCount)},
                ),
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceNote extends StatelessWidget {
  const _SourceNote();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ZadCard(
      padding: const EdgeInsets.all(ZadSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.verified_outlined,
            size: 18,
            color: context.tokens.gold,
          ),
          const SizedBox(width: ZadSpacing.sm),
          Expanded(
            child: Text(
              l10n.t('settings.sourcesBody'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
