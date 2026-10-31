import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/design/motion_policy.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/game_feedback_layer.dart';
import '../features/splash/splash_screen.dart';
import 'app_scope.dart';
import 'app_services.dart';
import 'settings_controller.dart';

/// Lets screens know when they become the top route again (for example the
/// room, after a sheet or puzzle closes).
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();

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
  bool _foreground = true;
  late final AppLifecycleListener _lifecycle;
  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        final foreground = state == AppLifecycleState.resumed;
        _services?.audio.setForeground(foreground);
        if (!foreground) {
          unawaited(_services?.game.flushSaves() ?? Future<void>.value());
          unawaited(_services?.settings.saveCurrent() ?? Future<void>.value());
        }
        if (mounted) setState(() => _foreground = foreground);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    final services = _services;
    if (services != null) unawaited(services.close());
    super.dispose();
  }

  void _ready(AppServices services) {
    if (!mounted) {
      unawaited(services.close());
      return;
    }
    setState(() => _services = services);
    services.audio.setForeground(_foreground);
    services.audio.start();
  }

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
          navigatorObservers: [appRouteObserver],
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
                  child: TickerMode(
                    enabled: _foreground,
                    child: _services == null
                        ? (child ?? const SizedBox.shrink())
                        : GameFeedbackLayer(
                            child: child ?? const SizedBox.shrink(),
                          ),
                  ),
                ),
              ),
            );
          },
          home: SplashScreen(
            bootstrap: widget.bootstrap,
            minDuration: widget.minSplash,
            onReady: _ready,
          ),
        );
      },
    );
  }
}
