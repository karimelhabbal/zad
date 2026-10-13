import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';
import '../../state/tasbeeh_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_app_bar.dart';

/// Create or edit a custom dhikr for the digital tasbeeh.
///
/// Pass [dhikrId] to edit an existing entry; leave it `null` to create a new
/// one. Validation happens before anything is persisted, so an empty text or a
/// non-positive target can never be stored.
class DhikrEditorScreen extends StatefulWidget {
  const DhikrEditorScreen({super.key, this.dhikrId});

  final String? dhikrId;

  @override
  State<DhikrEditorScreen> createState() => _DhikrEditorScreenState();
}

class _DhikrEditorScreenState extends State<DhikrEditorScreen> {
  static const List<String> _suggestions = <String>[
    'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
    'سُبْحَانَ اللَّهِ الْعَظِيمِ',
    'الْحَمْدُ لِلَّهِ',
    'اللَّهُ أَكْبَرُ',
    'لَا إِلَٰهَ إِلَّا اللَّهُ',
    'أَسْتَغْفِرُ اللَّهَ',
    'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
    'اللَّهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ',
  ];

  final TextEditingController _text = TextEditingController();
  final TextEditingController _customTarget = TextEditingController();

  int _target = 33;
  bool _useCustomTarget = false;
  String? _error;
  bool _saving = false;
  bool _initialised = false;

  bool get _isEditing => widget.dhikrId != null;

  @override
  void dispose() {
    _text.dispose();
    _customTarget.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final id = widget.dhikrId;
    if (id == null) return;
    final existing = context.read<TasbeehController>().customById(id);
    if (existing == null) return;
    _text.text = existing.text;
    final isPreset = TasbeehController.presetTargets.contains(existing.target);
    _useCustomTarget = !isPreset;
    _target = existing.target;
    if (_useCustomTarget) {
      _customTarget.text = existing.target.toString();
    }
  }

  int? get _resolvedTarget {
    if (!_useCustomTarget) return _target;
    return int.tryParse(_customTarget.text.trim());
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;
    final tasbeeh = context.read<TasbeehController>();
    final text = _text.text.trim();
    final target = _resolvedTarget;

    final validation = tasbeeh.validate(text: text, target: target);
    if (validation != null) {
      setState(() => _error = l10n.t(validation));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = _isEditing
        ? await tasbeeh.updateCustom(
            id: widget.dhikrId!,
            text: text,
            target: target,
          )
        : await tasbeeh.addCustom(text: text, target: target);

    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      setState(() => _error = l10n.t(error));
      return;
    }
    showZadSnack(
      context,
      l10n.t(_isEditing ? 'tasbeeh.updated' : 'tasbeeh.saved'),
    );
    Navigator.of(context).maybePop();
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final id = widget.dhikrId;
    if (id == null) return;
    final confirmed = await showZadConfirm(
      context,
      title: l10n.t('tasbeeh.deleteConfirm'),
      body: l10n.t(
        'tasbeeh.deleteConfirmBody',
        args: <String, Object?>{'name': _text.text.trim()},
      ),
      confirmLabel: l10n.t('tasbeeh.delete'),
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await context.read<TasbeehController>().deleteCustom(id);
    if (!mounted) return;
    showZadSnack(context, l10n.t('tasbeeh.deleted'));
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;

    return Scaffold(
      appBar: ZadAppBar(
        title: l10n.t(_isEditing ? 'tasbeeh.editDhikr' : 'tasbeeh.addDhikr'),
        subtitle: l10n.t('tasbeeh.dhikrSaved'),
        showLogo: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_forward_rounded),
          tooltip: l10n.t('common.close'),
        ),
        actions: <Widget>[
          if (_isEditing)
            ZadIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: l10n.t('tasbeeh.delete'),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ZadSpacing.md,
          ZadSpacing.md,
          ZadSpacing.md,
          ZadSpacing.xl,
        ),
        children: <Widget>[
          SectionHeader(
            title: l10n.t('tasbeeh.dhikrText'),
            icon: Icons.edit_note_rounded,
          ),
          const SizedBox(height: ZadSpacing.sm),
          TextField(
            controller: _text,
            autofocus: !_isEditing,
            maxLines: 4,
            minLines: 3,
            textDirection: TextDirection.rtl,
            style: zadText(
              size: 20,
              weight: 400,
              height: 1.9,
              family: ZadFonts.classical,
              color: scheme.onSurface,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              hintText: l10n.t('tasbeeh.dhikrTextHint'),
              errorText: _error,
            ),
          ),
          const SizedBox(height: ZadSpacing.sm),
          Text(
            l10n.t('tasbeeh.customHint'),
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: ZadSpacing.md),
          Wrap(
            spacing: ZadSpacing.sm,
            runSpacing: ZadSpacing.sm,
            children: <Widget>[
              for (final suggestion in _suggestions)
                ActionChip(
                  label: Text(
                    suggestion,
                    style: zadText(
                      size: 12,
                      weight: 500,
                      family: ZadFonts.classical,
                      color: scheme.onSurface,
                    ),
                  ),
                  onPressed: () {
                    _text.text = suggestion;
                    if (_error != null) setState(() => _error = null);
                  },
                ),
            ],
          ),
          const SizedBox(height: ZadSpacing.lg),
          SectionHeader(
            title: l10n.t('tasbeeh.targetCount'),
            icon: Icons.flag_outlined,
          ),
          const SizedBox(height: ZadSpacing.sm),
          Wrap(
            spacing: ZadSpacing.sm,
            runSpacing: ZadSpacing.sm,
            children: <Widget>[
              for (final preset in TasbeehController.presetTargets)
                ZadFilterChip(
                  label: l10n.n(preset),
                  selected: !_useCustomTarget && _target == preset,
                  onTap: () => setState(() {
                    _useCustomTarget = false;
                    _target = preset;
                    _error = null;
                  }),
                ),
              ZadFilterChip(
                label: l10n.t('tasbeeh.customTarget'),
                selected: _useCustomTarget,
                onTap: () => setState(() {
                  _useCustomTarget = true;
                  _error = null;
                }),
              ),
            ],
          ),
          if (_useCustomTarget) ...<Widget>[
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: _customTarget,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                labelText: l10n.t('tasbeeh.customTarget'),
                hintText: l10n.t('tasbeeh.targetHint'),
                prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
              ),
            ),
          ],
          const SizedBox(height: ZadSpacing.lg),
          ZadCard(
            padding: const EdgeInsets.all(ZadSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.info_outline_rounded, size: 17, color: tokens.gold),
                const SizedBox(width: ZadSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.t('tasbeeh.builtInNote'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZadSpacing.lg),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(l10n.t('tasbeeh.save')),
            ),
          ),
        ],
      ),
    );
  }
}
