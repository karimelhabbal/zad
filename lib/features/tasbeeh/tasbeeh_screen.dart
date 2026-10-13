import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/azkar_models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/settings_controller.dart';
import '../../state/tasbeeh_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_app_bar.dart';
import '../quran/quran_navigation.dart';

/// The digital tasbeeh: built-in adhkar with their documented counts, full CRUD
/// for the user's own adhkar, per-entry counters and daily statistics.
class TasbeehScreen extends StatelessWidget {
  const TasbeehScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tasbeeh = context.watch<TasbeehController>();
    final tokens = context.tokens;

    return Scaffold(
      appBar: ZadAppBar(
        title: l10n.t('tasbeeh.title'),
        subtitle: l10n.t('tasbeeh.dhikrSaved'),
        actions: <Widget>[
          ZadIconButton(
            icon: Icons.add_rounded,
            tooltip: l10n.t('tasbeeh.addDhikr'),
            onPressed: () => QuranNavigation.openDhikrEditor(context),
          ),
        ],
      ),
      body: !tasbeeh.isInitialised
          ? LoadingView(message: l10n.t('common.loading'))
          : ListView(
              padding: EdgeInsets.fromLTRB(
                ZadSpacing.md,
                ZadSpacing.md,
                ZadSpacing.md,
                MediaQuery.of(context).padding.bottom + ZadSpacing.md,
              ),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: StatTile(
                        label: l10n.t('tasbeeh.totalToday'),
                        value: l10n.n(tasbeeh.totalToday),
                        icon: Icons.today_rounded,
                        accent: tokens.gold,
                      ),
                    ),
                    const SizedBox(width: ZadSpacing.md),
                    Expanded(
                      child: StatTile(
                        label: l10n.t('tasbeeh.totalAll'),
                        value: l10n.n(tasbeeh.totalAllTime),
                        icon: Icons.all_inclusive_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZadSpacing.lg),
                SectionHeader(
                  title: l10n.t('tasbeeh.selectDhikr'),
                  subtitle: l10n.t('tasbeeh.builtInNote'),
                  icon: Icons.blur_circular_rounded,
                ),
                const SizedBox(height: ZadSpacing.sm),
                _DhikrSelector(tasbeeh: tasbeeh),
                const SizedBox(height: ZadSpacing.lg),
                _ActiveCounter(tasbeeh: tasbeeh),
                const SizedBox(height: ZadSpacing.lg),
                SectionHeader(
                  title: l10n.t('tasbeeh.myAdhkar'),
                  subtitle: l10n.t('tasbeeh.customHint'),
                  icon: Icons.star_outline_rounded,
                  action: TextButton.icon(
                    onPressed: () => QuranNavigation.openDhikrEditor(context),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text(l10n.t('common.new')),
                  ),
                ),
                const SizedBox(height: ZadSpacing.sm),
                _CustomList(tasbeeh: tasbeeh),
              ],
            ),
    );
  }
}

/// Horizontal selector over every available dhikr (built-in + custom).
class _DhikrSelector extends StatelessWidget {
  const _DhikrSelector({required this.tasbeeh});

  final TasbeehController tasbeeh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = tasbeeh.allDhikr;
    if (items.isEmpty) {
      return ZadCard(
        child: Text(
          l10n.t('tasbeeh.emptyDhikr'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final activeId = tasbeeh.active?.storageId;

    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: ZadSpacing.sm),
        itemBuilder: (context, index) {
          final dhikr = items[index];
          return _DhikrChip(
            dhikr: dhikr,
            selected: dhikr.storageId == activeId,
            count: tasbeeh.countFor(dhikr),
            target: tasbeeh.targetFor(dhikr),
            onTap: () => tasbeeh.selectDhikr(dhikr.storageId),
          );
        },
      ),
    );
  }
}

class _DhikrChip extends StatelessWidget {
  const _DhikrChip({
    required this.dhikr,
    required this.selected,
    required this.count,
    required this.target,
    required this.onTap,
  });

  final ActiveDhikr dhikr;
  final bool selected;
  final int count;
  final int target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final label = dhikr.label ?? dhikr.text;

    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(ZadRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZadRadius.lg),
        child: Container(
          width: 158,
          padding: const EdgeInsets.symmetric(
            horizontal: ZadSpacing.sm + 2,
            vertical: ZadSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZadRadius.lg),
            border: Border.all(
              color: selected ? tokens.gold : tokens.cardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    dhikr.isCustom
                        ? Icons.star_rounded
                        : Icons.blur_circular_rounded,
                    size: 13,
                    color: selected
                        ? (l10n.isArabic
                              ? scheme.onPrimaryContainer
                              : tokens.gold)
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: zadText(
                        size: 13,
                        weight: 600,
                        family: ZadFonts.arabicUi,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                target > 0
                    ? l10n.t(
                        'azkar.itemProgress',
                        args: <String, Object?>{
                          'done': l10n.n(count),
                          'total': l10n.n(target),
                        },
                      )
                    : l10n.n(count),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The large circular counter with the lap count, target chips and reset.
class _ActiveCounter extends StatefulWidget {
  const _ActiveCounter({required this.tasbeeh});

  final TasbeehController tasbeeh;

  @override
  State<_ActiveCounter> createState() => _ActiveCounterState();
}

class _ActiveCounterState extends State<_ActiveCounter> {
  bool _busy = false;

  Future<void> _count() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final settings = context.read<SettingsController>();
      if (settings.settings.tasbeehVibration) {
        await HapticFeedback.selectionClick();
      }
      final lapDone = await widget.tasbeeh.increment();
      if (!mounted) return;
      if (lapDone) {
        if (settings.settings.tasbeehVibration) {
          await HapticFeedback.mediumImpact();
        }
        if (!mounted) return;
        showZadSnack(context, context.l10n.t('tasbeeh.targetReached'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final l10n = context.l10n;
    final name = widget.tasbeeh.active?.label ??
        widget.tasbeeh.active?.text ??
        '';
    final confirmed = await showZadConfirm(
      context,
      title: l10n.t('tasbeeh.resetCounterConfirm'),
      body: l10n.t(
        'tasbeeh.resetCounterBody',
        args: <String, Object?>{'name': name},
      ),
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await widget.tasbeeh.resetActiveCounter();
    if (!mounted) return;
    showZadSnack(context, l10n.t('azkar.counterReset'));
  }

  Future<void> _setCustomTarget() async {
    final l10n = context.l10n;
    final controller = TextEditingController(
      text: widget.tasbeeh.activeTarget > 0
          ? widget.tasbeeh.activeTarget.toString()
          : '',
    );
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('tasbeeh.customTarget')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(hintText: l10n.t('tasbeeh.targetHint')),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(int.tryParse(controller.text.trim())),
            child: Text(l10n.t('common.save')),
          ),
        ],
      ),
    );
    controller.dispose();
    final dhikr = widget.tasbeeh.active;
    if (value == null || value <= 0 || dhikr == null) return;
    await widget.tasbeeh.setTargetFor(dhikr, value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;
    final tasbeeh = widget.tasbeeh;
    final dhikr = tasbeeh.active;

    if (dhikr == null) {
      return ZadCard(
        padding: const EdgeInsets.all(ZadSpacing.lg),
        child: EmptyView(
          icon: Icons.blur_circular_rounded,
          title: l10n.t('tasbeeh.emptyDhikr'),
          body: l10n.t('tasbeeh.pickDhikr'),
        ),
      );
    }

    final count = tasbeeh.activeCount;
    final target = tasbeeh.activeTarget;
    final laps = tasbeeh.activeLaps;
    final progress = tasbeeh.activeProgress;
    final reached = target > 0 && count >= target;

    return ZadCard(
      padding: const EdgeInsets.all(ZadSpacing.lg),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.blur_circular_rounded, size: 16, color: tokens.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.t('tasbeeh.session'),
                  style: theme.textTheme.labelMedium,
                ),
              ),
              if (laps > 0)
                ZadBadge(
                  label: l10n.t(
                    'tasbeeh.completedLaps',
                    args: <String, Object?>{'n': l10n.n(laps)},
                  ),
                  icon: Icons.repeat_rounded,
                ),
            ],
          ),
          const SizedBox(height: ZadSpacing.md),
          Semantics(
            button: true,
            label: l10n.t('tasbeeh.incrementHint'),
            child: GestureDetector(
              onTap: _count,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 208,
                height: 208,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: reached
                      ? scheme.primaryContainer.withValues(alpha: 0.22)
                      : scheme.surfaceContainerHigh,
                  border: Border.all(
                    color: reached ? tokens.gold : scheme.outlineVariant,
                    width: 2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: tokens.ambientShadow,
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    if (target > 0)
                      SizedBox(
                        width: 188,
                        height: 188,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 6,
                          backgroundColor: scheme.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            reached ? tokens.gold : scheme.primary,
                          ),
                        ),
                      ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          l10n.n(count),
                          style: zadText(
                            size: 54,
                            weight: 700,
                            family: ZadFonts.arabicUi,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          target > 0
                              ? '${l10n.t('tasbeeh.target')} ${l10n.n(target)}'
                              : '∞',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
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
            l10n.t('tasbeeh.hint'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: ZadSpacing.md),
          Wrap(
            spacing: ZadSpacing.sm,
            runSpacing: ZadSpacing.sm,
            alignment: WrapAlignment.center,
            children: <Widget>[
              for (final preset in TasbeehController.presetTargets)
                ZadFilterChip(
                  label: l10n.n(preset),
                  selected: target == preset,
                  onTap: () => tasbeeh.setTargetFor(dhikr, preset),
                ),
              ZadFilterChip(
                label: '∞',
                selected: target == 0,
                onTap: () => tasbeeh.setTargetFor(dhikr, 0),
              ),
              ZadFilterChip(
                label: l10n.t('tasbeeh.customTarget'),
                selected: target > 0 &&
                    !TasbeehController.presetTargets.contains(target),
                onTap: _setCustomTarget,
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextButton.icon(
                onPressed: count == 0 ? null : _reset,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(l10n.t('tasbeeh.resetCounter')),
              ),
            ],
          ),
          if (dhikr.isCustom) ...<Widget>[
            const ZadDivider(indent: ZadSpacing.lg),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              l10n.t('tasbeeh.counterFor', args: <String, Object?>{'name': dhikr.text}),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// The user's own adhkar with edit and delete.
class _CustomList extends StatelessWidget {
  const _CustomList({required this.tasbeeh});

  final TasbeehController tasbeeh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (tasbeeh.custom.isEmpty) {
      return ZadCard(
        padding: const EdgeInsets.all(ZadSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.star_outline_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: ZadSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.t('tasbeeh.noCustom'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.t('tasbeeh.noCustomBody'),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: <Widget>[
        for (final dhikr in tasbeeh.custom)
          Padding(
            padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
            child: _CustomTile(dhikr: dhikr, tasbeeh: tasbeeh),
          ),
      ],
    );
  }
}

class _CustomTile extends StatelessWidget {
  const _CustomTile({required this.dhikr, required this.tasbeeh});

  final CustomDhikr dhikr;
  final TasbeehController tasbeeh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final storageId = 'custom:${dhikr.id}';
    final count = tasbeeh.countForStorageId(storageId);
    final selected = tasbeeh.active?.storageId == storageId;

    return ZadCard(
      onTap: () => tasbeeh.selectDhikr(storageId),
      highlighted: selected,
      padding: const EdgeInsetsDirectional.fromSTEB(
        ZadSpacing.md,
        ZadSpacing.sm,
        ZadSpacing.sm,
        ZadSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  dhikr.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: zadText(
                    size: 15,
                    weight: 600,
                    family: ZadFonts.arabicUi,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${l10n.t('tasbeeh.target')} '
                  '${l10n.n(dhikr.target)} • '
                  '${l10n.t('tasbeeh.count')} ${l10n.n(count)}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => QuranNavigation.openDhikrEditor(
              context,
              dhikrId: dhikr.id,
            ),
            iconSize: 18,
            tooltip: l10n.t('tasbeeh.edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: () => _confirmDelete(context),
            iconSize: 18,
            tooltip: l10n.t('tasbeeh.delete'),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showZadConfirm(
      context,
      title: l10n.t('tasbeeh.deleteConfirm'),
      body: l10n.t(
        'tasbeeh.deleteConfirmBody',
        args: <String, Object?>{'name': dhikr.text},
      ),
      confirmLabel: l10n.t('tasbeeh.delete'),
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await tasbeeh.deleteCustom(dhikr.id);
    if (!context.mounted) return;
    showZadSnack(context, l10n.t('tasbeeh.deleted'));
  }
}
