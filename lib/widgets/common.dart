import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../l10n/app_localizations.dart';

/// An elevated reading surface: warm card, 16px radius and a hairline gold
/// border that catches the light — straight from the design system.
class ZadCard extends StatelessWidget {
  const ZadCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ZadSpacing.md),
    this.onTap,
    this.highlighted = false,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool highlighted;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.primaryContainer
            : (isDark
                  ? scheme.surfaceContainerHigh
                  : scheme.surfaceContainerLowest),
        borderRadius: BorderRadius.circular(ZadRadius.xl),
        border: Border.all(
          color: highlighted
              ? tokens.gold.withValues(alpha: 0.5)
              : tokens.cardBorder,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tokens.ambientShadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Section title with an optional trailing action, right-aligned for RTL.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.action,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: ZadSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.titleMedium),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

/// Horizontal pill filter used for adhkar filters and Quran tabs.
class ZadFilterChip extends StatelessWidget {
  const ZadFilterChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(ZadRadius.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZadRadius.full),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ZadSpacing.md,
            vertical: ZadSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZadRadius.full),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : scheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 6),
                Text(
                  trailing!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Gold gradient hairline used to separate devotional content.
class ZadDivider extends StatelessWidget {
  const ZadDivider({super.key, this.height = 1, this.indent = 0});

  final double height;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              tokens.gold.withValues(alpha: 0),
              tokens.gold.withValues(alpha: 0.55),
              tokens.gold.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact labelled statistic, used on the home dashboard.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ZadCard(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.md,
        vertical: ZadSpacing.sm + 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 15, color: accent ?? scheme.primary),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                value,
                style: zadText(
                  size: 20,
                  weight: 700,
                  family: ZadFonts.arabicUi,
                  color: accent ?? scheme.onSurface,
                ),
              ),
              if (unit != null) ...<Widget>[
                const SizedBox(width: 4),
                Text(unit!, style: theme.textTheme.labelSmall),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Centered loading indicator with a message.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: ZadSpacing.md),
            Text(message!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Empty state with an icon, title and optional body + action.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.body,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? body;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                shape: BoxShape.circle,
                border: Border.all(color: context.tokens.cardBorder),
              ),
              child: Icon(icon, size: 28, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: ZadSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (body != null) ...<Widget>[
              const SizedBox(height: ZadSpacing.sm),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: ZadSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with a retry action.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    this.title,
    this.body,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  final String? title;
  final String? body;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyView(
      icon: icon,
      title: title ?? l10n.t('common.error'),
      body: body,
      action: onRetry == null
          ? null
          : FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.t('common.retry')),
            ),
    );
  }
}

/// State shown when a permission is required, with a shortcut to settings.
class PermissionView extends StatelessWidget {
  const PermissionView({
    super.key,
    required this.title,
    required this.body,
    this.onPrimary,
    this.primaryLabel,
    this.onSecondary,
    this.secondaryLabel,
    this.icon = Icons.location_off_outlined,
  });

  final String title;
  final String body;
  final VoidCallback? onPrimary;
  final String? primaryLabel;
  final VoidCallback? onSecondary;
  final String? secondaryLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: icon,
      title: title,
      body: body,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (onPrimary != null)
            FilledButton(
              onPressed: onPrimary,
              child: Text(primaryLabel ?? ''),
            ),
          if (onSecondary != null) ...<Widget>[
            const SizedBox(height: ZadSpacing.sm),
            OutlinedButton(
              onPressed: onSecondary,
              child: Text(secondaryLabel ?? ''),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small badge used for statuses such as "verified" or "offline".
class ZadBadge extends StatelessWidget {
  const ZadBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
  });

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? context.tokens.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(ZadRadius.full),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: tint),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A settings row with a leading icon, title, optional subtitle and trailing
/// widget.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ZadSpacing.md,
          vertical: ZadSpacing.sm + 4,
        ),
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(ZadRadius.md),
                ),
                child: Icon(icon, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: ZadSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleSmall),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: ZadSpacing.sm),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
