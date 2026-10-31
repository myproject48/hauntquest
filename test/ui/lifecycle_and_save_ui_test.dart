import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/app/app_services.dart';
import 'package:hauntquest/app/game_store.dart';
import 'package:hauntquest/app/settings_controller.dart';
import 'package:hauntquest/core/widgets/game_feedback_layer.dart';
import 'package:hauntquest/features/room/room_screen.dart';
import 'package:hauntquest/features/saves/save_slots_screen.dart';
import 'package:hauntquest/features/settings/settings_screen.dart';

import '../content/content_fixture.dart';
import '../domain/audio_system_test.dart' show RecordingAudioBackend;
import 'ui_harness.dart';

void main() {
  testWidgets(
    'gameplay tickers and audio pause when backgrounded and resume safely',
    (t) async {
      setScreen(t, 430, 932);
      final backend = RecordingAudioBackend();
      final services = await AppServices.create(
        content: contentFrom(freshRaw()),
        store: MemorySettingsStore(const AppSettings()),
        audioBackend: backend,
      );
      await bootApp(t, services);
      await openScreen(t, const RoomScreen());
      await services.audio.flush();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      await services.audio.flush();
      final ctx = t.element(find.byType(RoomScreen));
      expect(TickerMode.valuesOf(ctx).enabled, isFalse);
      expect(services.audio.foreground, isFalse);
      expect(backend.active.last, isFalse);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      await services.audio.flush();
      expect(TickerMode.valuesOf(ctx).enabled, isTrue);
      expect(services.audio.foreground, isTrue);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'discovery and puzzle effects are finite and disabled by reduced motion',
    (t) async {
      setScreen(t, 430, 932);
      final services = await makeServices(settings: const AppSettings());
      await bootApp(t, services);
      await openScreen(t, const RoomScreen());
      services.game.examine('h_portrait');
      await t.pump();
      final effects = t.state<GameFeedbackLayerState>(
        find.byType(GameFeedbackLayer),
      );
      expect(effects.animating, isTrue);
      await t.pump(const Duration(milliseconds: 1000));
      expect(effects.animating, isFalse);
      await services.settings.update(
        services.settings.settings.copyWith(reducedMotion: true),
      );
      await t.pump();
      services.game.acquireItem('wax_cylinder');
      await t.pump();
      expect(effects.animating, isFalse);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'sound controls apply immediately and persist mute and volume after interaction',
    (t) async {
      setScreen(t, 430, 932);
      final settingsStore = MemorySettingsStore();
      final services = await makeServices(store: settingsStore);
      await bootApp(t, services);
      await openScreen(t, const SettingsScreen());
      await t.dragUntilVisible(
        find.text('Mute all sound'),
        find.byType(ListView),
        const Offset(0, -250),
      );
      await t.ensureVisible(find.text('Mute all sound'));
      await t.tap(find.text('Mute all sound'));
      await settle(t);
      expect(services.settings.settings.muted, isTrue);
      final slider = find.byKey(const ValueKey('Master volume'));
      await t.ensureVisible(slider);
      await t.drag(slider, const Offset(-90, 0));
      await settle(t);
      await services.settings.flushWrites();
      expect(services.settings.settings.masterVolume, lessThan(.7));
      expect(
        settingsStore.value.masterVolume,
        services.settings.settings.masterVolume,
      );
      expect(settingsStore.value.muted, isTrue);
      expect(services.game.state.inventory, ['wrens_letter']);
    },
  );

  testWidgets(
    'New Game from Continue requires confirmation and cancellation preserves the save',
    (t) async {
      setScreen(t, 430, 932);
      final content = contentFrom(freshRaw());
      final store = MemoryGameStore();
      final services = await AppServices.create(
        content: content,
        store: MemorySettingsStore(),
        gameStore: store,
      );
      services.game.examine('h_portrait');
      await services.game.flushSaves();
      final before = store.savedState;
      await bootApp(t, services);
      await openScreen(t, const SaveSlotsScreen());
      await t.ensureVisible(find.text('BEGIN QUEST'));
      await t.tap(find.text('BEGIN QUEST'));
      await settle(t);
      expect(find.text('Begin a new quest?'), findsOneWidget);
      await t.tap(find.text('Keep my journey'));
      await settle(t);
      expect(store.savedState, before);
      expect(services.game.hasItem('brass_winding_key'), isTrue);
      await t.tap(find.text('BEGIN QUEST'));
      await settle(t);
      await t.tap(find.text('Start over'));
      await settle(t);
      await t.tap(find.text('SKIP'));
      await settle(t);
      await services.game.flushSaves();
      expect(store.savedState!.inventory, content.story.startItems);
    },
  );
}
