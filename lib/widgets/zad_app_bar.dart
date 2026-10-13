import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../l10n/app_localizations.dart';
import 'zad_logo.dart';

/// The shared top bar from the approved design: the Zad mark on the leading
/// edge, the screen title centred, and contextual actions on the trailing edge.
class ZadAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ZadAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.showLogo = true,
    this.leading,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showLogo;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppBar(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      centerTitle: false,
      leadingWidth: showLogo ? 60 : null,
      leading: leading,
      titleSpacing: 0,
      title: Row(
        children: <Widget>[
          if (showLogo)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: ZadSpacing.md),
              child: const ZadLogo(size: 34, elevated: false),
            ),
          const SizedBox(width: ZadSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(fontSize: 19),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: <Widget>[
        ...actions,
        const SizedBox(width: ZadSpacing.sm),
      ],
      bottom: bottom,
    );
  }
}

/// A rounded icon button used in the app bars.
class ZadIconButton extends StatelessWidget {
  const ZadIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.badge,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 21),
          tooltip: tooltip,
          style: IconButton.styleFrom(
            backgroundColor: scheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ZadRadius.md),
            ),
            minimumSize: const Size(38, 38),
            padding: EdgeInsets.zero,
          ),
        ),
        if (badge != null)
          PositionedDirectional(
            top: -2,
            end: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: context.tokens.gold,
                borderRadius: BorderRadius.circular(ZadRadius.full),
              ),
              child: Text(
                badge!,
                style: zadText(size: 9, weight: 700, color: Colors.black87),
              ),
            ),
          ),
      ],
    );
    return button;
  }
}

/// Small helper used by several screens to show a transient message.
void showZadSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(ZadSpacing.md),
      ),
    );
}

/// Confirmation dialog styled to match the design system.
Future<bool> showZadConfirm(
  BuildContext context, {
  required String title,
  required String body,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel ?? l10n.t('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          child: Text(confirmLabel ?? l10n.t('tasbeeh.confirm')),
        ),
      ],
    ),
  );
  return result ?? false;
}
