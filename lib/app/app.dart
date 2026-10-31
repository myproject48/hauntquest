import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/design/motion_policy.dart';
import '../core/theme/app_theme.dart';
import '../features/splash/splash_screen.dart';
import 'app_scope.dart';
import 'app_services.dart';
import 'settings_controller.dart';

/// Root widget of HauntQuest AI.
class HauntQuestApp extends StatefulWidget {
  const HauntQuestApp({
    super.key,
    this.bootstrap = AppServices.load,
    this.minSplash = const Duration(milliseconds: 2800),
  });

  /// Loads content and settings. Tests pass a fake.
  final Future<AppServices> Function() bootstrap;

  /// Minimum time the splash screen stays up.
  final Duration minSplash;

  @override
  State<HauntQuestApp> createState() => _HauntQuestAppState();
}

class _HauntQuestAppState extends State<HauntQuestApp> {
  AppServices? _services;

  @override
  Widget build(BuildContext context) {
    final settingsController = _services?.settings;
    return ListenableBuilder(
      listenable: Listenable.merge([?settingsController]),
      builder: (context, _) {
        final s = settingsController?.settings ?? const AppSettings();
        return MaterialApp(
          title: 'HauntQuest AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(
            highContrast: s.highContrast,
            spacedText: s.spacedText,
          ),
          themeMode: ThemeMode.dark,
          darkTheme: AppTheme.build(
            highContrast: s.highContrast,
            spacedText: s.spacedText,
          ),
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            // Honor whichever is larger: the device font size or ours.
            final scale = math.max(mq.textScaler.scale(1), s.textScale);
            return AppScope(
              services: _services,
              child: MotionPolicy(
                reduceMotion: s.reducedMotion,
                child: MediaQuery(
                  data: mq.copyWith(textScaler: TextScaler.linear(scale)),
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
          home: SplashScreen(
            bootstrap: widget.bootstrap,
            minDuration: widget.minSplash,
            onReady: (services) => setState(() => _services = services),
          ),
        );
      },
    );
  }
}
