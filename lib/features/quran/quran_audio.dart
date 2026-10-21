import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/quran_models.dart';
import '../../data/models/reciter.dart';
import '../../l10n/app_localizations.dart';
import '../../state/audio_controller.dart';
import '../../state/quran_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_logo.dart';

/// Opens the reciter chooser. Selecting an entry persists it through
/// [SettingsController] and, when a track is loaded, reloads that same track
/// with the new voice so the choice is immediately audible.
///
/// The reload is keyed off the controller's own state (see
/// [AudioController.reloadWith]) rather than off the screen, so it fires
/// whether the player was playing, paused or stopped — and it keeps the exact
/// ayah that was playing instead of dropping back to the start of the surah.
Future<void> showReciterPicker(BuildContext context) async {
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
  if (!context.mounted) return;
  await context.read<AudioController>().reloadWith(selected);
}

/// Opens the "listen" sheet: the one place where the user says exactly what
/// they want to hear — the whole surah, or one specific ayah.
///
/// Nothing in the reader is a permanent player bar any more. The reader shows a
/// single button ([ListenBar]); this sheet is what it opens, and once playback
/// starts the same button turns into a slim now-playing strip.
Future<void> showListenSheet(
  BuildContext context, {
  required Surah surah,
  int? initialAyah,
  bool preferAyah = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ListenSheet(
      surah: surah,
      initialAyah: initialAyah,
      preferAyah: preferAyah,
    ),
  );
}

/// The reader's single audio affordance.
///
/// Idle: one outlined "listen" button — no transport, no scrubber, no
/// reciter name taking up space the page could use. Once something is loaded
/// it collapses into a slim now-playing strip that opens the full sheet, so
/// playback is still controllable without a permanent bar.
class ListenBar extends StatelessWidget {
  const ListenBar({super.key, required this.surah, this.initialAyah});

  /// The surah the sheet opens on — the one being read.
  final Surah surah;

  /// The ayah the reader is currently on, used to pre-select it in the sheet.
  final int? initialAyah;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final audio = context.watch<AudioController>();
    void open() =>
        showListenSheet(context, surah: surah, initialAyah: initialAyah);

    if (!audio.hasTrack) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: open,
          icon: const Icon(Icons.headphones_rounded, size: 18),
          label: Text(l10n.t('audio.listen')),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.md),
            textStyle: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return _NowPlayingStrip(audio: audio, onOpen: open);
  }
}

/// Slim "what is playing" strip, shown only once a track is loaded.
class _NowPlayingStrip extends StatelessWidget {
  const _NowPlayingStrip({required this.audio, required this.onOpen});

  final AudioController audio;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final playing = audio.isPlaying;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ZadRadius.lg),
        border: Border.all(
          color: playing
              ? tokens.gold.withValues(alpha: 0.6)
              : (audio.hasError
                    ? scheme.error.withValues(alpha: 0.55)
                    : tokens.cardBorder),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              _TransportButton(audio: audio),
              Expanded(
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(ZadRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 2,
                    ),
                    child: _TrackStatus(audio: audio),
                  ),
                ),
              ),
              if (audio.hasError)
                _IconAction(
                  icon: Icons.refresh_rounded,
                  tooltip: l10n.t('audio.retry'),
                  onPressed: audio.retry,
                )
              else
                _IconAction(
                  icon: Icons.keyboard_arrow_up_rounded,
                  tooltip: l10n.t('audio.title'),
                  onPressed: onOpen,
                ),
              _IconAction(
                icon: Icons.close_rounded,
                tooltip: l10n.t('audio.dismiss'),
                onPressed: audio.dismiss,
              ),
            ],
          ),
          // Only once the platform reported a duration — before that the strip
          // stays one line tall instead of reserving space for a bar that has
          // nothing to show.
          if (audio.canSeek)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ZadRadius.full),
                child: LinearProgressIndicator(
                  value: audio.progress ?? 0,
                  minHeight: 2.5,
                  color: tokens.gold,
                  backgroundColor: tokens.cardBorder,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The full transport for whatever the controller has loaded: skip, play/pause,
/// stop, scrubber, speed and the error row.
///
/// Deliberately track-agnostic — it never decides *what* to play, so it renders
/// the same whether the loaded track is a surah or a single ayah.
class RecitationTransport extends StatelessWidget {
  const RecitationTransport({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final audio = context.watch<AudioController>();

    if (!audio.hasTrack) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(ZadSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ZadRadius.lg),
        border: Border.all(
          color: audio.isPlaying
              ? tokens.gold.withValues(alpha: 0.65)
              : (audio.hasError
                    ? scheme.error.withValues(alpha: 0.6)
                    : tokens.cardBorder),
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
                onPressed: audio.canSeek
                    ? () => audio.seekBy(-AudioController.skipStep)
                    : null,
              ),
              _TransportButton(audio: audio),
              _IconAction(
                icon: Icons.forward_10_rounded,
                tooltip: l10n.t('audio.skipForward'),
                onPressed: audio.canSeek
                    ? () => audio.seekBy(AudioController.skipStep)
                    : null,
              ),
              const SizedBox(width: ZadSpacing.xs),
              Expanded(child: _TrackStatus(audio: audio)),
              _IconAction(
                icon: Icons.stop_rounded,
                tooltip: l10n.t('audio.stop'),
                onPressed: audio.isLoading ? null : audio.stop,
              ),
            ],
          ),
          const SizedBox(height: 2),
          _ProgressRow(audio: audio),
          if (audio.hasError) ...<Widget>[
            const SizedBox(height: 6),
            _ErrorRow(audio: audio),
          ],
        ],
      ),
    );
  }
}

/// Play / pause / cancel-prepare for the loaded track.
class _TransportButton extends StatelessWidget {
  const _TransportButton({required this.audio});

  final AudioController audio;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (audio.isLoading) {
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
          minimumSize: const Size(38, 38),
          padding: EdgeInsets.zero,
        ),
        icon: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: scheme.onPrimaryContainer,
          ),
        ),
      );
    }

    final playing = audio.isPlaying;
    final replay = audio.status == RecitationStatus.completed;

    return IconButton(
      onPressed: audio.toggle,
      tooltip: playing ? l10n.t('audio.pause') : l10n.t('audio.play'),
      icon: Icon(
        playing
            ? Icons.pause_rounded
            : (replay ? Icons.replay_rounded : Icons.play_arrow_rounded),
        size: 24,
      ),
      style: IconButton.styleFrom(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        minimumSize: const Size(38, 38),
        padding: EdgeInsets.zero,
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
            l10n.t(
              'audio.speedValue',
              args: <String, Object?>{'v': l10n.digits(value)},
            ),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
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
      'download' => l10n.t('audio.errorDownload'),
      'unavailable' => who == null
          ? l10n.t('audio.errorUnavailable')
          : l10n.t(
              'audio.errorUnavailableFor',
              args: <String, Object?>{'reciter': who},
            ),
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
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: EdgeInsets.zero,
    );
  }
}

/// Track title plus live status, shared by the strip and the transport.
class _TrackStatus extends StatelessWidget {
  const _TrackStatus({required this.audio});

  final AudioController audio;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ayah = audio.ayahNumber;

    final title = audio.isAyahScope && ayah != null
        ? l10n.t(
            'audio.ayahOfSurah',
            args: <String, Object?>{
              'surah': audio.surahLabel,
              'n': l10n.n(ayah),
            },
          )
        : audio.surahLabel;

    final String status;
    if (audio.isDownloading) {
      // The download fallback knows its real progress, and a long surah runs to
      // well over 100 MB — a bare spinner there looks like a hang.
      final fraction = audio.downloadProgress ?? 0;
      status = l10n.t(
        'audio.downloading',
        args: <String, Object?>{'p': l10n.n((fraction * 100).round())},
      );
    } else if (audio.isLoading) {
      status = l10n.t('audio.loading');
    } else if (audio.isPlaying) {
      status = l10n.t('audio.nowPlaying');
    } else if (audio.status == RecitationStatus.completed) {
      status = audio.isAyahScope
          ? l10n.t('audio.ayahFinished')
          : l10n.t('audio.completed');
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
          title,
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

/// The listen sheet: scope switch, the picker for that scope, and the transport
/// for whatever is loaded.
class _ListenSheet extends StatefulWidget {
  const _ListenSheet({
    required this.surah,
    this.initialAyah,
    this.preferAyah = false,
  });

  final Surah surah;
  final int? initialAyah;
  final bool preferAyah;

  @override
  State<_ListenSheet> createState() => _ListenSheetState();
}

class _ListenSheetState extends State<_ListenSheet> {
  /// Which pane is open. Ayah mode is only the *default* when the caller asked
  /// for it — the reader's single "listen" button opens the surah pane, because
  /// "listen to this surah" is what a reader with no other context means.
  late RecitationScope _scope = widget.preferAyah
      ? RecitationScope.ayah
      : RecitationScope.surah;

  /// Whether an ayah hands over to the next one when it ends. On by default —
  /// that is what "listen to Al-Kahf from ayah 10" means to a listener — and
  /// switchable so "just this ayah" is one tap away.
  bool _continueThroughSurah = true;

  QuranReciter get _reciter =>
      context.read<SettingsController>().settings.reciter;

  /// Global index of the surah's first ayah; `null` until the dataset is
  /// loaded, in which case the ayah picker is not offered.
  int? get _firstAyahGlobal =>
      context.read<QuranController>().data?.firstAyahGlobalNumber(
        widget.surah.number,
      );

  Future<void> _playAyah(int ayahNumber) async {
    final first = _firstAyahGlobal;
    if (first == null) return;
    await context.read<AudioController>().playAyah(
      surahNumber: widget.surah.number,
      surahLabel: widget.surah.arabicName,
      ayahNumber: ayahNumber,
      ayahCount: widget.surah.ayahCount,
      firstAyahGlobal: first,
      reciter: _reciter,
      continueThroughSurah: _continueThroughSurah,
    );
  }

  Future<void> _playSurah() async {
    await context.read<AudioController>().playSurah(
      surahNumber: widget.surah.number,
      surahLabel: widget.surah.arabicName,
      reciter: _reciter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final audio = context.watch<AudioController>();
    final reciter = context.watch<SettingsController>().settings.reciter;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.76,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.md),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.t('audio.title'),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Flexible(
                    child: TextButton.icon(
                      onPressed: () => showReciterPicker(context),
                      icon: const Icon(
                        Icons.record_voice_over_outlined,
                        size: 16,
                      ),
                      label: Text(
                        reciter.nameFor(isArabic: l10n.isArabic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZadSpacing.md,
                0,
                ZadSpacing.md,
                ZadSpacing.sm,
              ),
              child: SegmentedButton<RecitationScope>(
                segments: <ButtonSegment<RecitationScope>>[
                  ButtonSegment<RecitationScope>(
                    value: RecitationScope.surah,
                    label: Text(l10n.t('audio.scopeSurah')),
                    icon: const Icon(Icons.menu_book_outlined, size: 16),
                  ),
                  ButtonSegment<RecitationScope>(
                    value: RecitationScope.ayah,
                    label: Text(l10n.t('audio.scopeAyah')),
                    icon: const Icon(Icons.format_quote_rounded, size: 16),
                  ),
                ],
                selected: <RecitationScope>{_scope},
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                onSelectionChanged: (selection) =>
                    setState(() => _scope = selection.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.md),
              child: RecitationTransport(),
            ),
            const SizedBox(height: ZadSpacing.sm),
            Expanded(
              child: _scope == RecitationScope.surah
                  ? _SurahPane(
                      surah: widget.surah,
                      onPlay: _playSurah,
                      isThisSurah:
                          audio.isSurahScope &&
                          audio.surahNumber == widget.surah.number,
                    )
                  : _AyahPane(
                      surah: widget.surah,
                      initialAyah: widget.initialAyah,
                      currentAyah: audio.isAyahScope ? audio.ayahNumber : null,
                      continueThroughSurah: _continueThroughSurah,
                      onContinueChanged: (value) {
                        setState(() => _continueThroughSurah = value);
                        // Applies to the ayah already playing, so the switch
                        // is not silently ignored until the next tap.
                        context
                            .read<AudioController>()
                            .setContinueThroughSurah(value);
                      },
                      onPlay: _playAyah,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZadSpacing.md,
                ZadSpacing.xs,
                ZadSpacing.md,
                ZadSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.t('audio.streamedNote'),
                      style: theme.textTheme.labelSmall,
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

/// Whole-surah pane: one clear action, no ambiguity about what will play.
class _SurahPane extends StatelessWidget {
  const _SurahPane({
    required this.surah,
    required this.onPlay,
    required this.isThisSurah,
  });

  final Surah surah;
  final Future<void> Function() onPlay;
  final bool isThisSurah;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZadSpacing.md,
        0,
        ZadSpacing.md,
        ZadSpacing.md,
      ),
      children: <Widget>[
        ZadCard(
          padding: const EdgeInsets.all(ZadSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                surah.fullName,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: zadText(
                  size: 20,
                  weight: 600,
                  family: ZadFonts.classical,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.t(
                  'audio.surahMeta',
                  args: <String, Object?>{
                    'n': l10n.n(surah.ayahCount),
                    'page': l10n.n(surah.startPage),
                  },
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(height: ZadSpacing.md),
              FilledButton.icon(
                onPressed: onPlay,
                icon: Icon(
                  isThisSurah ? Icons.replay_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(l10n.t('audio.playSurahFull')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                ),
              ),
              const SizedBox(height: ZadSpacing.sm),
              Text(
                l10n.t('audio.playSurahHint'),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ayah pane: the exact ayah, chosen from the surah's own text.
class _AyahPane extends StatefulWidget {
  const _AyahPane({
    required this.surah,
    required this.initialAyah,
    required this.currentAyah,
    required this.continueThroughSurah,
    required this.onContinueChanged,
    required this.onPlay,
  });

  final Surah surah;

  /// Ayah the reader was on when the sheet opened, so the list starts there
  /// instead of at 1:1 — Al-Baqarah 255 is 254 rows away from the top.
  final int? initialAyah;

  final int? currentAyah;
  final bool continueThroughSurah;
  final ValueChanged<bool> onContinueChanged;
  final Future<void> Function(int ayahNumber) onPlay;

  @override
  State<_AyahPane> createState() => _AyahPaneState();
}

class _AyahPaneState extends State<_AyahPane> {
  /// Approximate height of one dense row. Only used to place the initial
  /// scroll position, so being a few pixels off is harmless — the list clamps.
  static const double _rowExtent = 52;

  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: ((widget.initialAyah ?? 1) - 1) * _rowExtent,
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = widget.currentAyah ?? widget.initialAyah;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.md),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.playlist_play_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      l10n.t('audio.continueAfter'),
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      l10n.t('audio.continueAfterBody'),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              Switch(
                value: widget.continueThroughSurah,
                onChanged: widget.onContinueChanged,
              ),
            ],
          ),
        ),
        const ZadDivider(),
        Expanded(
          child: ListView.separated(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: widget.surah.verses.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final verse = widget.surah.verses[index];
              final isCurrent = verse.numberInSurah == widget.currentAyah;
              final isSelected = verse.numberInSurah == selected;
              return ListTile(
                dense: true,
                leading: OctagonBadge(
                  label: l10n.n(verse.numberInSurah),
                  size: 30,
                  filled: isSelected,
                ),
                title: Text(
                  _snippet(verse.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.start,
                  style: zadText(
                    size: 15,
                    weight: isSelected ? 600 : 400,
                    family: ZadFonts.arabicUi,
                    color: isSelected ? scheme.primary : scheme.onSurface,
                  ),
                ),
                trailing: Icon(
                  isCurrent
                      ? Icons.graphic_eq_rounded
                      : Icons.play_circle_outline_rounded,
                  size: 22,
                  color: isCurrent ? scheme.primary : scheme.onSurfaceVariant,
                ),
                selected: isSelected,
                onTap: () => widget.onPlay(verse.numberInSurah),
              );
            },
          ),
        ),
      ],
    );
  }

  /// First few words of the ayah — enough to recognise it, short enough to fit
  /// on one line at any text scale.
  static String _snippet(String text) {
    final words = text.split(RegExp(r'\s+'));
    if (words.length <= 8) return text;
    return '${words.take(8).join(' ')} …';
  }
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
