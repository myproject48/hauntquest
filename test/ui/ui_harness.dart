import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/app/app.dart';
import 'package:hauntquest/app/app_services.dart';
import 'package:hauntquest/app/settings_controller.dart';
import 'package:hauntquest/core/navigation/mist_route.dart';

import '../content/content_fixture.dart';

/// Settings store that keeps values in memory.
class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this.value = const AppSettings()]);

  AppSettings value;
  int saves = 0;

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async {
    value = settings;
    saves++;
  }
}

/// Builds app services from the real content files and an in-memory store.
Future<AppServices> makeServices({
  AppSettings settings = const AppSettings(reducedMotion: true),
  bool reveal = false,
  SettingsStore? store,
}) async {
  final services = await AppServices.create(
    content: contentFrom(freshRaw()),
    store: store ?? MemorySettingsStore(settings),
  );
  services.game.reviewMode = reveal;
  return services;
}

/// Sets the logical screen size for the test view.
void setScreen(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Starts the real app and waits until the main menu is showing.
Future<void> bootApp(WidgetTester tester, AppServices services) async {
  await tester.pumpWidget(
    HauntQuestApp(bootstrap: () async => services, minSplash: Duration.zero),
  );
  await pumpUntilFound(tester, find.text('BEGIN QUEST'));
  await settle(tester);
}

/// Pumps frames until [finder] matches, failing after [maxFrames].
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 60,
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

/// Pushes [screen] on top of whatever is showing, using the app's own route.
Future<void> openScreen(WidgetTester tester, Widget screen) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.push(MistPageRoute<void>(builder: (_) => screen));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

/// Lets transitions and entrance animations finish without waiting forever
/// on looping animations.
Future<void> settle(WidgetTester tester, [int milliseconds = 900]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: milliseconds));
}
