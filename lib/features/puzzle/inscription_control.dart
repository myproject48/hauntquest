import 'dart:async';

import 'package:flutter/material.dart';

import '../../content/definitions/puzzle_def.dart';
import '../../app/app_scope.dart';
import '../../domain/audio/sound_cue.dart';
import '../../core/design/tokens.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/puzzles/puzzle_evaluator.dart';

/// Controlled apparatus for the manor's inscribed puzzles. All changes are
/// drafts; only the screen's explicit Check action may complete a puzzle.
class InscriptionControl extends StatefulWidget {
  const InscriptionControl({
    super.key,
    required this.def,
    required this.input,
    required this.enabled,
    required this.onChanged,
  });
  final PuzzleDef def;
  final PuzzleInput input;
  final bool enabled;
  final ValueChanged<PuzzleInput> onChanged;

  @override
  State<InscriptionControl> createState() => _InscriptionControlState();
}

class _InscriptionControlState extends State<InscriptionControl>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _playback?.cancel();
      if (mounted) setState(() => _pulse = null);
    }
  }

  Timer? _playback;
  int? _pulse;
  int _beat = 0;

  @override
  void dispose() {
    _playback?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _replay() {
    _playback?.cancel();
    final call = (widget.def.config['frequencies'] as List).cast<int>();
    _beat = 0;
    setState(() => _pulse = call.first);
    _sound(call.first);
    _playback = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _beat++;
      setState(() => _pulse = _beat < call.length ? call[_beat] : null);
      if (_beat >= call.length) {
        timer.cancel();
      } else {
        _sound(call[_beat]);
      }
    });
  }

  void _sound(int hz) => AppScope.of(context).audio.play(switch (hz) {
    220 => SoundCue.echo220,
    330 => SoundCue.echo330,
    440 => SoundCue.echo440,
    _ => SoundCue.echo550,
  });

  String _label(String value) => widget.def.config['variant'] == 'echo'
      ? '$value Hz'
      : value.replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    final c = widget.def.config;
    final variant = c['variant'];
    final theme = Theme.of(context);
    final input = widget.input;
    Widget body;
    if (input is SequenceInput) {
      final options = (c['options'] as List).cast<String>();
      final length = (c['solution'] as List).length;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c['pattern'] != null)
            Text(
              c['pattern'] as String,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
          if (variant == 'echo') ...[
            OutlinedButton.icon(
              onPressed: widget.enabled ? _replay : null,
              icon: const Icon(Icons.graphic_eq),
              label: const Text('Replay the call'),
            ),
            Semantics(
              liveRegion: true,
              child: Text(
                _pulse == null
                    ? 'Remembered call: low → high → middle'
                    : 'Pulse ${_beat + 1}: $_pulse Hz',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(switch (variant) {
            'alchemy' => 'Retort • add ingredients in order',
            'evidence' => 'Timeline • earliest to latest',
            'runes' => 'Missing carvings • left to right',
            _ => 'Response • three pulses',
          }, style: theme.textTheme.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.goldLight.withValues(alpha: .4),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${i + 1}. ${i < input.picks.length ? _label(input.picks[i]) : '—'}',
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                OutlinedButton(
                  key: ValueKey('pick-$option'),
                  onPressed:
                      widget.enabled &&
                          input.picks.length < length &&
                          !input.picks.contains(option)
                      ? () => widget.onChanged(
                          SequenceInput([...input.picks, option]),
                        )
                      : null,
                  child: Text(_label(option)),
                ),
            ],
          ),
          TextButton(
            onPressed: widget.enabled && input.picks.isNotEmpty
                ? () => widget.onChanged(
                    SequenceInput(
                      input.picks.sublist(0, input.picks.length - 1),
                    ),
                  )
                : null,
            child: const Text('Undo last entry'),
          ),
        ],
      );
    } else if (input is GearsInput && variant == 'mirror') {
      final source = (c['source'] as List).cast<int>();
      Widget grid(List<int> cells, bool editable) => SizedBox(
        width: 168,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (var i = 0; i < cells.length; i++)
              Semantics(
                label:
                    '${editable ? 'Reflection' : 'Source'} row ${i ~/ 3 + 1}, column ${i % 3 + 1}, ${cells[i] == 1 ? 'lit' : 'dark'}',
                button: editable,
                toggled: cells[i] == 1,
                child: InkWell(
                  key: ValueKey('${editable ? 'mirror' : 'source'}-$i'),
                  onTap: editable && widget.enabled
                      ? () {
                          final next = List<int>.of(cells);
                          next[i] = 1 - next[i];
                          widget.onChanged(GearsInput(next));
                        }
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cells[i] == 1
                          ? AppColors.goldLight
                          : AppColors.midnight,
                      border: Border.all(
                        color: AppColors.goldLight.withValues(alpha: .5),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      cells[i] == 1 ? Icons.star : Icons.circle_outlined,
                      color: cells[i] == 1
                          ? AppColors.midnight
                          : AppColors.goldLight,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
      body = Column(
        children: [
          const Text(
            'SOURCE  │  VERTICAL MIRROR  │  REFLECTION',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 16,
            children: [
              Column(
                children: [
                  const Text('Fixed pattern'),
                  const SizedBox(height: 8),
                  grid(source, false),
                ],
              ),
              Column(
                children: [
                  const Text('Your reflection'),
                  const SizedBox(height: 8),
                  grid(input.positions, true),
                ],
              ),
            ],
          ),
        ],
      );
    } else if (input is GearsInput) {
      final labels = (c['labels'] as List).cast<String>();
      const compass = ['North · 0', 'East · 1', 'South · 2', 'West · 3'];
      body = Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: [
          for (var i = 0; i < input.positions.length; i++)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(labels[i], style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: ValueKey('disc-$i'),
                  onPressed: widget.enabled
                      ? () {
                          final next = List<int>.of(input.positions);
                          next[i] = (next[i] + 1) % 4;
                          widget.onChanged(GearsInput(next));
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Transform.rotate(
                          angle: input.positions[i] * 1.57079632679,
                          child: const Icon(
                            Icons.north,
                            color: AppColors.goldLight,
                            size: 48,
                          ),
                        ),
                        Text(compass[input.positions[i]]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      );
    } else if (input is CipherInput) {
      final alphabet = (c['substitution'] as Map).entries;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            c['cipherText'] as String,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            children: [
              for (final entry in alphabet)
                Text(
                  '${entry.key} = ${entry.value}',
                  style: theme.textTheme.titleMedium,
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: input.text,
            enabled: widget.enabled,
            maxLength: 200,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Decoded flower',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => widget.onChanged(CipherInput(v)),
          ),
        ],
      );
    } else {
      body = const SizedBox.shrink();
    }
    return body;
  }
}
