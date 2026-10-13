import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/services/qibla_service.dart';
import '../../l10n/app_localizations.dart';
import '../../state/qibla_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/zad_app_bar.dart';
import '../prayer/prayer_times_screen.dart';

/// Qibla direction from the device's real location and heading sensor.
///
/// The bearing is computed geographically (great-circle to the Kaaba); the
/// needle uses the magnetometer. When the sensor is missing or unreliable the
/// screen says so instead of showing a confident but meaningless compass.
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final qibla = context.read<QiblaController>();
      if (qibla.state == QiblaState.idle) {
        qibla.initialise();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final qibla = context.watch<QiblaController>();

    return Scaffold(
      appBar: ZadAppBar(
        title: l10n.t('qibla.title'),
        subtitle: l10n.t('qibla.subtitle'),
        showLogo: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_forward_rounded),
          tooltip: l10n.t('common.close'),
        ),
        actions: <Widget>[
          ZadIconButton(
            icon: Icons.edit_location_alt_outlined,
            tooltip: l10n.t('qibla.settingsLocation'),
            onPressed: () => showLocationSheet(context),
          ),
          ZadIconButton(
            icon: Icons.refresh_rounded,
            tooltip: l10n.t('common.retry'),
            onPressed: qibla.refresh,
          ),
        ],
      ),
      body: _body(context, l10n, qibla),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    QiblaController qibla,
  ) {
    if (qibla.state == QiblaState.loading && qibla.bearing == null) {
      return LoadingView(message: l10n.t('common.loading'));
    }
    if (qibla.state == QiblaState.needsLocation) {
      return PermissionView(
        title: l10n.t('qibla.needsLocation'),
        body: l10n.t('home.locationNeededBody'),
        icon: Icons.explore_off_rounded,
        primaryLabel: l10n.t('settings.useMyLocation'),
        onPrimary: qibla.refresh,
        secondaryLabel: l10n.t('prayer.manualLocation'),
        onSecondary: () => showLocationSheet(context),
      );
    }
    if (qibla.state == QiblaState.error || qibla.bearing == null) {
      return ErrorView(
        body: qibla.error ?? l10n.t('prayer.errorBody'),
        onRetry: qibla.refresh,
      );
    }

    final bearing = qibla.bearing!;
    final distance = qibla.distanceKm;
    final heading = qibla.heading;
    final aligned = qibla.isAligned;
    final turn = qibla.turnInstruction;
    final noSensor = qibla.state == QiblaState.noSensor || !qibla.hasSensor;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZadSpacing.md,
        ZadSpacing.md,
        ZadSpacing.md,
        ZadSpacing.xl,
      ),
      children: <Widget>[
        _CompassDial(
          heading: noSensor ? null : heading,
          bearing: bearing,
          aligned: aligned,
          calibrating: qibla.isCalibrating && !noSensor,
          northLabel: l10n.t('qibla.headingNorth'),
          eastLabel: l10n.t('qibla.headingEast'),
          southLabel: l10n.t('qibla.headingSouth'),
          westLabel: l10n.t('qibla.headingWest'),
          kaabaLabel: l10n.t('qibla.kaaba'),
        ),
        const SizedBox(height: ZadSpacing.lg),
        _StatusCard(
          aligned: aligned,
          noSensor: noSensor,
          calibrating: qibla.isCalibrating && !noSensor,
          turn: turn,
          accuracy: qibla.accuracy,
        ),
        const SizedBox(height: ZadSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: _MetricTile(
                label: l10n.t('qibla.kaabaBearing'),
                value: l10n.t(
                  'qibla.degrees',
                  args: <String, Object?>{'n': l10n.n(bearing.round())},
                ),
                icon: Icons.explore_rounded,
                accent: context.tokens.gold,
              ),
            ),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: _MetricTile(
                label: l10n.t('qibla.distance'),
                value: distance == null
                    ? '--'
                    : '${l10n.n(distance.round())} ${l10n.t('qibla.km')}',
                icon: Icons.straighten_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZadSpacing.md),
        _MetricTile(
          label: l10n.t('qibla.deviceHeading'),
          value: heading == null
              ? l10n.t('qibla.calibrating')
              : '${l10n.n(heading.round())}° '
                    '${l10n.t(_cardinalKey(heading))}',
          icon: Icons.screen_rotation_alt_outlined,
        ),
        const SizedBox(height: ZadSpacing.lg),
        if (noSensor)
          _NoticeCard(
            icon: Icons.sensors_off_rounded,
            title: l10n.t('qibla.noSensor'),
            body: l10n.t('qibla.noSensorBody'),
            accent: Theme.of(context).colorScheme.error,
          )
        else
          _NoticeCard(
            icon: Icons.explore_rounded,
            title: l10n.t('qibla.calibrationTitle'),
            body: l10n.t('qibla.calibrationBody'),
            accent: context.tokens.gold,
          ),
        const SizedBox(height: ZadSpacing.md),
        _NoticeCard(
          icon: Icons.info_outline_rounded,
          title: l10n.t('qibla.method'),
          body: '${l10n.t('qibla.methodGreatCircle')}\n${l10n.t('qibla.accuracyNote')}',
          accent: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  static String _cardinalKey(double heading) =>
      switch (cardinalFor(heading)) {
        CompassCardinal.north => 'qibla.headingNorth',
        CompassCardinal.east => 'qibla.headingEast',
        CompassCardinal.south => 'qibla.headingSouth',
        CompassCardinal.west => 'qibla.headingWest',
      };
}

/// The compass dial.
///
/// The dial itself rotates by the negated device heading so its cardinal labels
/// point at true north; the Kaaba marker is drawn at the computed Qibla bearing
/// and the fixed triangle at the top marks where the phone is pointing.
class _CompassDial extends StatelessWidget {
  const _CompassDial({
    required this.heading,
    required this.bearing,
    required this.aligned,
    required this.calibrating,
    required this.northLabel,
    required this.eastLabel,
    required this.southLabel,
    required this.westLabel,
    required this.kaabaLabel,
  });

  final double? heading;
  final double bearing;
  final bool aligned;
  final bool calibrating;
  final String northLabel;
  final String eastLabel;
  final String southLabel;
  final String westLabel;
  final String kaabaLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return Center(
      child: SizedBox(
        width: 300,
        height: 300,
        child: CustomPaint(
          painter: _CompassPainter(
            heading: heading,
            bearing: bearing,
            aligned: aligned,
            calibrating: calibrating,
            north: northLabel,
            east: eastLabel,
            south: southLabel,
            west: westLabel,
            kaaba: kaabaLabel,
            dial: scheme.surfaceContainerHigh,
            rim: tokens.cardBorder,
            tick: scheme.onSurfaceVariant,
            accent: tokens.gold,
            kaabaColor: scheme.primary,
            onSurface: scheme.onSurface,
            surface: scheme.surface,
            textDirection: Directionality.of(context),
          ),
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({
    required this.heading,
    required this.bearing,
    required this.aligned,
    required this.calibrating,
    required this.north,
    required this.east,
    required this.south,
    required this.west,
    required this.kaaba,
    required this.dial,
    required this.rim,
    required this.tick,
    required this.accent,
    required this.kaabaColor,
    required this.onSurface,
    required this.surface,
    required this.textDirection,
  });

  final double? heading;
  final double bearing;
  final bool aligned;
  final bool calibrating;
  final String north;
  final String east;
  final String south;
  final String west;
  final String kaaba;
  final Color dial;
  final Color rim;
  final Color tick;
  final Color accent;
  final Color kaabaColor;
  final Color onSurface;
  final Color surface;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 18;

    final dialPaint = Paint()..color = dial;
    canvas.drawCircle(center, radius, dialPaint);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = rim,
    );

    final rotation = -((heading ?? 0) * math.pi / 180);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Degree ticks: a longer tick every 45 degrees.
    for (var degree = 0; degree < 360; degree += 15) {
      final isMajor = degree % 45 == 0;
      final angle = degree * math.pi / 180;
      final outer = Offset(
        math.sin(angle) * radius,
        -math.cos(angle) * radius,
      );
      final inner = Offset(
        math.sin(angle) * (radius - (isMajor ? 14 : 7)),
        -math.cos(angle) * (radius - (isMajor ? 14 : 7)),
      );
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..strokeWidth = isMajor ? 1.8 : 1
          ..color = tick.withValues(alpha: isMajor ? 0.65 : 0.32),
      );
    }

    _label(canvas, north, 0, radius - 30, accent, 15, bold: true);
    _label(canvas, east, 90, radius - 30, tick, 13);
    _label(canvas, south, 180, radius - 30, tick, 13);
    _label(canvas, west, 270, radius - 30, tick, 13);

    // The Kaaba marker at the computed Qibla bearing.
    final bearingAngle = bearing * math.pi / 180;
    final markerCenter = Offset(
      math.sin(bearingAngle) * (radius - 52),
      -math.cos(bearingAngle) * (radius - 52),
    );
    canvas.drawCircle(
      markerCenter,
      20,
      Paint()..color = kaabaColor.withValues(alpha: aligned ? 0.28 : 0.16),
    );
    canvas.drawCircle(
      markerCenter,
      20,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = kaabaColor.withValues(alpha: 0.8),
    );
    _kaabaGlyph(canvas, markerCenter);
    _label(canvas, kaaba, bearing, radius - 92, kaabaColor, 11);

    canvas.restore();

    // Fixed pointer marking the phone's forward direction.
    final pointer = Path()
      ..moveTo(center.dx, center.dy - radius + 2)
      ..lineTo(center.dx - 9, center.dy - radius + 20)
      ..lineTo(center.dx + 9, center.dy - radius + 20)
      ..close();
    canvas.drawPath(pointer, Paint()..color = aligned ? accent : kaabaColor);

    // Hub.
    canvas.drawCircle(center, 26, Paint()..color = surface);
    canvas.drawCircle(
      center,
      26,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = rim,
    );
    _centerReadout(canvas, center);
  }

  void _kaabaGlyph(Canvas canvas, Offset center) {
    final paint = Paint()..color = kaabaColor;
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 14, height: 14),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(center.dx - 7, center.dy - 2, 14, 3),
      Paint()..color = accent,
    );
  }

  void _centerReadout(Canvas canvas, Offset center) {
    final text = heading == null
        ? '—'
        : '${heading!.round()}°';
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
      ),
      textDirection: textDirection,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  void _label(
    Canvas canvas,
    String text,
    double degrees,
    double distance,
    Color color,
    double fontSize, {
    bool bold = false,
  }) {
    final angle = degrees * math.pi / 180;
    final position = Offset(
      math.sin(angle) * distance,
      -math.cos(angle) * distance,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color,
        ),
      ),
      textDirection: textDirection,
    )..layout();
    painter.paint(
      canvas,
      Offset(position.dx - painter.width / 2, position.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CompassPainter old) =>
      old.heading != heading ||
      old.bearing != bearing ||
      old.aligned != aligned ||
      old.calibrating != calibrating ||
      old.north != north ||
      old.kaaba != kaaba ||
      old.dial != dial ||
      old.onSurface != onSurface;
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.aligned,
    required this.noSensor,
    required this.calibrating,
    required this.turn,
    required this.accuracy,
  });

  final bool aligned;
  final bool noSensor;
  final bool calibrating;
  final (double, bool)? turn;
  final AccuracyBucket accuracy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;

    final (String title, String body, IconData icon, Color accent) = noSensor
        ? (
            l10n.t('qibla.noSensor'),
            l10n.t('qibla.noSensorBody'),
            Icons.sensors_off_rounded,
            scheme.error,
          )
        : calibrating
        ? (
            l10n.t('qibla.calibrating'),
            l10n.t('qibla.calibrationBody'),
            Icons.screen_rotation_alt_rounded,
            tokens.gold,
          )
        : aligned
        ? (
            l10n.t('qibla.aligned'),
            l10n.t('qibla.alignedBody'),
            Icons.check_circle_rounded,
            scheme.primary,
          )
        : turn == null
        ? (
            l10n.t('qibla.direction'),
            l10n.t('qibla.accuracyNote'),
            Icons.explore_rounded,
            tokens.gold,
          )
        : (
            l10n.t(
              turn!.$2 ? 'qibla.turnRight' : 'qibla.turnLeft',
              args: <String, Object?>{'n': l10n.n(turn!.$1.round())},
            ),
            l10n.t('qibla.direction'),
            turn!.$2 ? Icons.rotate_right_rounded : Icons.rotate_left_rounded,
            tokens.gold,
          );

    final accuracyLabel = switch (accuracy) {
      AccuracyBucket.high => l10n.t('qibla.accuracyHigh'),
      AccuracyBucket.medium => l10n.t('qibla.accuracyMedium'),
      AccuracyBucket.low => l10n.t('qibla.accuracyLow'),
      AccuracyBucket.unknown => l10n.t('qibla.accuracyUnreliable'),
    };

    return ZadCard(
      highlighted: aligned,
      padding: const EdgeInsets.all(ZadSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: accent),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(color: accent),
                ),
              ),
              if (!noSensor && !calibrating)
                ZadBadge(
                  label: accuracyLabel,
                  icon: Icons.speed_rounded,
                  color: accuracy == AccuracyBucket.high
                      ? scheme.primary
                      : tokens.gold,
                ),
            ],
          ),
          const SizedBox(height: ZadSpacing.sm),
          Text(body, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ZadCard(
      padding: const EdgeInsets.all(ZadSpacing.md),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: accent ?? theme.colorScheme.primary),
          const SizedBox(width: ZadSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: zadText(
                    size: 16,
                    weight: 700,
                    family: ZadFonts.arabicUi,
                    color: accent ?? theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ZadCard(
      padding: const EdgeInsets.all(ZadSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 17, color: accent),
          const SizedBox(width: ZadSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
