import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/azkar_models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/azkar_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_app_bar.dart';
import 'azkar_icons.dart';

/// The adhkar reading flow.
///
/// One dhikr at a time with its verbatim text, its documented repetition count
/// and its cited source. Progress is stored per dhikr, so closing the app never
/// loses a partly-finished wird.
class AzkarReaderScreen extends StatefulWidget {
  const AzkarReaderScreen({
    super.key,
    required this.categoryId,
    this.initialIndex = 0,
  });

  final String categoryId;
  final int initialIndex;

  @override
  State<AzkarReaderScreen> createState() => _AzkarReaderScreenState();
}

class _AzkarReaderScreenState extends State<AzkarReaderScreen> {
  late int _index = widget.initialIndex;
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );

  /// When enabled a single tap counts the whole required repetition count.
  bool _autoCount = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  AzkarController get _azkar => context.read<AzkarController>();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final azkar = context.watch<AzkarController>();
    final category = azkar.categoryById(widget.categoryId);

    if (category == null) {
      return Scaffold(
        appBar: ZadAppBar(
          title: l10n.t('azkar.title'),
          showLogo: false,
          leading: _backButton(l10n),
        ),
        body: EmptyView(
          icon: Icons.auto_awesome_outlined,
          title: l10n.t('common.notAvailable'),
        ),
      );
    }

    final items = category.items;
    final completed = azkar.completedCount(category);
    final progress = azkar.categoryProgress(category);

    return Scaffold(
      appBar: ZadAppBar(
        title: category.title.resolve(l10n.isArabic),
        subtitle: l10n.t(
          'azkar.itemProgress',
          args: <String, Object?>{
            'done': l10n.n(completed),
            'total': l10n.n(items.length),
          },
        ),
        showLogo: false,
        leading: _backButton(l10n),
        actions: <Widget>[
          ZadIconButton(
            icon: Icons.list_alt_rounded,
            tooltip: l10n.t('azkar.categories'),
            onPressed: () => _showIndexSheet(category),
          ),
          PopupMenuButton<_ReaderAction>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: l10n.t('nav.more'),
            onSelected: (action) async {
              switch (action) {
                case _ReaderAction.autoCount:
                  setState(() => _autoCount = !_autoCount);
                case _ReaderAction.reset:
                  await _resetCategory(category);
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<_ReaderAction>>[
              CheckedPopupMenuItem<_ReaderAction>(
                value: _ReaderAction.autoCount,
                checked: _autoCount,
                child: Text(l10n.t('azkar.autoCount')),
              ),
              PopupMenuItem<_ReaderAction>(
                value: _ReaderAction.reset,
                child: Text(l10n.t('azkar.reset')),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: ClipRRect(
            borderRadius: BorderRadius.zero,
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 3,
            ),
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: items.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                final item = items[index];
                return _ZikrView(
                  key: ValueKey<String>(item.id),
                  categoryId: category.id,
                  item: item,
                  index: index,
                  total: items.length,
                  autoCount: _autoCount,
                );
              },
            ),
          ),
          _ReaderNav(
            index: _index,
            total: items.length,
            onPrevious: _index == 0 ? null : () => _goTo(_index - 1),
            onNext: _index >= items.length - 1 ? null : () => _goTo(_index + 1),
            onFinish: () => _finish(items, azkar),
          ),
        ],
      ),
    );
  }

  Widget _backButton(AppLocalizations l10n) => IconButton(
    onPressed: () => Navigator.of(context).maybePop(),
    icon: const Icon(Icons.arrow_forward_rounded),
    tooltip: l10n.t('common.close'),
  );

  void _goTo(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _resetCategory(ZikrCategory category) async {
    final l10n = context.l10n;
    final confirmed = await showZadConfirm(
      context,
      title: l10n.t('azkar.resetConfirm'),
      body: l10n.t('azkar.resetConfirmBody'),
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _azkar.resetCategory(category.id);
    if (!mounted) return;
    showZadSnack(context, l10n.t('azkar.resetDone'));
  }

  Future<void> _finish(List<ZikrItem> items, AzkarController azkar) async {
    final l10n = context.l10n;
    final remaining = items
        .where((item) => !azkar.isCompleted(widget.categoryId, item))
        .length;
    if (remaining == 0) {
      showZadSnack(context, l10n.t('azkar.finished'));
      return;
    }
    final firstRemaining = items.indexWhere(
      (item) => !azkar.isCompleted(widget.categoryId, item),
    );
    if (firstRemaining >= 0) _goTo(firstRemaining);
  }

  Future<void> _showIndexSheet(ZikrCategory category) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _IndexSheet(category: category),
    );
    if (selected == null || !mounted) return;
    _goTo(selected);
  }
}

enum _ReaderAction { autoCount, reset }

/// A single dhikr: text, source, virtue and the tap-to-count target.
class _ZikrView extends StatelessWidget {
  const _ZikrView({
    super.key,
    required this.categoryId,
    required this.item,
    required this.index,
    required this.total,
    required this.autoCount,
  });

  final String categoryId;
  final ZikrItem item;
  final int index;
  final int total;
  final bool autoCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final azkar = context.watch<AzkarController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;

    final done = azkar.repetitionsOf(categoryId, item);
    final complete = done >= item.count;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZadSpacing.md,
        ZadSpacing.md,
        ZadSpacing.md,
        ZadSpacing.lg,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            ZadBadge(
              label: l10n.t(
                'azkar.dhikrNumber',
                args: <String, Object?>{'n': l10n.n(index + 1)},
              ),
              icon: Icons.tag,
            ),
            const Spacer(),
            ZadBadge(
              label: l10n.t(
                'azkar.itemProgress',
                args: <String, Object?>{
                  'done': l10n.n(index + 1),
                  'total': l10n.n(total),
                },
              ),
              icon: Icons.format_list_numbered_rounded,
            ),
          ],
        ),
        const SizedBox(height: ZadSpacing.md),
        if (item.isQuranic) ...<Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.menu_book_rounded, size: 15, color: tokens.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.t('azkar.quranicText'),
                  style: theme.textTheme.labelSmall?.copyWith(color: tokens.gold),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.sm),
        ],
        ZadCard(
          padding: const EdgeInsets.all(ZadSpacing.lg),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              item.text,
              textAlign: TextAlign.justify,
              style: zadText(
                size: item.isQuranic ? 24 : 21,
                weight: 400,
                height: 2.1,
                family: ZadFonts.classical,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(height: ZadSpacing.md),
        _CounterTarget(
          categoryId: categoryId,
          item: item,
          done: done,
          complete: complete,
          autoCount: autoCount,
        ),
        const SizedBox(height: ZadSpacing.md),
        if (item.source != null)
          _InfoBlock(
            icon: Icons.verified_outlined,
            title: l10n.t('azkar.source'),
            body: item.source!.resolve(l10n.isArabic),
            accent: tokens.gold,
          ),
        if (item.virtue != null) ...<Widget>[
          const SizedBox(height: ZadSpacing.md),
          _InfoBlock(
            icon: Icons.auto_awesome_rounded,
            title: l10n.t('azkar.virtue'),
            body: item.virtue!.resolve(l10n.isArabic),
            accent: scheme.primary,
          ),
        ],
      ],
    );
  }
}

/// The large circular tap target that records one repetition per tap.
class _CounterTarget extends StatefulWidget {
  const _CounterTarget({
    required this.categoryId,
    required this.item,
    required this.done,
    required this.complete,
    required this.autoCount,
  });

  final String categoryId;
  final ZikrItem item;
  final int done;
  final bool complete;
  final bool autoCount;

  @override
  State<_CounterTarget> createState() => _CounterTargetState();
}

class _CounterTargetState extends State<_CounterTarget> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    final azkar = context.read<AzkarController>();
    final settings = context.read<SettingsController>();
    if (widget.complete && !widget.autoCount) return;

    setState(() => _busy = true);
    try {
      if (settings.settings.tasbeehVibration) {
        await HapticFeedback.selectionClick();
      }
      if (widget.autoCount) {
        await azkar.markCompleted(widget.categoryId, widget.item);
      } else {
        final completed = await azkar.countOnce(widget.categoryId, widget.item);
        if (completed && settings.settings.tasbeehVibration) {
          await HapticFeedback.mediumImpact();
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final azkar = context.read<AzkarController>();
    await azkar.setRepetitions(widget.categoryId, widget.item, 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;
    final progress = widget.item.count == 0
        ? 0.0
        : (widget.done / widget.item.count).clamp(0.0, 1.0);

    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.repeat_rounded, size: 15, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              l10n.t('azkar.repeat'),
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(width: 6),
            Text(
              '${l10n.n(widget.item.count)} ${l10n.t('azkar.times')}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZadSpacing.md),
        Semantics(
          button: true,
          label: l10n.t('azkar.tapToCount'),
          child: GestureDetector(
            onTap: _tap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 168,
              height: 168,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.complete
                    ? scheme.primaryContainer.withValues(alpha: 0.22)
                    : scheme.surfaceContainerHigh,
                border: Border.all(
                  color: widget.complete ? tokens.gold : scheme.outlineVariant,
                  width: 2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: tokens.ambientShadow,
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 5,
                      backgroundColor: scheme.outlineVariant.withValues(
                        alpha: 0.4,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.complete ? tokens.gold : scheme.primary,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (widget.complete)
                        Icon(Icons.check_rounded, size: 34, color: tokens.gold)
                      else
                        Text(
                          l10n.n(widget.done),
                          style: zadText(
                            size: 44,
                            weight: 700,
                            family: ZadFonts.arabicUi,
                            color: scheme.onSurface,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.t(
                          'azkar.itemProgress',
                          args: <String, Object?>{
                            'done': l10n.n(widget.done),
                            'total': l10n.n(widget.item.count),
                          },
                        ),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: ZadSpacing.sm + 2),
        Text(
          widget.complete ? l10n.t('azkar.completed') : l10n.t('azkar.tapToCount'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: widget.complete ? tokens.gold : scheme.onSurfaceVariant,
          ),
        ),
        if (widget.done > 0) ...<Widget>[
          const SizedBox(height: ZadSpacing.sm),
          TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(l10n.t('azkar.counterReset')),
          ),
        ],
      ],
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ZadCard(
      padding: const EdgeInsets.all(ZadSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 17, color: accent),
          const SizedBox(width: ZadSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderNav extends StatelessWidget {
  const _ReaderNav({
    required this.index,
    required this.total,
    required this.onPrevious,
    required this.onNext,
    required this.onFinish,
  });

  final int index;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Material(
      color: scheme.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tokens.cardBorder)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ZadSpacing.md,
              ZadSpacing.sm,
              ZadSpacing.md,
              ZadSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                IconButton.filledTonal(
                  onPressed: onPrevious,
                  tooltip: l10n.t('azkar.previous'),
                  icon: Icon(
                    rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                  ),
                ),
                const SizedBox(width: ZadSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onFinish,
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: Text(l10n.t('azkar.finish')),
                  ),
                ),
                const SizedBox(width: ZadSpacing.sm),
                IconButton.filledTonal(
                  onPressed: onNext,
                  tooltip: l10n.t('azkar.next'),
                  icon: Icon(
                    rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Index of the wird with search and completion filters.
class _IndexSheet extends StatefulWidget {
  const _IndexSheet({required this.category});

  final ZikrCategory category;

  @override
  State<_IndexSheet> createState() => _IndexSheetState();
}

class _IndexSheetState extends State<_IndexSheet> {
  final TextEditingController _search = TextEditingController();
  int _filter = 0; // 0 = all, 1 = completed, 2 = remaining

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final azkar = context.watch<AzkarController>();
    final theme = Theme.of(context);

    var items = azkar.search(widget.category, _search.text);
    if (_filter == 1) {
      items = items
          .where((item) => azkar.isCompleted(widget.category.id, item))
          .toList(growable: false);
    } else if (_filter == 2) {
      items = items
          .where((item) => !azkar.isCompleted(widget.category.id, item))
          .toList(growable: false);
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: Column(
        children: <Widget>[
          const SizedBox(height: ZadSpacing.sm),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ZadSpacing.md,
              0,
              ZadSpacing.md,
              ZadSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      azkarIcon(widget.category.icon),
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: ZadSpacing.sm),
                    Expanded(
                      child: Text(
                        widget.category.title.resolve(l10n.isArabic),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      l10n.t(
                        'azkar.itemProgress',
                        args: <String, Object?>{
                          'done': l10n.n(azkar.completedCount(widget.category)),
                          'total': l10n.n(widget.category.itemCount),
                        },
                      ),
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: ZadSpacing.md),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: l10n.t('azkar.searchHint'),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: ZadSpacing.sm),
                Row(
                  children: <Widget>[
                    ZadFilterChip(
                      label: l10n.t('azkar.filterAll'),
                      selected: _filter == 0,
                      onTap: () => setState(() => _filter = 0),
                    ),
                    const SizedBox(width: ZadSpacing.sm),
                    ZadFilterChip(
                      label: l10n.t('azkar.filterCompleted'),
                      selected: _filter == 1,
                      onTap: () => setState(() => _filter = 1),
                    ),
                    const SizedBox(width: ZadSpacing.sm),
                    ZadFilterChip(
                      label: l10n.t('azkar.filterRemaining'),
                      selected: _filter == 2,
                      onTap: () => setState(() => _filter = 2),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? EmptyView(
                    icon: Icons.search_off_rounded,
                    title: l10n.t('azkar.noResults'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      vertical: ZadSpacing.sm,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final complete = azkar.isCompleted(
                        widget.category.id,
                        item,
                      );
                      final realIndex = widget.category.items.indexOf(item);
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: complete
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHigh,
                          child: complete
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 15,
                                  color: context.tokens.gold,
                                )
                              : Text(
                                  l10n.n(realIndex + 1),
                                  style: theme.textTheme.labelSmall,
                                ),
                        ),
                        title: Text(
                          item.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        subtitle: Text(
                          '${l10n.t('azkar.repeat')}: '
                          '${l10n.n(item.count)} ${l10n.t('azkar.times')}',
                          style: theme.textTheme.labelSmall,
                        ),
                        onTap: () => Navigator.of(context).pop(realIndex),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
