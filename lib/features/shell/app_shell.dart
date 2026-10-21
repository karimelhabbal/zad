import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderProxyBox;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';
import '../azkar/azkar_screen.dart';
import '../home/home_screen.dart';
import '../more/more_screen.dart';
import '../quran/quran_screen.dart';
import '../tasbeeh/tasbeeh_screen.dart';

/// Primary navigation shell: five destinations in a floating, frosted dock.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;

  /// The dock's real height, measured after layout.
  ///
  /// It depends on the text scale and the locale, so measuring is more reliable
  /// than a hard-coded constant that would silently drift. It lives in a
  /// [ValueNotifier] rather than in `setState` so a measurement pass rebuilds
  /// only the `MediaQuery` that publishes the clearance — not all five tabs.
  final ValueNotifier<double> _dockHeight = ValueNotifier<double>(0);

  /// Lets any screen switch the active tab (e.g. the home quick actions).
  void select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  static AppShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<AppShellState>();

  @override
  void dispose() {
    _dockHeight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final destinations = <_Destination>[
      _Destination(
        label: l10n.t('nav.home'),
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      _Destination(
        label: l10n.t('nav.quran'),
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book_rounded,
      ),
      _Destination(
        label: l10n.t('nav.azkar'),
        icon: Icons.auto_awesome_outlined,
        activeIcon: Icons.auto_awesome,
      ),
      _Destination(
        label: l10n.t('nav.tasbeeh'),
        icon: Icons.radio_button_unchecked,
        activeIcon: Icons.adjust,
      ),
      _Destination(
        label: l10n.t('nav.more'),
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view_rounded,
      ),
    ];

    return Scaffold(
      extendBody: true,
      // The dock floats over the body. Instead of every screen inventing its own
      // bottom padding, the shell publishes the exact clearance as
      // `MediaQuery.padding.bottom`, so scrollables inside the shell reach
      // their last item while staying clear of both the dock and the Android
      // navigation bar. (Scaffold zeroes the body's bottom padding whenever a
      // bottomNavigationBar exists, which is what hid the overlap.)
      body: ValueListenableBuilder<double>(
        valueListenable: _dockHeight,
        builder: (context, dockHeight, child) => MediaQuery(
          data: media.copyWith(
            padding: media.padding.copyWith(
              bottom: dockHeight + media.padding.bottom,
            ),
          ),
          child: child!,
        ),
        // Rebuilt only when the shell rebuilds (tab change), never when the
        // dock's height changes — that is the whole point of passing it here.
        child: IndexedStack(
          index: _index,
          children: const <Widget>[
            HomeScreen(),
            QuranScreen(),
            AzkarScreen(),
            TasbeehScreen(),
            MoreScreen(),
          ],
        ),
      ),
      bottomNavigationBar: _MeasuredSize(
        onChange: (size) => _dockHeight.value = size.height,
        child: _SanctuaryNavigationBar(
          destinations: destinations,
          selectedIndex: _index,
          onSelected: select,
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Reports its child's laid-out size, once per actual change.
///
/// The previous approach measured a `GlobalKey` from a post-frame callback
/// scheduled inside `build`, which queued work on **every** rebuild of the
/// shell. This reports from `performLayout` instead and only when the size
/// really changed, so a settled screen schedules nothing at all.
class _MeasuredSize extends SingleChildRenderObjectWidget {
  const _MeasuredSize({required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  _MeasuredSizeBox createRenderObject(BuildContext context) =>
      _MeasuredSizeBox(onChange);

  @override
  void updateRenderObject(BuildContext context, _MeasuredSizeBox renderObject) {
    renderObject.onChange = onChange;
  }
}

class _MeasuredSizeBox extends RenderProxyBox {
  _MeasuredSizeBox(this.onChange);

  ValueChanged<Size> onChange;

  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final laidOut = size;
    if (laidOut == _reported) return;
    _reported = laidOut;
    // Deferred: the listener rebuilds a MediaQuery, which cannot happen while
    // the tree is laying out.
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(laidOut));
  }
}

class _SanctuaryNavigationBar extends StatelessWidget {
  const _SanctuaryNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // Full inset, not a fraction of it: with three-button navigation the bar is
    // ~48dp tall, and lifting the dock by only 40% of that left the bottom
    // third of the dock underneath the system buttons.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        ZadSpacing.md,
        0,
        ZadSpacing.md,
        bottomInset + ZadSpacing.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.navigationFill,
          borderRadius: BorderRadius.circular(ZadRadius.xxl),
          border: Border.all(color: tokens.cardBorder),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: tokens.ambientShadow,
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ZadRadius.xxl),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ZadSpacing.sm,
              vertical: 6,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _NavItem(
                      destination: destinations[i],
                      selected: i == selectedIndex,
                      onTap: () => onSelected(i),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZadRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                selected ? destination.activeIcon : destination.icon,
                size: 22,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 3),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: zadText(
                  size: 10,
                  weight: selected ? 600 : 500,
                  family: Theme.of(context).textTheme.labelSmall?.fontFamily,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              // Muted gold dot indicator for the active destination.
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 3,
                width: selected ? 14 : 0,
                decoration: BoxDecoration(
                  color: tokens.gold,
                  borderRadius: BorderRadius.circular(ZadRadius.full),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
