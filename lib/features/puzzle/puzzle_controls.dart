import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../content/definitions/item_def.dart';
import '../../content/definitions/puzzle_def.dart';
import '../../core/design/manor_tokens.dart';
import '../../core/design/tokens.dart';
import '../../core/painting/item_icons.dart';
import '../../core/painting/puzzle_art.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../core/widgets/spectral_button.dart';
import '../../domain/puzzles/puzzle_evaluator.dart';

/// Starting input for a puzzle, taken from its content definition.
PuzzleInput initialInputFor(PuzzleDef def) {
  final c = def.config;
  return switch (def.kind) {
    PuzzleKind.sequence => const SequenceInput([]),
    PuzzleKind.cipher => const CipherInput(''),
    PuzzleKind.dial => DialInput(c['start'] as int),
    PuzzleKind.combine => const PlacedItemsInput({}),
    PuzzleKind.useItem => const UseItemInput(''),
    PuzzleKind.clock => const ClockInput(12, 0),
    PuzzleKind.gears => GearsInput(
      List.filled((c['target'] as List).length, 0),
    ),
  };
}

String _title(String id) =>
    id.isEmpty ? id : id[0].toUpperCase() + id.substring(1);

/// A square, labeled, tappable tile used by several controls.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.child,
    required this.onTap,
    this.selected = false,
    this.semanticLabel,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = ManorTokens.of(context);
    final theme = Theme.of(context);
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: PressableScale(
        onTap: onTap,
        enforceMinSize: false,
        semanticLabel: semanticLabel ?? label,
        child: Container(
          width: 92,
          height: 96,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: tokens.panelFill,
            border: Border.all(
              color: selected
                  ? AppColors.goldLight
                  : tokens.panelBorder.withValues(alpha: 0.5),
              width: selected ? 2.4 : 1,
            ),
            boxShadow: selected ? AppGlow.gold(0.7) : null,
          ),
          child: ExcludeSemantics(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: Center(child: child)),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textPrimary,
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

/// A round +/- style stepper button.
class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.semantic,
    required this.onTap,
  });

  final String label;
  final String semantic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ManorTokens.of(context);
    final theme = Theme.of(context);
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: PressableScale(
        onTap: onTap,
        semanticLabel: semantic,
        borderRadius: 28,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.panelFill,
            border: Border.all(color: tokens.panelBorder, width: 1.5),
          ),
          child: ExcludeSemantics(
            child: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.goldLight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- sequence

class SequenceControl extends StatefulWidget {
  const SequenceControl({
    super.key,
    required this.def,
    required this.onChanged,
    required this.enabled,
  });

  final PuzzleDef def;
  final ValueChanged<PuzzleInput> onChanged;
  final bool enabled;

  @override
  State<SequenceControl> createState() => _SequenceControlState();
}

class _SequenceControlState extends State<SequenceControl> {
  final List<String> _picks = [];

  List<String> get _options =>
      (widget.def.config['options'] as List).cast<String>();
  int get _length => (widget.def.config['solution'] as List).length;

  void _set(void Function() change) {
    setState(change);
    widget.onChanged(SequenceInput(List.of(_picks)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ManorTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label:
              'Chosen so far: ${_picks.isEmpty ? 'nothing' : _picks.map(_title).join(', then ')}. ${_length - _picks.length} to go.',
          liveRegion: true,
          child: ExcludeSemantics(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                for (var i = 0; i < _length; i++)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.midnight,
                      border: Border.all(
                        color: i < _picks.length
                            ? AppColors.goldLight
                            : tokens.panelBorder.withValues(alpha: 0.4),
                        width: i < _picks.length ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: i < _picks.length
                        ? SigilIcon(id: _picks[i], size: 34)
                        : Text('${i + 1}', style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final id in _options)
              _Tile(
                label: _title(id),
                selected: _picks.contains(id),
                onTap:
                    widget.enabled &&
                        !_picks.contains(id) &&
                        _picks.length < _length
                    ? () => _set(() => _picks.add(id))
                    : null,
                child: SigilIcon(id: id, size: 40),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpectralButton(
              label: 'Undo',
              icon: Icons.undo_rounded,
              style: SpectralStyle.quiet,
              onPressed: widget.enabled && _picks.isNotEmpty
                  ? () => _set(_picks.removeLast)
                  : null,
            ),
            SpectralButton(
              label: 'Clear',
              style: SpectralStyle.quiet,
              onPressed: widget.enabled && _picks.isNotEmpty
                  ? () => _set(_picks.clear)
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ cipher

class CipherControl extends StatefulWidget {
  const CipherControl({
    super.key,
    required this.def,
    required this.onChanged,
    required this.onSubmit,
    required this.enabled,
  });

  final PuzzleDef def;
  final ValueChanged<PuzzleInput> onChanged;
  final VoidCallback onSubmit;
  final bool enabled;

  @override
  State<CipherControl> createState() => _CipherControlState();
}

class _CipherControlState extends State<CipherControl> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ManorTokens.of(context);
    final cipher = (widget.def.config['cipherText'] as String).toUpperCase();
    final length = (widget.def.config['answer'] as String).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Stamped letters: ${cipher.split('').join(', ')}',
          child: ExcludeSemantics(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                for (final ch in cipher.split(''))
                  Container(
                    width: 46,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.violetMist, AppColors.deepPurple],
                      ),
                      border: Border.all(
                        color: AppColors.goldLight.withValues(alpha: 0.8),
                      ),
                    ),
                    child: Text(
                      ch,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.goldLight,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          maxLength: length,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
          ],
          style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
          onChanged: (v) => widget.onChanged(CipherInput(v)),
          onSubmitted: (_) => widget.onSubmit(),
          decoration: InputDecoration(
            counterText: '',
            labelText: 'The word the shelf is saying',
            labelStyle: theme.textTheme.bodySmall,
            filled: true,
            fillColor: AppColors.midnight,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(
                color: tokens.panelBorder.withValues(alpha: 0.6),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: tokens.focus, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- dial

class DialControl extends StatefulWidget {
  const DialControl({
    super.key,
    required this.def,
    required this.onChanged,
    required this.enabled,
  });

  final PuzzleDef def;
  final ValueChanged<PuzzleInput> onChanged;
  final bool enabled;

  @override
  State<DialControl> createState() => _DialControlState();
}

class _DialControlState extends State<DialControl> {
  late int _value = widget.def.config['start'] as int;

  int get _min => widget.def.config['min'] as int;
  int get _max => widget.def.config['max'] as int;

  void _step(int delta) {
    setState(() => _value = (_value + delta).clamp(_min, _max));
    widget.onChanged(DialInput(_value));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        DialFace(value: _value, min: _min, max: _max),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          liveRegion: true,
          label: 'Dial set to $_value',
          child: ExcludeSemantics(
            child: Text(
              '$_value',
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 40,
                color: AppColors.goldLight,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            _Step(
              label: '-10',
              semantic: 'Turn down ten',
              onTap: widget.enabled && _value > _min ? () => _step(-10) : null,
            ),
            _Step(
              label: '-1',
              semantic: 'Turn down one',
              onTap: widget.enabled && _value > _min ? () => _step(-1) : null,
            ),
            _Step(
              label: '+1',
              semantic: 'Turn up one',
              onTap: widget.enabled && _value < _max ? () => _step(1) : null,
            ),
            _Step(
              label: '+10',
              semantic: 'Turn up ten',
              onTap: widget.enabled && _value < _max ? () => _step(10) : null,
            ),
          ],
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- combine

class CombineControl extends StatefulWidget {
  const CombineControl({
    super.key,
    required this.def,
    required this.items,
    required this.owned,
    required this.onChanged,
    required this.enabled,
  });

  final PuzzleDef def;
  final List<ItemDef> items;
  final List<String> owned;
  final ValueChanged<PuzzleInput> onChanged;
  final bool enabled;

  @override
  State<CombineControl> createState() => _CombineControlState();
}

class _CombineControlState extends State<CombineControl> {
  final Set<String> _placed = {};

  List<String> get _slots =>
      (widget.def.config['slots'] as List).cast<String>();

  ItemDef _item(String id) => widget.items.firstWhere((i) => i.id == id);

  void _toggle(String id) {
    setState(() {
      if (!_placed.remove(id) && _placed.length < _slots.length) {
        _placed.add(id);
      }
    });
    widget.onChanged(PlacedItemsInput(Set.of(_placed)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ManorTokens.of(context);
    final placed = _placed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label: '${placed.length} of ${_slots.length} pieces placed',
          child: ExcludeSemantics(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.md,
              children: [
                for (var i = 0; i < _slots.length; i++)
                  Container(
                    width: 96,
                    height: 110,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      color: AppColors.midnight,
                      border: Border.all(
                        color: i < placed.length
                            ? AppColors.goldLight
                            : tokens.panelBorder.withValues(alpha: 0.4),
                        width: i < placed.length ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: i < placed.length
                        ? ItemIcon(iconId: _item(placed[i]).iconId, size: 70)
                        : Text(
                            'Piece ${i + 1}',
                            style: theme.textTheme.bodySmall,
                          ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Items you carry',
          style: theme.textTheme.labelMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final id in widget.owned)
              _Tile(
                label: _item(id).name,
                selected: _placed.contains(id),
                semanticLabel:
                    '${_item(id).name}${_placed.contains(id) ? ', placed. Tap to take back' : '. Tap to place'}',
                onTap: widget.enabled ? () => _toggle(id) : null,
                child: ItemIcon(
                  iconId: _item(id).iconId,
                  size: 44,
                  glow: false,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- use item

class UseItemControl extends StatelessWidget {
  const UseItemControl({
    super.key,
    required this.def,
    required this.item,
    required this.targetLabel,
    required this.owned,
    required this.onUse,
  });

  final PuzzleDef def;
  final ItemDef item;
  final String targetLabel;
  final bool owned;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget labeled(Widget art, String label) => SizedBox(
      width: 104,
      child: Column(
        children: [
          art,
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );

    return Column(
      children: [
        Semantics(
          label: 'Use ${item.name} on $targetLabel',
          child: ExcludeSemantics(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                labeled(
                  Opacity(
                    opacity: owned ? 1 : 0.4,
                    child: ItemIcon(
                      iconId: item.iconId,
                      size: 84,
                      glow: owned,
                      dimmed: !owned,
                    ),
                  ),
                  item.name,
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.goldLight,
                  size: 32,
                ),
                labeled(
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.moonCyan, width: 2),
                      boxShadow: AppGlow.cyan(0.6),
                    ),
                    child: const Icon(
                      Icons.ads_click_rounded,
                      color: AppColors.moonCyan,
                      size: 40,
                    ),
                  ),
                  targetLabel,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SpectralButton(
          label: 'Use ${item.name}',
          icon: Icons.touch_app_rounded,
          onPressed: owned ? onUse : null,
          disabledReason: owned
              ? null
              : 'You do not have the ${item.name} yet.',
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- clock

class ClockControl extends StatefulWidget {
  const ClockControl({
    super.key,
    required this.onChanged,
    required this.enabled,
  });

  final ValueChanged<PuzzleInput> onChanged;
  final bool enabled;

  @override
  State<ClockControl> createState() => _ClockControlState();
}

class _ClockControlState extends State<ClockControl> {
  int _hour = 12;
  int _minute = 0;

  void _set(int hour, int minute) {
    setState(() {
      _hour = ((hour - 1) % 12 + 12) % 12 + 1;
      _minute = ((minute % 60) + 60) % 60;
    });
    widget.onChanged(ClockInput(_hour, _minute));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = widget.enabled;
    final time = '$_hour:${_minute.toString().padLeft(2, '0')}';
    return Column(
      children: [
        ClockFace(hour: _hour, minute: _minute),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          liveRegion: true,
          label: 'Clock set to $_hour ${_minute.toString().padLeft(2, '0')}',
          child: ExcludeSemantics(
            child: Text(
              time,
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 40,
                color: AppColors.goldLight,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Hour', style: theme.textTheme.labelMedium),
            _Step(
              label: '-1',
              semantic: 'Hour back one',
              onTap: on ? () => _set(_hour - 1, _minute) : null,
            ),
            _Step(
              label: '+1',
              semantic: 'Hour forward one',
              onTap: on ? () => _set(_hour + 1, _minute) : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Text('Minutes', style: theme.textTheme.labelMedium),
            _Step(
              label: '-5',
              semantic: 'Minutes back five',
              onTap: on ? () => _set(_hour, _minute - 5) : null,
            ),
            _Step(
              label: '-1',
              semantic: 'Minutes back one',
              onTap: on ? () => _set(_hour, _minute - 1) : null,
            ),
            _Step(
              label: '+1',
              semantic: 'Minutes forward one',
              onTap: on ? () => _set(_hour, _minute + 1) : null,
            ),
            _Step(
              label: '+5',
              semantic: 'Minutes forward five',
              onTap: on ? () => _set(_hour, _minute + 5) : null,
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- gears

class GearsControl extends StatefulWidget {
  const GearsControl({
    super.key,
    required this.def,
    required this.onChanged,
    required this.enabled,
  });

  final PuzzleDef def;
  final ValueChanged<PuzzleInput> onChanged;
  final bool enabled;

  @override
  State<GearsControl> createState() => _GearsControlState();
}

class _GearsControlState extends State<GearsControl> {
  late final List<int> _positions = List.filled(
    (widget.def.config['target'] as List).length,
    0,
  );

  int get _notches => widget.def.config['positions'] as int;

  void _turn(int i) {
    setState(() => _positions[i] = (_positions[i] + 1) % _notches);
    widget.onChanged(GearsInput(List.of(_positions)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (var i = 0; i < _positions.length; i++)
              Opacity(
                opacity: widget.enabled ? 1 : 0.5,
                child: PressableScale(
                  onTap: widget.enabled ? () => _turn(i) : null,
                  semanticLabel:
                      'Gear ${i + 1}, notch ${_positions[i]} of ${_notches - 1}. Tap to turn one notch.',
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: ExcludeSemantics(
                      child: Column(
                        children: [
                          GearDial(
                            position: _positions[i],
                            positions: _notches,
                            size: 96,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Gear ${i + 1}',
                            style: theme.textTheme.labelMedium,
                          ),
                          Text(
                            'Notch ${_positions[i]}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Tap a gear to turn it one notch.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
