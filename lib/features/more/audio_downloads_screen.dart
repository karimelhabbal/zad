import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/reciter.dart';
import '../../l10n/app_localizations.dart';
import '../../state/audio_downloads_controller.dart';
import '../../state/quran_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_app_bar.dart';
import '../../widgets/zad_logo.dart';
import '../quran/quran_audio.dart';

/// Audio download manager: which surahs of the selected reciter are on the
/// device, how much space they take, and the download / delete actions.
///
/// This replaces the old Mushaf-page download screen. It manages exactly the
/// folder the player reads from, so a surah downloaded here is what plays next
/// time — offline, with no second copy on the device.
class AudioDownloadsScreen extends StatefulWidget {
  const AudioDownloadsScreen({super.key});

  @override
  State<AudioDownloadsScreen> createState() => _AudioDownloadsScreenState();
}

class _AudioDownloadsScreenState extends State<AudioDownloadsScreen> {
  @override
  void initState() {
    super.initState();
    // The cache is read after the first frame: it touches the filesystem, and
    // a scan must never delay the screen's first paint.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reciter = context.read<SettingsController>().settings.reciter;
      context.read<AudioDownloadsController>().refresh(reciter);
    });
  }

  Future<void> _changeReciter() async {
    await showReciterPicker(context);
    if (!mounted) return;
    final reciter = context.read<SettingsController>().settings.reciter;
    await context.read<AudioDownloadsController>().refresh(reciter);
  }

  Future<void> _download(int surah) async {
    final l10n = context.l10n;
    final ok = await context.read<AudioDownloadsController>().download(surah);
    if (!mounted) return;
    showZadSnack(
      context,
      l10n.t(ok ? 'audio.downloads.saved' : 'audio.downloads.failed'),
    );
  }

  Future<void> _delete(int surah) async {
    final l10n = context.l10n;
    final ok = await context.read<AudioDownloadsController>().remove(surah);
    if (!mounted) return;
    showZadSnack(
      context,
      l10n.t(ok ? 'audio.downloads.removed' : 'audio.downloads.deleteFailed'),
    );
  }

  Future<void> _deleteAll() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('audio.downloads.deleteAll')),
        content: Text(l10n.t('audio.downloads.confirmDeleteAll')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.t('audio.downloads.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AudioDownloadsController>().clearAll();
    if (!mounted) return;
    showZadSnack(context, l10n.t('audio.downloads.cleared'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final downloads = context.watch<AudioDownloadsController>();
    final reciter = context.watch<SettingsController>().settings.reciter;
    // The Quran dataset supplies the 114 surah names; it is already loaded
    // app-wide and is the same list the reader uses.
    final surahs = context.watch<QuranController>().surahs;

    return Scaffold(
      appBar: ZadAppBar(
        title: l10n.t('audio.downloads.title'),
        subtitle: l10n.t('audio.downloads.subtitle'),
        showLogo: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: surahs.isEmpty
          // Reachable only in the instant before the dataset finishes loading;
          // an empty list would otherwise read as "nothing to download".
          ? LoadingView(message: l10n.t('common.loading'))
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                ZadSpacing.md,
                ZadSpacing.md,
                ZadSpacing.md,
                MediaQuery.of(context).padding.bottom + ZadSpacing.md,
              ),
              itemCount: surahs.length + 1,
              separatorBuilder: (_, index) => index == 0
                  ? const SizedBox(height: ZadSpacing.sm)
                  : const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _Header(
                    reciter: reciter,
                    downloads: downloads,
                    onChangeReciter: _changeReciter,
                    onDeleteAll: downloads.downloadedCount == 0
                        ? null
                        : _deleteAll,
                  );
                }
                final surah = surahs[index - 1];
                return _SurahRow(
                  number: surah.number,
                  label: l10n.isArabic ? surah.arabicName : surah.englishName,
                  downloads: downloads,
                  onDownload: () => _download(surah.number),
                  onDelete: () => _delete(surah.number),
                );
              },
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.reciter,
    required this.downloads,
    required this.onChangeReciter,
    required this.onDeleteAll,
  });

  final QuranReciter reciter;
  final AudioDownloadsController downloads;
  final VoidCallback onChangeReciter;
  final VoidCallback? onDeleteAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ZadCard(
          padding: const EdgeInsets.all(ZadSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.record_voice_over_outlined,
                    size: 18,
                    color: tokens.gold,
                  ),
                  const SizedBox(width: ZadSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.t('audio.downloads.reciter'),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: onChangeReciter,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(l10n.t('audio.downloads.change')),
                  ),
                ],
              ),
              Text(
                reciter.nameFor(isArabic: l10n.isArabic),
                style: zadText(
                  size: 17,
                  weight: 700,
                  family: l10n.isArabic ? ZadFonts.arabicUi : ZadFonts.latinUi,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: ZadSpacing.sm),
              const ZadDivider(),
              const SizedBox(height: ZadSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _Stat(
                      label: l10n.t('audio.downloads.totalSize'),
                      value: l10n.t(
                        'audio.downloads.sizeMb',
                        args: <String, Object?>{
                          'v': l10n.n(
                            downloads.totalBytes / (1024 * 1024),
                          ),
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      label: l10n.t('audio.downloads.downloaded'),
                      value: l10n.t(
                        'audio.downloads.downloadedCount',
                        args: <String, Object?>{
                          'n': l10n.n(downloads.downloadedCount),
                        },
                      ),
                    ),
                  ),
                ],
              ),
              if (downloads.isScanning) ...<Widget>[
                const SizedBox(height: ZadSpacing.sm),
                Text(
                  l10n.t('audio.downloads.scanning'),
                  style: theme.textTheme.labelSmall,
                ),
              ],
              const SizedBox(height: ZadSpacing.sm),
              OutlinedButton.icon(
                onPressed: onDeleteAll,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: Text(l10n.t('audio.downloads.deleteAll')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZadSpacing.sm),
        Row(
          children: <Widget>[
            Icon(
              Icons.lock_outline_rounded,
              size: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.t('audio.downloads.note'),
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: theme.textTheme.labelSmall),
        Text(
          value,
          style: zadText(
            size: 15,
            weight: 600,
            family: ZadFonts.arabicUi,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _SurahRow extends StatelessWidget {
  const _SurahRow({
    required this.number,
    required this.label,
    required this.downloads,
    required this.onDownload,
    required this.onDelete,
  });

  final int number;
  final String label;
  final AudioDownloadsController downloads;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;

    final downloading = downloads.isDownloading(number);
    final bytes = downloads.sizeOf(number);
    final downloaded = bytes != null;

    final Widget trailing;
    if (downloading) {
      trailing = SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          value: downloads.progressOf(number),
          strokeWidth: 2.2,
          color: tokens.gold,
        ),
      );
    } else if (downloaded) {
      trailing = IconButton(
        onPressed: onDelete,
        tooltip: l10n.t('audio.downloads.delete'),
        icon: const Icon(Icons.delete_outline_rounded, size: 20),
      );
    } else {
      trailing = IconButton(
        onPressed: onDownload,
        tooltip: l10n.t('audio.downloads.download'),
        icon: const Icon(Icons.download_rounded, size: 20),
      );
    }

    final subtitle = downloading
        ? l10n.t(
            'audio.downloads.progress',
            args: <String, Object?>{
              'p': l10n.n(((downloads.progressOf(number) ?? 0) * 100).round()),
            },
          )
        : downloaded
        ? l10n.t(
            'audio.downloads.sizeMb',
            args: <String, Object?>{
              'v': l10n.n(bytes / (1024 * 1024)),
            },
          )
        : l10n.t('audio.downloads.notDownloaded');

    return ListTile(
      leading: OctagonBadge(
        label: l10n.n(number),
        size: 32,
        filled: downloaded,
      ),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: zadText(
          size: 15.5,
          weight: downloaded ? 600 : 400,
          family: ZadFonts.arabicUi,
          color: scheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.labelSmall?.copyWith(
          color: downloaded ? tokens.gold : scheme.onSurfaceVariant,
        ),
      ),
      trailing: trailing,
      onTap: downloading || downloaded ? null : onDownload,
    );
  }
}
