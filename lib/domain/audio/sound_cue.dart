import '../engine/game_events.dart';

enum SoundCue {
  pickup,
  unlock,
  success,
  failure,
  footstep,
  discovery,
  chapter,
  interact,
  endingRelease,
  endingSeal,
  endingGuardian,
  echo220,
  echo330,
  echo440,
  echo550,
}

String soundAsset(SoundCue cue) =>
    'audio/${switch (cue) {
      SoundCue.endingRelease => 'ending_release',
      SoundCue.endingSeal => 'ending_seal',
      SoundCue.endingGuardian => 'ending_guardian',
      SoundCue.echo220 => 'echo_220',
      SoundCue.echo330 => 'echo_330',
      SoundCue.echo440 => 'echo_440',
      SoundCue.echo550 => 'echo_550',
      _ => cue.name,
    }}.wav';
String ambienceAsset(String roomId) =>
    'audio/ambient_${switch (roomId) {
      'forgotten_library' => 'library',
      'alchemist_workshop' => 'workshop',
      'clocktower_chamber' => 'clocktower',
      'echo_vault' => 'vault',
      _ => 'hall',
    }}.wav';
List<SoundCue> soundsFor(List<GameEvent> events) {
  final ending = events.whereType<EndingReached>().firstOrNull;
  if (ending != null) {
    return [
      switch (ending.endingId) {
        'seal_echo' => SoundCue.endingSeal,
        'echo_guardian' => SoundCue.endingGuardian,
        _ => SoundCue.endingRelease,
      },
    ];
  }
  final cues = <SoundCue>{};
  if (events.any((e) => e is PuzzleSolved)) {
    cues.add(SoundCue.success);
  } else if (events.any((e) => e is PuzzleAttempted)) {
    cues.add(SoundCue.failure);
  }
  if (events.any((e) => e is ItemAcquired || e is ItemCombined)) {
    cues.add(SoundCue.pickup);
  }
  if (events.any((e) => e is ExitOpened)) cues.add(SoundCue.unlock);
  for (final event in events.whereType<RoomEntered>()) {
    cues.add(SoundCue.footstep);
    if (event.firstVisit) cues.add(SoundCue.chapter);
  }
  if (cues.isEmpty &&
      events.any(
        (e) =>
            e is HotspotExamined ||
            e is ItemInspected ||
            e is ItemUsed ||
            e is ChoiceResolved,
      )) {
    cues.add(SoundCue.interact);
  }
  return cues.take(3).toList();
}
