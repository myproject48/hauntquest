import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/design/motion_policy.dart';
import '../../core/design/tokens.dart';
import '../../core/navigation/mist_route.dart';
import '../../core/painting/exterior_scene.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fill_or_scroll.dart';
import '../../core/widgets/manor_panel.dart';
import '../../core/widgets/spectral_button.dart';
import '../menu/main_menu_screen.dart';

/// Animated splash. The moon rises, the manor appears, and the title writes
/// itself while content and settings load. Shows a clear error with a retry if
/// loading or content validation fails.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.bootstrap,
    required this.minDuration,
    required this.onReady,
  });

  final Future<AppServices> Function() bootstrap;
  final Duration minDuration;
  final ValueChanged<AppServices> onReady;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this);
  Object? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduce = MotionPolicy.reduceOf(context);
    final duration = reduce ? Duration.zero : widget.minDuration;
    _intro.duration = duration == Duration.zero
        ? const Duration(milliseconds: 1)
        : duration;
    _intro.forward();
    _load(duration);
  }

  Future<void> _load(Duration minimum) async {
    if (_error != null) setState(() => _error = null);
    if (_intro.isCompleted) _intro.forward(from: 0);
    try {
      final results = await Future.wait<Object?>([
        widget.bootstrap(),
        Future<void>.delayed(minimum),
      ]);
      if (!mounted) return;
      final services = results.first! as AppServices;
      widget.onReady(services);
      // Wait one frame so the app scope holds the services before routing.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pushReplacementMist(const MainMenuScreen());
      });
    } catch (error, stack) {
      debugPrint('Startup failed: $error\n$stack');
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          ExteriorScene(reveal: _intro),
          // Darken the lower half so the title and bar stay readable.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00050818), Color(0xCC050818)],
                stops: [0.45, 1],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.contentMaxWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: AnimatedBuilder(
                    animation: _intro,
                    builder: (context, _) => _error == null
                        ? _Lockup(progress: _intro.value, theme: theme)
                        : _ErrorCard(
                            error: _error!,
                            onRetry: () => _load(
                              MotionPolicy.reduceOf(context)
                                  ? Duration.zero
                                  : widget.minDuration,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Lockup extends StatelessWidget {
  const _Lockup({required this.progress, required this.theme});

  final double progress;
  final ThemeData theme;

  double _phase(double from, double to) => Curves.easeOutCubic.transform(
    ((progress - from) / (to - from)).clamp(0, 1),
  );

  @override
  Widget build(BuildContext context) {
    final title = _phase(0.25, 0.7);
    final sub = _phase(0.55, 0.85);
    final bar = _phase(0.1, 1);
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = (width * 0.11).clamp(30.0, 56.0);

    // Title in the middle, loading bar at the bottom; scrolls if needed.
    return FillOrScroll(
      children: [
        const SizedBox.shrink(),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              label: 'HauntQuest AI',
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: title,
                  child: Text(
                    'HAUNTQUEST',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: titleSize,
                      letterSpacing: 14 - 11 * title,
                      shadows: [
                        Shadow(
                          color: AppColors.moonCyan.withValues(
                            alpha: 0.75 * title,
                          ),
                          blurRadius: 26,
                        ),
                        Shadow(
                          color: AppColors.moonCyan.withValues(
                            alpha: 0.4 * title,
                          ),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Opacity(
              opacity: sub,
              child: ExcludeSemantics(
                child: Text(
                  'A I',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.antiqueGold,
                    letterSpacing: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Opacity(
              opacity: sub,
              child: Text(
                'The Whispering Manor',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: AppColors.fog,
                ),
              ),
            ),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.xxl),
            Semantics(
              label: 'Loading',
              value: '${(bar * 100).round()} percent',
              child: SizedBox(
                width: 220,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: bar,
                        minHeight: 4,
                        backgroundColor: AppColors.deepNavy,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.antiqueGold,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ExcludeSemantics(
                      child: Text(
                        'Lighting the lanterns',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        child: Semantics(
          liveRegion: true,
          child: ManorPanel(
            tone: PanelTone.strong,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'The manor would not open',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Something went wrong while loading the story.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      '$error',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SpectralButton(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
