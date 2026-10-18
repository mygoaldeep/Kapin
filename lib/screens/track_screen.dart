import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/share_session.dart';
import '../services/backend.dart';
import '../utils.dart';
import '../widgets/app_map.dart';
import '../widgets/map_panel.dart';
import '../widgets/pulse_dot.dart';

/// Follow someone else's live share by entering the code they sent you.
class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  final _code = TextEditingController();
  final _mapCtl = AppMapController();
  StreamSubscription<ShareSession?>? _sub;
  ShareSession? _session;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (Backend.instance.isDemo) _code.text = demoShareCode;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) _code.text = data!.text!.trim();
  }

  void _track() {
    final id = _code.text.trim();
    if (id.isEmpty || id.contains('/')) {
      setState(() => _error = 'Enter a valid share code.');
      return;
    }
    FocusScope.of(context).unfocus();
    _sub?.cancel();
    setState(() {
      _loading = true;
      _error = null;
      _session = null;
    });

    _sub = Backend.instance.shares.watch(id).listen(
      (s) {
        if (!mounted) return;
        if (s == null) {
          setState(() {
            _loading = false;
            _session = null;
            _error = 'No share found for that code.';
          });
          return;
        }
        setState(() {
          _loading = false;
          _session = s;
          _error = null;
        });
        _mapCtl.move(LatLng(s.latitude, s.longitude), zoom: 16);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _session = null;
          _error = 'This share has ended, or the code is invalid.';
        });
      },
    );
  }

  void _stop() {
    _sub?.cancel();
    setState(() {
      _session = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final point = s == null ? null : LatLng(s.latitude, s.longitude);

    return Stack(
      children: [
        Positioned.fill(
          child: AppMap(
            controller: _mapCtl,
            focus: point,
            markerAt: point,
            destination: s != null && s.hasDestination
                ? LatLng(s.destinationLat!, s.destinationLng!)
                : null,
            bottomPadding: s == null ? 0 : 290,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FloatingRoundButton(
                child: IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
                ),
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
  }

  Widget _buildPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = _session;

    if (s == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Track a share', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Enter the code someone sent you to see their live location.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          if (Backend.instance.isDemo) ...[
            const SizedBox(height: 6),
            Text('Test mode: tap Track to follow the demo friend ($demoShareCode), '
                'or track a code you shared from this device.',
                style: text.bodySmall?.copyWith(color: scheme.tertiary)),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _track(),
            decoration: InputDecoration(
              labelText: 'Share code',
              prefixIcon: const Icon(Icons.key_outlined),
              suffixIcon: IconButton(
                tooltip: 'Paste',
                icon: const Icon(Icons.content_paste_rounded),
                onPressed: _paste,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: text.bodySmall?.copyWith(color: scheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _track,
            icon: _loading
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.travel_explore),
            label: const Text('Track'),
          ),
        ],
      );
    }

    final live = s.isLive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (live) const PulseDot() else Icon(Icons.history, size: 16, color: scheme.outline),
            const SizedBox(width: 8),
            Text(
              live ? 'Live' : 'Sharing ended',
              style: text.labelLarge?.copyWith(
                color: live ? const Color(0xFF16A34A) : scheme.outline,
              ),
            ),
            const Spacer(),
            if (s.updatedAt != null)
              Text('Updated ${timeAgo(s.updatedAt!)}',
                  style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          s.address.isEmpty ? 'Shared location' : s.address,
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '${s.latitude.toStringAsFixed(5)}, ${s.longitude.toStringAsFixed(5)}',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (s.hasDestination) ...[
          const SizedBox(height: 10),
          Chip(
            avatar: const Icon(Icons.flag_rounded, size: 18),
            label: Text(
              '${s.destinationName ?? 'Destination'} \u00b7 '
              '${distanceLabel(Geolocator.distanceBetween(s.latitude, s.longitude, s.destinationLat!, s.destinationLng!))} away',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _stop,
          icon: const Icon(Icons.close),
          label: const Text('Stop tracking'),
        ),
      ],
    );
  }
}
