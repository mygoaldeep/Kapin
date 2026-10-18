import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../services/app_services.dart';
import '../services/backend.dart';
import '../services/share_controller.dart';
import '../utils.dart';
import '../widgets/app_map.dart';
import '../widgets/map_panel.dart';
import '../widgets/pulse_dot.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key, required this.user});
  final AppUser user;

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final ShareController _c = AppServices.current.share;
  final _mapCtl = AppMapController();
  Duration _duration = const Duration(hours: 1);
  Position? _lastCamera;

  static const _mapBottomPadding = 300.0;

  @override
  void initState() {
    super.initState();
    _c.addListener(_follow);
    _c.locate();
  }

  @override
  void dispose() {
    _c.removeListener(_follow);
    super.dispose();
  }

  void _follow() {
    final p = _c.position;
    if (p == null || identical(p, _lastCamera)) return;
    _lastCamera = p;
    _mapCtl.move(LatLng(p.latitude, p.longitude));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final p = _c.position;
        final here = p == null ? null : LatLng(p.latitude, p.longitude);

        return Stack(
          children: [
            Positioned.fill(
              child: AppMap(
                controller: _mapCtl,
                focus: here,
                accuracyMeters: p?.accuracy,
                markerAt: _c.isSharing ? here : null,
                showMyLocation: p != null,
                bottomPadding: p == null ? 0 : _mapBottomPadding,
              ),
            ),
            // Floating top controls
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      FloatingRoundButton(
                        child: IconButton(
                          tooltip: 'Menu',
                          icon: const Icon(Icons.menu_rounded),
                          onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
                        ),
                      ),
                      const Spacer(),
                      FloatingRoundButton(
                        child: IconButton(
                          tooltip: 'Recenter',
                          icon: _c.locating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.my_location),
                          onPressed: _c.locating
                              ? null
                              : () {
                                  _lastCamera = null;
                                  _c.locate();
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MapPanel(child: _buildPanel(context)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final p = _c.position;

    if (p == null) {
      if (_c.locating) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Row(
            children: [
              SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
              SizedBox(width: 14),
              Text('Finding your location…'),
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Location unavailable', style: text.titleLarge),
          const SizedBox(height: 6),
          Text(_c.error ?? 'We need your location to start.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _c.locate,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      );
    }

    final session = _c.session;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (session != null)
          Row(
            children: [
              const PulseDot(),
              const SizedBox(width: 8),
              Text('Live now', style: text.labelLarge?.copyWith(color: const Color(0xFF16A34A))),
              const Spacer(),
              ValueListenableBuilder<Duration>(
                valueListenable: _c.remaining,
                builder: (_, d, __) => Chip(
                  avatar: const Icon(Icons.timer_outlined, size: 18),
                  label: Text('${formatRemaining(d)} left'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        if (session != null) const SizedBox(height: 8),
        Text(
          _c.address.isEmpty ? 'Your location' : _c.address,
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}  ·  ±${p.accuracy.round()} m',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        if (session == null) ...[
          Text('Share for', style: text.labelLarge),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<Duration>(
              segments: const [
                ButtonSegment(value: Duration(minutes: 15), label: Text('15 min')),
                ButtonSegment(value: Duration(hours: 1), label: Text('1 hour')),
                ButtonSegment(value: Duration(hours: 8), label: Text('8 hours')),
              ],
              selected: {_duration},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _duration = s.first),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _c.busy ? null : () => _c.startSharing(_duration),
            icon: _c.busy
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share_location),
            label: const Text('Start sharing'),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Share code', style: text.labelSmall),
                      Text(
                        session.id,
                        style: text.bodyMedium?.copyWith(fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: session.id));
                    if (mounted) _snack('Code copied');
                  },
                ),
                IconButton.filledTonal(
                  tooltip: 'Share',
                  icon: const Icon(Icons.ios_share),
                  onPressed: () => Share.share(
                    'Follow my live location in Location Sharing. Open the Track tab and enter this code:\n${session.id}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: _c.stopSharing,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.errorContainer,
              foregroundColor: scheme.onErrorContainer,
            ),
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop sharing'),
          ),
        ],
        if (_c.error != null) ...[
          const SizedBox(height: 10),
          Text(_c.error!, style: text.bodySmall?.copyWith(color: scheme.error)),
        ],
      ],
    );
  }
}
