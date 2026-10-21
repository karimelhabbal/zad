import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_app_bar.dart';

/// Credits for the Mushaf text and fonts, and the app's data policy.
///
/// Everything shown here is a statement of fact about the build: the glyphs
/// come from the King Fahd Complex masters, the app works offline, and there is
/// no advertising or tracking code anywhere in it.
class MushafAboutScreen extends StatelessWidget {
  const MushafAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;

    return Scaffold(
      appBar: ZadAppBar(
        title: l10n.t('quran.aboutMushaf'),
        subtitle: l10n.t('quran.edition'),
        showLogo: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_forward_rounded),
          tooltip: l10n.t('common.close'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ZadSpacing.md,
          ZadSpacing.md,
          ZadSpacing.md,
          ZadSpacing.xl,
        ),
        children: <Widget>[
          ZadCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.menu_book_rounded,
                      size: 20,
                      color: tokens.gold,
                    ),
                    const SizedBox(width: ZadSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.t('mushaf.aboutFontTitle'),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZadSpacing.sm),
                Text(
                  l10n.t('mushaf.aboutFontBody'),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: ZadSpacing.sm),
                Text(
                  l10n.t('mushaf.aboutEdition'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: ZadSpacing.sm),
                const ZadDivider(),
                const SizedBox(height: ZadSpacing.sm),
                Text(
                  l10n.t('mushaf.aboutPackage'),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          ZadCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.verified_user_outlined,
                      size: 20,
                      color: tokens.gold,
                    ),
                    const SizedBox(width: ZadSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.t('mushaf.aboutTextTitle'),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZadSpacing.sm),
                Text(
                  l10n.t('mushaf.aboutTextBody'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          ZadCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.lock_outline_rounded, size: 20, color: tokens.gold),
                    const SizedBox(width: ZadSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.t('mushaf.aboutPrivacyTitle'),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZadSpacing.sm),
                Text(
                  l10n.t('mushaf.aboutPrivacyBody'),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: ZadSpacing.sm),
                Wrap(
                  spacing: ZadSpacing.sm,
                  runSpacing: ZadSpacing.sm,
                  children: <Widget>[
                    ZadBadge(
                      label: l10n.t('mushaf.aboutNoAds'),
                      icon: Icons.block_outlined,
                    ),
                    ZadBadge(
                      label: l10n.t('quran.offlineBadge'),
                      icon: Icons.cloud_off_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          ZadCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.t('mushaf.aboutLicenceTitle'),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: ZadSpacing.sm),
                Text(
                  l10n.t('mushaf.aboutLicenceBody'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: ZadSpacing.lg),
          Center(
            child: Text(
              l10n.t('app.versionNote'),
              textAlign: TextAlign.center,
              style: zadText(
                size: 11,
                family: ZadFonts.arabicUi,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
