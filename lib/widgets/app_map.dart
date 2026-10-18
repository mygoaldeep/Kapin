import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Pass the key at build time too (--dart-define=MAPS_API_KEY=...) so the app
/// knows whether the real map can be shown. Without it a stylised preview map
/// is drawn instead, so test builds still look good and never hit Maps SDK errors.
const _mapsKey = String.fromEnvironment('MAPS_API_KEY');
bool get hasMapsKey => _mapsKey.isNotEmpty;

class AppMapController {
  GoogleMapController? _g;
  LatLng? _pending;
  double _pendingZoom = 16.5;

  void move(LatLng p, {double zoom = 16.5}) {
    _pending = p;
    _pendingZoom = zoom;
    _g?.animateCamera(CameraUpdate.newLatLngZoom(p, zoom));
  }
}

class AppMap extends StatefulWidget {
  const AppMap({
    super.key,
    required this.controller,
    this.focus,
    this.accuracyMeters,
    this.markerAt,
    this.destination,
    this.showMyLocation = false,
    this.bottomPadding = 0,
  });

  final AppMapController controller;
  final LatLng? focus;
  final double? accuracyMeters;
  final LatLng? markerAt;
  final LatLng? destination;
  final bool showMyLocation;
  final double bottomPadding;

  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> {
  @override
  void dispose() {
    widget.controller._g = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (!hasMapsKey) {
      return _PreviewMap(
        focus: widget.focus,
        marker: widget.markerAt,
        destination: widget.destination,
        accuracy: widget.accuracyMeters,
        showMe: widget.showMyLocation,
        bottomPadding: widget.bottomPadding,
      );
    }

    final f = widget.focus;
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: f ?? const LatLng(20, 0),
        zoom: f == null ? 1.5 : 16.5,
      ),
      onMapCreated: (g) {
        final c = widget.controller;
        c._g = g;
        final t = c._pending;
        if (t != null) g.moveCamera(CameraUpdate.newLatLngZoom(t, c._pendingZoom));
      },
      style: theme.brightness == Brightness.dark ? _darkStyle : null,
      myLocationEnabled: widget.showMyLocation,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      circles: {
        if (f != null && widget.accuracyMeters != null)
          Circle(
            circleId: const CircleId('accuracy'),
            center: f,
            radius: widget.accuracyMeters!,
            fillColor: scheme.primary.withValues(alpha: 0.15),
            strokeColor: scheme.primary.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
      },
      markers: {
        if (widget.markerAt != null)
          Marker(markerId: const MarkerId('target'), position: widget.markerAt!),
        if (widget.destination != null)
          Marker(
            markerId: const MarkerId('destination'),
            position: widget.destination!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Preview map (no Maps key): animated radar-style grid that moves with you.
// ---------------------------------------------------------------------------

class _PreviewMap extends StatefulWidget {
  const _PreviewMap({
    required this.focus,
    required this.marker,
    required this.destination,
    required this.accuracy,
    required this.showMe,
    required this.bottomPadding,
  });

  final LatLng? focus;
  final LatLng? marker;
  final LatLng? destination;
  final double? accuracy;
  final bool showMe;
  final double bottomPadding;

  @override
  State<_PreviewMap> createState() => _PreviewMapState();
}

class _PreviewMapState extends State<_PreviewMap> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: _PreviewPainter(
              focus: widget.focus,
              marker: widget.marker,
              destination: widget.destination,
              accuracy: widget.accuracy,
              showMe: widget.showMe,
              bottomPadding: widget.bottomPadding,
              scheme: scheme,
              t: _pulse,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: widget.bottomPadding + 14,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Map preview \u00b7 add a Maps key for the street map',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter({
    required this.focus,
    required this.marker,
    required this.destination,
    required this.accuracy,
    required this.showMe,
    required this.bottomPadding,
    required this.scheme,
    required this.t,
  }) : super(repaint: t);

  final LatLng? focus;
  final LatLng? marker;
  final LatLng? destination;
  final double? accuracy;
  final bool showMe;
  final double bottomPadding;
  final ColorScheme scheme;
  final Animation<double> t;

  static const _metersPerPixel = 2.0;
  static const _spacing = 56.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scheme.surfaceContainerHigh, scheme.surfaceContainerLowest],
        ).createShader(rect),
    );

    final center = Offset(size.width / 2, (size.height - bottomPadding) / 2);
    final f = focus;
    final cosLat = f == null ? 1.0 : math.cos(f.latitude * math.pi / 180);
    final ox = f == null ? 0.0 : (f.longitude * 111320 * cosLat / _metersPerPixel) % _spacing;
    final oy = f == null ? 0.0 : (f.latitude * 110574 / _metersPerPixel) % _spacing;

    // Street-like grid that scrolls as the focus moves.
    final thin = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    final thick = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.7)
      ..strokeWidth = 3;
    var i = 0;
    for (var x = (-ox) % _spacing; x < size.width; x += _spacing, i++) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), i % 4 == 0 ? thick : thin);
    }
    i = 0;
    for (var y = oy % _spacing; y < size.height; y += _spacing, i++) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), i % 4 == 0 ? thick : thin);
    }

    // Radar rings.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = scheme.primary.withValues(alpha: 0.12);
    for (final r in [90.0, 180.0, 270.0]) {
      canvas.drawCircle(center, r, ring);
    }
    if (f == null) return;

    // Accuracy area.
    if (showMe && accuracy != null) {
      final r = (accuracy! / _metersPerPixel).clamp(18.0, 140.0);
      canvas.drawCircle(center, r, Paint()..color = scheme.primary.withValues(alpha: 0.12));
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = scheme.primary.withValues(alpha: 0.35),
      );
    }

    // Pulse.
    final p = t.value;
    canvas.drawCircle(
      center,
      12 + 46 * p,
      Paint()..color = scheme.primary.withValues(alpha: 0.28 * (1 - p)),
    );

    final m = marker;
    var pinAt = center;
    if (m != null) {
      final dx = (m.longitude - f.longitude) * 111320 * cosLat / _metersPerPixel;
      final dy = -(m.latitude - f.latitude) * 110574 / _metersPerPixel;
      pinAt = center + Offset(dx, dy);
    }

    if (showMe && (m == null || (pinAt - center).distance > 24)) {
      canvas.drawCircle(center, 11, Paint()..color = Colors.white);
      canvas.drawCircle(center, 8, Paint()..color = scheme.primary);
    }
    final d = destination;
    if (d != null) {
      final dx = (d.longitude - f.longitude) * 111320 * cosLat / _metersPerPixel;
      final dy = -(d.latitude - f.latitude) * 110574 / _metersPerPixel;
      final dest = center + Offset(dx, dy);
      canvas.drawLine(
        center,
        dest,
        Paint()
          ..color = scheme.secondary.withValues(alpha: 0.6)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      _drawPin(canvas, dest, scheme.secondary, scheme.onSecondary);
    }
    if (m != null) _drawPin(canvas, pinAt, scheme.tertiary, scheme.onTertiary);
  }

  void _drawPin(Canvas canvas, Offset tip, Color color, Color onColor) {
    canvas.drawOval(
      Rect.fromCenter(center: tip, width: 22, height: 8),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    final head = tip - const Offset(0, 30);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(head.dx - 11, head.dy + 8)
      ..lineTo(head.dx + 11, head.dy + 8)
      ..close();
    final fill = Paint()..color = color;
    canvas.drawPath(path, fill);
    canvas.drawCircle(head, 15, fill);
    canvas.drawCircle(head, 6, Paint()..color = onColor);
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => true;
}

const _darkStyle = '''
[
 {"elementType":"geometry","stylers":[{"color":"#1d2330"}]},
 {"elementType":"labels.text.fill","stylers":[{"color":"#9aa4b8"}]},
 {"elementType":"labels.text.stroke","stylers":[{"color":"#1d2330"}]},
 {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2c3446"}]},
 {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3a4560"}]},
 {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0f1724"}]},
 {"featureType":"poi","stylers":[{"visibility":"off"}]},
 {"featureType":"transit","stylers":[{"visibility":"off"}]}
]
''';
