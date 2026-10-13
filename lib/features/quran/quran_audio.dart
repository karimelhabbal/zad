import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/reciter.dart';
import '../../l10n/app_localizations.dart';
import '../../state/audio_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_logo.dart';

/// Opens the reciter chooser. Selecting an entry persists it through
/// [SettingsController] and, when a surah is already loaded, restarts that
/// surah with the new voice so the choice is immediately audible.
///
/// This is the fix for "I picked a reciter and nothing changed": the restart is
/// keyed off `hasTrack`, so it fires whether the player was playing, paused or
/// stopped — previously a paused player resumed the *old* reciter's file.
Future<void> showReciterPicker(
  BuildContext context, {
  int? restartSurah,
  String? restartLabel,
}) async {
  final selected = await showModalBottomSheet<QuranReciter>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => const _ReciterSheet(),
  );
  if (selected == null || !context.mounted) return;

  final settings = context.read<SettingsController>();
  if (settings.settings.reciterId == selected.id) return;
  await settings.setReciter(selected);

  if (restartSurah != null && context.mounted) {
    await context.read<AudioController>().playSurah(
      surahNumber: restartSurah,
      surahLabel: restartLabel ?? '',
      reciter: selected,
    );
  }
}

/// Bottom sheet with the full recitation controls for one surah.
///
/// Used by the Quran hub so audio is reachable without spending permanent
/// vertical space on a player bar.
Future<void> showRecitationSheet(
  BuildContext context, {
  required int surahNumber,
  required String surahLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ZadSpacing.md,
          0,
          ZadSpacing.md,
          ZadSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              AppLocalizations.of(sheetContext).t('audio.title'),
              style: Theme.of(sheetContext).textTheme.titleSmall,
            ),
            const SizedBox(height: ZadSpacing.sm),
            RecitationBar(surahNumber: surahNumber, surahLabel: surahLabel),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              AppLocalizations.of(sheetContext).t('audio.verifiedSource'),
              style: Theme.of(sheetContext).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Searchable reciter chooser.
///
/// The catalogue runs to well over a hundred verified editions, so a plain
/// list is no longer usable — hence the filter field. Arabic queries are
/// normalised by [QuranReciters.search], so a name typed without harakat still
/// finds its reciter.
class _ReciterSheet extends StatefulWidget {
  const _ReciterSheet();

  @override
  State<_ReciterSheet> createState() => _ReciterSheetState();
}

class _ReciterSheetState extends State<_ReciterSheet> {
  final TextEditingController _controller = TextEditingController();
  List<QuranReciter> _results = QuranReciters.all;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _results = QuranReciters.search(value));
  }

  void _clear() {
    _controller.clear();
    setState(() => _results = QuranReciters.all);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = context.watch<SettingsController>();
    final current = settings.settings.reciter;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.md),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.t('audio.selectReciter'),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  ZadBadge(
                    label: l10n.t(
                      'audio.reciterCount',
                      args: <String, Object?>{
                        'n': l10n.n(QuranReciters.all.length),
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.md),
              child: Text(
                l10n.t('audio.streamedNote'),
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: ZadSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.md),
              child: TextField(
                controller: _controller,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.t('audio.searchReciter'),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          tooltip: l10n.t('common.clear'),
                          onPressed: _clear,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ZadRadius.md),
                  ),
                ),
              ),
            ),
            const SizedBox(height: ZadSpacing.sm),
            const ZadDivider(),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(ZadSpacing.lg),
                        child: Text(
                          l10n.t('audio.noReciterMatches'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final reciter = _results[index];
                        final isCurrent = reciter.id == current.id;
                        return ListTile(
                          leading: OctagonBadge(
                            label: l10n.n(
                              QuranReciters.all.indexOf(reciter) + 1,
                            ),
                            size: 32,
                            filled: isCurrent,
                          ),
                          title: Text(
                            reciter.nameFor(isArabic: l10n.isArabic),
                            style: zadText(
                              size: 16,
                              weight: isCurrent ? 700 : 500,
                              family: l10n.isArabic
                                  ? ZadFonts.arabicUi
                                  : ZadFonts.latinUi,
                              color: scheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            l10n.isArabic
                                ? reciter.englishName
                                : reciter.arabicName,
                            style: theme.textTheme.labelSmall,
                          ),
                          trailing: isCurrent
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  size: 20,
                                  color: context.tokens.gold,
                                )
                              : null,
                          selected: isCurrent,
                          onTap: () => Navigator.of(context).pop(reciter),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact recitation bar used by the text reader and the Quran hub.
///
/// Every control maps to a real [AudioController] command — nothing here is a
/// decorative button.
class RecitationBar extends StatelessWidget {
  const RecitationBar({
    super.key,
    required this.surahNumber,
    required this.surahLabel,
  });

  /// The surah this bar controls. Pressing play streams exactly this surah.
  final int surahNumber;
  final String surahLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;
    final audio = context.watch<AudioController>();
    final settings = context.watch<SettingsController>();
    final reciter = settings.settings.reciter;

    // The bar is "live" only when the controller is on this exact surah.
    final isThisSurah = audio.surahNumber == surahNumber;
    final live = isThisSurah && audio.hasTrack;
    final failed = isThisSurah && audio.hasError;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        ZadSpacing.sm,
        ZadSpacing.sm,
        ZadSpacing.sm,
        ZadSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ZadRadius.lg),
        border: Border.all(
          color: isThisSurah && audio.isPlaying
              ? tokens.gold.withValues(alpha: 0.65)
              : (failed ? scheme.error.withValues(alpha: 0.6) : tokens.cardBorder),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              _IconAction(
                icon: Icons.replay_10_rounded,
                tooltip: l10n.t('audio.skipBack'),
                onPressed: live && audio.canSeek
                    ? () => audio.seekBy(-AudioController.skipStep)
                    : null,
              ),
              _TransportButton(
                audio: audio,
                surahNumber: surahNumber,
                surahLabel: surahLabel,
                reciter: reciter,
              ),
              _IconAction(
                icon: Icons.forward_10_rounded,
                tooltip: l10n.t('audio.skipForward'),
                onPressed: live && audio.canSeek
                    ? () => audio.seekBy(AudioController.skipStep)
                    : null,
              ),
              const SizedBox(width: ZadSpacing.xs),
              Expanded(
                child: _StatusText(
                  audio: audio,
                  isThisSurah: isThisSurah,
                  reciter: reciter,
                ),
              ),
              if (live)
                _IconAction(
                  icon: Icons.stop_rounded,
                  tooltip: l10n.t('audio.stop'),
                  onPressed: audio.isLoading ? null : audio.stop,
                ),
              _IconAction(
                icon: Icons.record_voice_over_outlined,
                tooltip: l10n.t('audio.selectReciter'),
                onPressed: () => showReciterPicker(
                  context,
                  restartSurah: live ? surahNumber : null,
                  restartLabel: surahLabel,
                ),
              ),
            ],
          ),
          // The progress row is always present once a surah is loaded. When the
          // platform has not reported a duration yet it renders as an
          // indeterminate bar rather than disappearing, so "is it doing
          // anything?" is never a question the user has to ask.
          if (live) ...<Widget>[
            const SizedBox(height: 2),
            _ProgressRow(audio: audio),
          ],
          if (failed) ...<Widget>[
            const SizedBox(height: 6),
            _ErrorRow(audio: audio),
          ],
        ],
      ),
    );
  }
}

/// Position, scrubber and duration — or an indeterminate bar until the
/// duration is known.
class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.audio});

  final AudioController audio;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final label = theme.textTheme.labelSmall;

    if (!audio.canSeek) {
      return Row(
        children: <Widget>[
          Text(l10n.duration(audio.position), style: label),
          const SizedBox(width: ZadSpacing.sm),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ZadRadius.full),
              child: LinearProgressIndicator(
                minHeight: 3,
                color: tokens.gold,
                backgroundColor: tokens.cardBorder,
              ),
            ),
          ),
          const SizedBox(width: ZadSpacing.sm),
          Text(l10n.t('audio.durationUnknown'), style: label),
          const SizedBox(width: ZadSpacing.xs),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Text(l10n.duration(audio.position), style: label),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              activeTrackColor: tokens.gold,
              thumbColor: tokens.gold,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: audio.progress ?? 0,
              onChanged: (value) => audio.seek(
                Duration(
                  milliseconds: (audio.duration.inMilliseconds * value).round(),
                ),
              ),
            ),
          ),
        ),
        Text(l10n.duration(audio.duration), style: label),
        const SizedBox(width: ZadSpacing.xs),
        _SpeedButton(audio: audio),
      ],
    );
  }
}

/// Cycles the playback rate. A real platform call, not a label.
class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.audio});

  final AudioController audio;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final value = audio.speed == audio.speed.roundToDouble()
        ? audio.speed.toStringAsFixed(0)
        : audio.speed.toString();

    return Tooltip(
      message: l10n.t('audio.speed'),
      child: InkWell(
        borderRadius: BorderRadius.circular(ZadRadius.sm),
        onTap: audio.cycleSpeed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            l10n.t('audio.speedValue', args: <String, Object?>{
              'v': l10n.digits(value),
            }),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Failure message plus a retry, so a dead stream is never a silent dead button.
class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.audio});

  final AudioController audio;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Icon(Icons.error_outline_rounded, size: 16, color: scheme.error),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _errorText(l10n, audio),
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.error),
          ),
        ),
        TextButton(
          onPressed: audio.retry,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.sm),
          ),
          child: Text(l10n.t('audio.retry')),
        ),
      ],
    );
  }

  /// Names the reciter that failed, because with a catalogue this large the
  /// most useful thing the message can say is *whose* recording is missing.
  static String _errorText(AppLocalizations l10n, AudioController audio) {
    final who = audio.failedReciter?.nameFor(isArabic: l10n.isArabic);
    return switch (audio.error) {
      'timeout' => l10n.t('audio.errorTimeout'),
      'network' => l10n.t('audio.errorNetwork'),
      'unavailable' => who == null
          ? l10n.t('audio.errorUnavailable')
          : l10n.t('audio.errorUnavailableFor', args: <String, Object?>{
              'reciter': who,
            }),
      _ => l10n.t('audio.errorPlayback'),
    };
  }
}

/// Small square icon button sized to match the transport row.
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.audio,
    required this.surahNumber,
    required this.surahLabel,
    required this.reciter,
  });

  final AudioController audio;
  final int surahNumber;
  final String surahLabel;
  final QuranReciter reciter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isThisSurah = audio.surahNumber == surahNumber;

    if (isThisSurah && audio.isLoading) {
      // A spinner that is *also* a button. Preparing a surah can take seconds
      // on a slow connection — and up to the platform's prepare timeout if the
      // stream stalls — so the user must be able to change their mind instead
      // of being locked behind an unresponsive spinner. Tapping cancels the
      // load ([AudioController.toggle] maps `loading` to `stop`).
      return IconButton(
        onPressed: audio.toggle,
        tooltip: l10n.t('audio.cancelPrepare'),
        style: IconButton.styleFrom(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          minimumSize: const Size(40, 40),
          padding: EdgeInsets.zero,
        ),
        icon: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: scheme.onPrimaryContainer,
          ),
        ),
      );
    }

    final playing = isThisSurah && audio.isPlaying;
    final needsStart = !isThisSurah || !audio.hasTrack;

    return IconButton(
      onPressed: () {
        if (needsStart) {
          audio.playSurah(
            surahNumber: surahNumber,
            surahLabel: surahLabel,
            reciter: reciter,
          );
        } else {
          audio.toggle();
        }
      },
      icon: Icon(
        playing
            ? Icons.pause_rounded
            : (needsStart || audio.isPaused ||
                      audio.status == RecitationStatus.completed
                  ? Icons.play_arrow_rounded
                  : Icons.replay_rounded),
        size: 24,
      ),
      tooltip: playing ? l10n.t('audio.pause') : l10n.t('audio.play'),
      style: IconButton.styleFrom(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({
    required this.audio,
    required this.isThisSurah,
    required this.reciter,
  });

  final AudioController audio;
  final bool isThisSurah;
  final QuranReciter reciter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // While a surah is loaded the controller's reciter is authoritative — that
    // is what is actually being streamed, even if settings changed since.
    final activeReciter = isThisSurah ? audio.reciter : reciter;

    final String status;
    if (!isThisSurah || !audio.hasTrack) {
      status = l10n.t('audio.listenSurah');
    } else if (audio.isLoading) {
      status = l10n.t('audio.loading');
    } else if (audio.isPlaying) {
      status = l10n.t('audio.nowPlaying');
    } else if (audio.status == RecitationStatus.completed) {
      status = l10n.t('audio.completed');
    } else if (audio.hasError) {
      status = l10n.t('audio.error');
    } else {
      status = l10n.t('audio.resume');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          activeReciter.nameFor(isArabic: l10n.isArabic),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: zadText(
            size: 13.5,
            weight: 600,
            family: l10n.isArabic ? ZadFonts.arabicUi : ZadFonts.latinUi,
            color: scheme.onSurface,
          ),
        ),
        Text(
          status,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: audio.hasError ? scheme.error : scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
