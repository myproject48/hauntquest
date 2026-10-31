import 'package:flutter/material.dart';

import '../../content/definitions/room_def.dart';
import '../../core/design/motion_policy.dart';
import '../../core/design/tokens.dart';
import '../../core/painting/hotspot_art.dart';
import '../../core/painting/paint_kit.dart';
import '../../core/painting/room_art.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fog_layer.dart';
import '../../core/widgets/grain_overlay.dart';
import '../../core/widgets/pressable_scale.dart';

/// What kind of marker an object shows, so meaning never relies on color alone.
enum HotspotKind { examine, puzzle, speak, locked }

/// The illustrated room with parallax depth and tappable objects.
///
/// The scene keeps a fixed 3:4 shape and is fitted into the space it is given.
/// Anything outside it is filled with the room's own colors, so tall phones and
/// wide tablets both look intentional.
class RoomStage extends StatefulWidget {
  const RoomStage({
    super.key,
    required this.room,
    required this.kindOf,
    required this.onHotspot,
    required this.showMarkers,
    this.interactive = true,
  });

  /// Width divided by height of the illustrated scene.
  static const double aspect = 0.75;

  final RoomDef room;
  final HotspotKind Function(HotspotDef) kindOf;
  final ValueChanged<HotspotDef> onHotspot;

  /// Show a marker on every object.
  final bool showMarkers;

  /// When false the objects are not exposed to touch or screen readers (the
  /// room's list view is used instead).
  final bool interactive;

  @override
  State<RoomStage> createState() => _RoomStageState();
}

class _RoomStageState extends State<RoomStage> with TickerProviderStateMixin {
  late final AnimationController _time = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
    value: 0.18,
  );
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  final ValueNotifier<Offset> _parallax = ValueNotifier(Offset.zero);
  Offset _from = Offset.zero;
  bool _reduce = false;
  late final RoomArt _art = RoomArt.forScene(widget.room.sceneId);

  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      _parallax.value = Offset.lerp(
        _from,
        Offset.zero,
        Curves.easeOutCubic.transform(_settle.value),
      )!;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MotionPolicy.reduceOf(context);
    if (_reduce) {
      _time.stop();
      _parallax.value = Offset.zero;
    } else if (!_time.isAnimating) {
      _time.repeat();
    }
  }

  @override
  void dispose() {
    _time.dispose();
    _settle.dispose();
    _parallax.dispose();
    super.dispose();
  }

  Size _fit(Size box) {
    var w = box.width;
    var h = w / RoomStage.aspect;
    if (h > box.height) {
      h = box.height;
      w = h * RoomStage.aspect;
    }
    return Size(w, h);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final stage = _fit(box.biggest);
        return Stack(
          fit: StackFit.expand,
          children: [
            // Room-colored backdrop that extends past the stage.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_art.topColor, _art.bottomColor],
                ),
              ),
            ),
            Center(
              child: SizedBox(
                width: stage.width,
                height: stage.height,
                child: ClipRect(child: _content(stage)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _content(Size stage) {
    Widget layer(_StageLayer l) => RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _RoomLayerPainter(
          art: _art,
          layer: l,
          hotspots: widget.room.hotspots,
          time: _time,
          parallax: _parallax,
          stageWidth: stage.width,
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanUpdate: _reduce
          ? null
          : (d) {
              final next =
                  _parallax.value +
                  Offset(
                    d.delta.dx / stage.width * 2.5,
                    d.delta.dy / stage.height * 2.5,
                  );
              _parallax.value = Offset(
                next.dx.clamp(-1, 1),
                next.dy.clamp(-1, 1),
              );
            },
      onPanEnd: (_) {
        _from = _parallax.value;
        _settle.forward(from: 0);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(child: layer(_StageLayer.back)),
          FogLayer(
            color: _art.accent,
            density: 0.7,
            verticalBias: 0.7,
            seed: widget.room.id.length,
          ),
          ExcludeSemantics(child: layer(_StageLayer.mid)),
          for (final h in widget.room.hotspots)
            _HotspotMarker(
              key: ValueKey(h.id),
              hotspot: h,
              stage: stage,
              kind: widget.kindOf(h),
              showMarker: widget.showMarkers,
              interactive: widget.interactive,
              onTap: () => widget.onHotspot(h),
            ),
          ExcludeSemantics(
            child: IgnorePointer(child: layer(_StageLayer.front)),
          ),
          const GrainOverlay(vignette: 0.5),
        ],
      ),
    );
  }
}

enum _StageLayer { back, mid, front }

class _RoomLayerPainter extends CustomPainter {
  _RoomLayerPainter({
    required this.art,
    required this.layer,
    required this.hotspots,
    required this.time,
    required this.parallax,
    required this.stageWidth,
  }) : super(repaint: Listenable.merge([time, parallax]));

  final RoomArt art;
  final _StageLayer layer;
  final List<HotspotDef> hotspots;
  final Animation<double> time;
  final ValueNotifier<Offset> parallax;
  final double stageWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final p = parallax.value;
    final t = time.value;
    // The middle layer is the reference plane; the others shift against it.
    final shift = switch (layer) {
      _StageLayer.back => Offset(
        -p.dx * stageWidth * 0.018,
        -p.dy * stageWidth * 0.008,
      ),
      _StageLayer.mid => Offset.zero,
      _StageLayer.front => Offset(
        p.dx * stageWidth * 0.03,
        p.dy * stageWidth * 0.012,
      ),
    };
    canvas.save();
    canvas.translate(shift.dx, shift.dy);
    switch (layer) {
      case _StageLayer.back:
        // Slightly oversized so shifting never reveals an edge.
        canvas.translate(-size.width * 0.02, -size.height * 0.01);
        canvas.scale(1.04, 1.02);
        art.paintBack(canvas, size, t);
      case _StageLayer.mid:
        art.paintMid(canvas, size, t);
        for (final h in hotspots) {
          HotspotArt.paint(canvas, h.id, Kit.rectOf(h.area, size), t);
        }
      case _StageLayer.front:
        art.paintFront(canvas, size, t);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RoomLayerPainter old) =>
      old.art != art || old.layer != layer;
}

class _HotspotMarker extends StatefulWidget {
  const _HotspotMarker({
    super.key,
    required this.hotspot,
    required this.stage,
    required this.kind,
    required this.showMarker,
    required this.interactive,
    required this.onTap,
  });

  final HotspotDef hotspot;
  final Size stage;
  final HotspotKind kind;
  final bool showMarker;
  final bool interactive;
  final VoidCallback onTap;

  @override
  State<_HotspotMarker> createState() => _HotspotMarkerState();
}

class _HotspotMarkerState extends State<_HotspotMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  IconData get _icon => switch (widget.kind) {
    HotspotKind.examine => Icons.search_rounded,
    HotspotKind.puzzle => Icons.extension_rounded,
    HotspotKind.speak => Icons.chat_bubble_rounded,
    HotspotKind.locked => Icons.lock_rounded,
  };

  Color get _color => switch (widget.kind) {
    HotspotKind.examine => AppColors.moonCyan,
    HotspotKind.puzzle => AppColors.goldLight,
    HotspotKind.speak => AppColors.ghostGreen,
    HotspotKind.locked => AppColors.fog,
  };

  String get _hint => switch (widget.kind) {
    HotspotKind.examine => 'Double tap to examine',
    HotspotKind.puzzle => 'Double tap to look closer. This is a puzzle.',
    HotspotKind.speak => 'Double tap to speak',
    HotspotKind.locked => 'Double tap to see why it is locked',
  };

  @override
  Widget build(BuildContext context) {
    final area = widget.hotspot.area;
    final w = area.w * widget.stage.width;
    final h = area.h * widget.stage.height;
    // Grow the touch area to the minimum without moving the artwork.
    final tw = w < AppLayout.minTouch ? AppLayout.minTouch : w;
    final th = h < AppLayout.minTouch ? AppLayout.minTouch : h;
    final left = area.x * widget.stage.width - (tw - w) / 2;
    final top = area.y * widget.stage.height - (th - h) / 2;
    final reduce = MotionPolicy.reduceOf(context);

    Widget content = Stack(
      alignment: Alignment.center,
      children: [
        if (widget.showMarker)
          Positioned(
            top: 4,
            right: 4,
            child: _Badge(icon: _icon, color: _color, pulse: !reduce),
          ),
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _flash,
            builder: (context, _) => CustomPaint(
              size: Size(tw, th),
              painter: _FlashPainter(
                _flash.value,
                widget.kind == HotspotKind.locked
                    ? AppColors.fog
                    : AppColors.goldLight,
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.interactive) {
      content = PressableScale(
        enforceMinSize: false,
        borderRadius: AppRadius.md,
        semanticLabel: widget.hotspot.semanticLabel,
        semanticHint: _hint,
        onTap: () {
          if (!reduce) _flash.forward(from: 0);
          widget.onTap();
        },
        child: content,
      );
    } else {
      content = ExcludeSemantics(child: content);
    }

    return Positioned(
      left: left,
      top: top,
      width: tw,
      height: th,
      child: content,
    );
  }
}

class _Badge extends StatefulWidget {
  const _Badge({required this.icon, required this.color, required this.pulse});

  final IconData icon;
  final Color color;
  final bool pulse;

  @override
  State<_Badge> createState() => _BadgeState();
}

class _BadgeState extends State<_Badge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.pulse && !MotionPolicy.reduceOf(context)) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0.5;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.midnight.withValues(alpha: 0.82),
            border: Border.all(color: widget.color, width: 1.6),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.2 + 0.35 * _c.value),
                blurRadius: 6 + 8 * _c.value,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        ),
        child: Icon(widget.icon, size: 15, color: widget.color),
      ),
    );
  }
}

class _FlashPainter extends CustomPainter {
  _FlashPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = size.center(Offset.zero);
    final r = size.shortestSide * (0.2 + 0.5 * t);
    canvas.drawCircle(
      c,
      r,
      Kit.stroke(color.withValues(alpha: 0.85 * (1 - t)), 3),
    );
    Kit.glow(canvas, c, r * 1.4, color, 0.35 * (1 - t));
  }

  @override
  bool shouldRepaint(_FlashPainter old) => old.t != t;
}
