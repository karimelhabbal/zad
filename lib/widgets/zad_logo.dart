import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// The Zad brand mark: an octagonal Khatam star in brushed gold over a deep
/// emerald field, with the name in classical script at the centre.
///
/// Drawn with [CustomPaint] so it stays crisp at any size and needs no raster
/// asset.
class ZadLogo extends StatelessWidget {
  const ZadLogo({
    super.key,
    this.size = 96,
    this.showName = true,
    this.elevated = true,
  });

  final double size;
  final bool showName;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const <Color>[Color(0xFF1B4B3A), Color(0xFF0B1914)]
              : const <Color>[Color(0xFF175C45), Color(0xFF00301F)],
        ),
        boxShadow: elevated
            ? <BoxShadow>[
                BoxShadow(
                  color: const Color(0x4D0F382C),
                  blurRadius: size * 0.25,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
        border: Border.all(
          color: ZadPalette.goldLight.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: CustomPaint(
        painter: _KhatamLogoPainter(
          gold: ZadPalette.goldLight,
          glow: const Color(0xFFEDBF7A),
        ),
        child: Center(
          child: showName
              ? Padding(
                  padding: EdgeInsets.only(top: size * 0.02),
                  child: Text(
                    'زاد',
                    textAlign: TextAlign.center,
                    style: zadText(
                      size: size * 0.4,
                      weight: 700,
                      height: 1.0,
                      family: ZadFonts.classical,
                      color: const Color(0xFFF2D8A4),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _KhatamLogoPainter extends CustomPainter {
  _KhatamLogoPainter({required this.gold, required this.glow});

  final Color gold;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.30;

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, size.width * 0.012)
      ..color = gold.withValues(alpha: 0.85);

    final faint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = gold.withValues(alpha: 0.22);

    // Concentric guide rings.
    canvas.drawCircle(center, radius * 1.55, faint);
    canvas.drawCircle(center, radius * 1.28, faint);

    // Outer square rotated 45° — the second square of the Khatam.
    final square = Path();
    final half = radius * 1.22;
    square.addPolygon(<Offset>[
      Offset(center.dx - half, center.dy - half),
      Offset(center.dx + half, center.dy - half),
      Offset(center.dx + half, center.dy + half),
      Offset(center.dx - half, center.dy + half),
    ], true);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 4);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(square, faint);
    canvas.restore();

    // Eight-pointed star (two overlapping squares).
    for (final rotation in <double>[0, math.pi / 4]) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawPath(square, outline);
      canvas.restore();
    }

    // Vertex nodes on the inner square.
    final nodePaint = Paint()..color = glow.withValues(alpha: 0.9);
    for (final angle in <double>[0, math.pi / 4, math.pi / 2, 3 * math.pi / 4]) {
      for (final sign in <double>[1, -1]) {
        final point = Offset(
          center.dx + math.cos(angle) * half * sign,
          center.dy + math.sin(angle) * half * sign,
        );
        canvas.drawCircle(point, math.max(1.2, size.width * 0.011), nodePaint);
      }
    }

    // Inner medallion holding the name.
    canvas.drawCircle(center, radius * 0.94, outline);
    canvas.drawCircle(center, radius * 0.86, faint);
  }

  @override
  bool shouldRepaint(_KhatamLogoPainter oldDelegate) =>
      oldDelegate.gold != gold || oldDelegate.glow != glow;
}

/// A subtle repeating Khatam watermark used behind hero surfaces.
class KhatamWatermark extends StatelessWidget {
  const KhatamWatermark({
    super.key,
    this.size = 160,
    this.opacity = 0.08,
    this.child,
  });

  final double size;
  final double opacity;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WatermarkPainter(
        color: context.tokens.gold.withValues(alpha: opacity),
        size: size,
      ),
      child: child,
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  _WatermarkPainter({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;

    for (double y = 0; y < canvasSize.height + size; y += size) {
      for (double x = 0; x < canvasSize.width + size; x += size) {
        final center = Offset(x, y);
        final half = size * 0.30;
        final square = Path()
          ..addPolygon(<Offset>[
            Offset(center.dx - half, center.dy - half),
            Offset(center.dx + half, center.dy - half),
            Offset(center.dx + half, center.dy + half),
            Offset(center.dx - half, center.dy + half),
          ], true);
        for (final rotation in <double>[0, math.pi / 4]) {
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.rotate(rotation);
          canvas.translate(-center.dx, -center.dy);
          canvas.drawPath(square, paint);
          canvas.restore();
        }
      }
    }
  }

  @override
  bool shouldRepaint(_WatermarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.size != size;
}

/// The gilded octagonal verse-number badge from the design.
class OctagonBadge extends StatelessWidget {
  const OctagonBadge({
    super.key,
    required this.label,
    this.size = 30,
    this.filled = true,
  });

  final String label;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OctagonPainter(
          fill: filled
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          border: tokens.gold.withValues(alpha: 0.7),
        ),
        child: Center(
          child: Text(
            label,
            style: zadText(
              size: size * 0.42,
              weight: 600,
              family: ZadFonts.arabicUi,
              color: filled ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _OctagonPainter extends CustomPainter {
  _OctagonPainter({required this.fill, required this.border});

  final Color fill;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = (math.pi / 4) * i - math.pi / 8;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
  }

  @override
  bool shouldRepaint(_OctagonPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.border != border;
}

/// The ornamental frame used above a surah in the reading view.
class SurahOrnament extends StatelessWidget {
  const SurahOrnament({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.md,
        vertical: ZadSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ZadRadius.lg),
        border: Border.all(color: tokens.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            title,
            textAlign: TextAlign.center,
            style: zadText(
              size: 20,
              weight: 600,
              family: ZadFonts.classical,
              color: scheme.onSurface,
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}
