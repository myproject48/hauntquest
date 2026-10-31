import 'package:hauntquest/content/game_content.dart';
import 'package:hauntquest/domain/engine/game_engine.dart';
import 'package:hauntquest/domain/models/game_state.dart';

import 'complete_puzzle_system_test.dart' show solutionFor;

/// A real-engine journey: legal movement, discoveries and manual submissions.
/// No review mode, injected flags, granted items, or pre-solved snapshots.
GameState reachFinalDecision(
  GameContent content, {
  String welcome = 'tw_kind',
  String memory = 'tm_listen',
  String whisper = 'ew_gentle',
  String identity = 'ei_person',
  String bargain = 'mb_refuse',
  String terms = 'mt_break',
  bool research = true,
}) {
  final e = GameEngine(content);
  var s = e.newGame();
  void action(EngineResult r) {
    if (!r.ok) throw StateError('Journey rejected: ${r.rejection?.message}');
    s = r.state;
  }

  void examine(String id) => action(e.examine(s, id));
  void move(String id) => action(e.move(s, id));
  void solve(String id) =>
      action(e.submitPuzzle(s, id, solutionFor(content.puzzleById(id)!)));
  void say(String node, String option) =>
      action(e.resolveChoice(s, node, option));
  examine('h_portrait');
  solve('p1_candle_moons');
  action(e.useItem(s, 'brass_winding_key', 'h_tallow'));
  say('c_tallow_welcome', welcome);
  say('c_tallow_memory', memory);
  solve('p10_symbol_seal');
  solve('p14_mirror');
  move('hall_to_library');
  examine('l_desk');
  solve('p3_shelf_cipher');
  solve('p12_rune_gaps');
  solve('p15_evidence');
  examine('l_hearth');
  solve('p4_torn_pages');
  examine('l_ledger');
  move('library_to_workshop');
  action(e.useItem(s, 'silver_solvent', 'w_cabinet'));
  if (research) solve('p13_alchemy');
  action(e.useItem(s, 'wax_cylinder', 'w_phonograph'));
  say('c_echo_whisper', whisper);
  say('c_echo_identity', identity);
  solve('p5_resonance_tuner');
  move('workshop_to_clocktower');
  solve('p7_stopped_hands');
  if (research) solve('p11_constellation');
  examine('c_logbook');
  say('c_maul_bargain', bargain);
  say('c_maul_terms', terms);
  solve('p8_gear_alignment');
  move('clocktower_to_vault');
  solve('p16_echo_frequencies');
  solve('p9_resonance_engine');
  return s;
}
