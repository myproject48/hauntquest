// Renders the original, code-drawn HauntQuest launcher icon (moonlit manor
// tower) into android/app/src/main/res. Not part of the test suite; run it
// only to regenerate the icons:
//
//   flutter test tool/icon/generate_launcher_icon_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/core/theme/app_colors.dart';

/// Paints the icon into a [size] square. [inset] shrinks the artwork toward
/// the center (adaptive icon foregrounds keep art inside the safe zone).
void paintIcon(
  Canvas c,
  double size, {
  bool background = true,
  double inset = 0,
}) {
  final s = size;
  if (background) {
    c.drawRect(
      Rect.fromLTWH(0, 0, s, s),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.35, -0.45),
          radius: 1.1,
          colors: [AppColors.deepPurple, AppColors.navy, AppColors.midnight],
          stops: [0, 0.55, 1],
        ).createShader(Rect.fromLTWH(0, 0, s, s)),
    );
  }
  c.save();
  c.translate(s * inset, s * inset);
  final u = s * (1 - 2 * inset); // art unit

  // Stars.
  final star = Paint()..color = AppColors.parchment.withValues(alpha: 0.75);
  for (final (x, y, r) in const [
    (0.16, 0.18, 0.010),
    (0.30, 0.10, 0.007),
    (0.12, 0.42, 0.006),
    (0.86, 0.62, 0.007),
    (0.48, 0.20, 0.006),
    (0.90, 0.14, 0.008),
  ]) {
    c.drawCircle(Offset(x * u, y * u), r * u, star);
  }

  // Moon with a soft cyan halo.
  final moon = Offset(0.66 * u, 0.30 * u);
  c.drawCircle(
    moon,
    0.24 * u,
    Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.moonCyan.withValues(alpha: 0.45),
          AppColors.moonCyan.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: moon, radius: 0.24 * u)),
  );
  c.drawCircle(moon, 0.14 * u, Paint()..color = const Color(0xFFE9FBFD));
  final crater = Paint()..color = AppColors.moonCyan.withValues(alpha: 0.55);
  c.drawCircle(moon + Offset(-0.04 * u, -0.02 * u), 0.025 * u, crater);
  c.drawCircle(moon + Offset(0.035 * u, 0.04 * u), 0.035 * u, crater);

  // Manor tower silhouette with a gold rim.
  final tower = Path()
    ..moveTo(0.30 * u, 0.96 * u)
    ..lineTo(0.30 * u, 0.52 * u)
    ..lineTo(0.42 * u, 0.30 * u) // spire
    ..lineTo(0.54 * u, 0.52 * u)
    ..lineTo(0.54 * u, 0.62 * u)
    ..lineTo(0.74 * u, 0.62 * u) // roofline
    ..lineTo(0.74 * u, 0.96 * u)
    ..close();
  c.drawPath(tower, Paint()..color = AppColors.midnight);
  c.drawPath(
    tower,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, 0.018 * u)
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.antiqueGold,
  );

  // Glowing clock window and a lit lower window.
  final clock = Offset(0.42 * u, 0.56 * u);
  c.drawCircle(
    clock,
    0.11 * u,
    Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.antiqueGold.withValues(alpha: 0.5),
          AppColors.antiqueGold.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: clock, radius: 0.11 * u)),
  );
  c.drawCircle(clock, 0.05 * u, Paint()..color = AppColors.antiqueGold);
  final hand = Paint()
    ..color = AppColors.midnight
    ..strokeWidth = math.max(1, 0.010 * u)
    ..strokeCap = StrokeCap.round;
  c.drawLine(clock, clock + Offset(0, -0.035 * u), hand);
  c.drawLine(clock, clock + Offset(0.025 * u, 0.015 * u), hand);
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(0.60 * u, 0.70 * u, 0.07 * u, 0.10 * u),
      Radius.circular(0.035 * u),
    ),
    Paint()..color = AppColors.ghostGreen.withValues(alpha: 0.85),
  );

  // Ground mist.
  c.drawRect(
    Rect.fromLTWH(-inset * s, 0.84 * u, s, 0.2 * u + inset * s),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.violetMist.withValues(alpha: 0),
          AppColors.violetMist.withValues(alpha: 0.55),
        ],
      ).createShader(Rect.fromLTWH(0, 0.84 * u, s, 0.2 * u)),
  );
  c.restore();
}

Future<void> render(
  String path,
  double size, {
  bool background = true,
  double inset = 0,
}) async {
  final rec = ui.PictureRecorder();
  paintIcon(Canvas(rec), size, background: background, inset: inset);
  final img = await rec.endRecording().toImage(size.round(), size.round());
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  test('generate launcher icons', () async {
    const res = 'android/app/src/main/res';
    const dens = {
      'mdpi': 1.0,
      'hdpi': 1.5,
      'xhdpi': 2.0,
      'xxhdpi': 3.0,
      'xxxhdpi': 4.0,
    };
    for (final e in dens.entries) {
      // Legacy square icon (48 dp) and adaptive foreground (108 dp, art in
      // the central 66 dp safe zone).
      await render('$res/mipmap-${e.key}/ic_launcher.png', 48 * e.value);
      await render(
        '$res/mipmap-${e.key}/ic_launcher_foreground.png',
        108 * e.value,
        background: false,
        inset: 0.2,
      );
    }
    await render('/tmp/hq_qa/icon_preview.png', 512);
  });
}
