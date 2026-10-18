import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';

import '../models/place_info.dart';
import '../models/records.dart';
import '../services/app_services.dart';
import '../services/links.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import 'family_screen.dart';
import 'find_place_screen.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({super.key, this.initialDestination});
  final PlaceInfo? initialDestination;

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  final _s = AppServices.current;
  final _name = TextEditingController();
  PlaceInfo? _dest;
  Duration _duration = const Duration(hours: 2);
  late final Set<String> _recipients = {for (final m in _s.family.items) m.id};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDestination != null) _setDest(widget.initialDestination!);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _setDest(PlaceInfo p) {
    _dest = p;
    _name.text = 'Trip to ${p.name}';
  }

  Future<void> _pickDestination() async {
    final p = await Navigator.push<PlaceInfo>(
        context, MaterialPageRoute(builder: (_) => const FindPlaceScreen(pickMode: true)));
    if (p != null && mounted) setState(() => _setDest(p));
  }

  String _tripMessage(TripRecord t) => liveShareMessage(
        t.shareId,
        lead: 'I\'m on my way to ${t.destName}. Follow my trip live on Kapin.',
      );

  Future<void> _sendMessage(TripRecord t) async {
    final phones = [
      for (final m in _s.family.items)
        if (t.recipients.contains(m.id)) m.phone
    ];
    final msg = '${_tripMessage(t)}\nDestination: ${mapsLink(t.destLat, t.destLng)}';
    if (phones.isEmpty) {
      await Share.share(msg);
    } else {
      await composeSms(context, phones, msg);
    }
  }

  Future<void> _start() async {
    final dest = _dest;
    if (dest == null) {
      toast(context, 'Choose a destination first.');
      return;
    }
    setState(() => _busy = true);
    try {
      if (_s.share.isSharing) await _s.share.stopSharing();
      if (_s.share.position == null) await _s.share.locate();
      if (_s.share.position == null) {
        if (mounted) toast(context, _s.share.error ?? 'Could not get your location.');
        return;
      }
      final name = _name.text.trim().isEmpty ? 'Trip to ${dest.name}' : _name.text.trim();
      await _s.share.startSharing(_duration, tripName: name, destination: dest);
      final session = _s.share.session;
      if (session == null) {
        if (mounted) toast(context, _s.share.error ?? 'Could not start the trip.');
        return;
      }
      final trip = TripRecord(
        id: newId(),
        name: name,
        destName: dest.name,
        destAddress: dest.address,
        destLat: dest.lat,
        destLng: dest.lng,
        startedAt: DateTime.now(),
        plannedEnd: session.expiresAt,
        shareId: session.id,
        recipients: _recipients.toList(),
      );
      await _s.trips.add(trip, atStart: true);
      final p = _s.share.position!;
      await _s.logEvent(p.latitude, p.longitude, _s.share.address, 'trip',
          note: 'Started trip to ${dest.name}');
      if (mounted) await _sendMessage(trip);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const _statusLabels = {
    'arrived': 'Arrived',
    'stopped': 'Stopped',
    'expired': 'Timed out',
    'ended': 'Ended',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Share a trip')),
      body: ListenableBuilder(
        listenable: Listenable.merge([_s.trips, _s.share, _s.family, _s.saved]),
        builder: (context, _) {
          final active = _s.activeTrip;
          final past = _s.trips.items.where((t) => !t.isActive).take(8).toList();
          return ListView(
            padding: listPadding(context),
            children: [
              if (active != null) _activeCard(context, active) else _form(context),
              if (past.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Past trips',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final t in past)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: t.status == 'arrived'
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                      child: Icon(
                        t.status == 'arrived' ? Icons.flag_rounded : Icons.route_outlined,
                        color: t.status == 'arrived'
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${_statusLabels[t.status] ?? 'Ended'} \u00b7 ${dayLabel(t.startedAt)}, ${clockLabel(t.startedAt)}'),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _activeCard(BuildContext context, TripRecord t) {
    final scheme = Theme.of(context).colorScheme;
    final p = _s.share.position;
    final dist = p == null
        ? null
        : Geolocator.distanceBetween(p.latitude, p.longitude, t.destLat, t.destLng);
    const onGrad = Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: brandGradient(scheme),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.route_rounded, color: onGrad, size: 20),
                  SizedBox(width: 8),
                  Text('TRIP IN PROGRESS',
                      style: TextStyle(
                          color: onGrad, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ],
              ),
              const SizedBox(height: 12),
              Text(t.destName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: onGrad, fontSize: 24, fontWeight: FontWeight.w800)),
              if (t.destAddress.isNotEmpty)
                Text(t.destAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: onGrad.withValues(alpha: 0.85))),
              const SizedBox(height: 16),
              Row(
                children: [
                  _stat('Distance', dist == null ? '-' : distanceLabel(dist)),
                  const SizedBox(width: 24),
                  ValueListenableBuilder<Duration>(
                    valueListenable: _s.share.remaining,
                    builder: (_, d, __) => _stat('Sharing for', formatRemaining(d)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => _s.finishTrip(t, 'arrived'),
          icon: const Icon(Icons.flag_outlined),
          label: const Text('I\'ve arrived'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () => _sendMessage(t),
          icon: const Icon(Icons.ios_share),
          label: const Text('Send trip link again'),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => _s.finishTrip(t, 'stopped'),
          child: const Text('Stop trip'),
        ),
        const SizedBox(height: 4),
        Text(
          'The trip ends automatically when you arrive (within about 75 m) or when the time runs out. Keep Kapin open while travelling.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      );

  Widget _form(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final saved = _s.saved.items.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Let people follow you to your destination, live.',
            style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        if (_dest == null)
          SoftCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              onTap: _pickDestination,
              leading: Icon(Icons.search, color: scheme.primary),
              title: const Text('Choose destination'),
              subtitle: const Text('Search a place or pick a saved one'),
              trailing: const Icon(Icons.chevron_right),
            ),
          )
        else
          SoftCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              onTap: _pickDestination,
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Icon(Icons.flag_rounded, color: scheme.onPrimaryContainer),
              ),
              title: Text(_dest!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: _dest!.address.isEmpty
                  ? null
                  : Text(_dest!.address, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Text('Change'),
            ),
          ),
        if (saved.isNotEmpty && _dest == null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in saved)
                ActionChip(
                  avatar: Icon(placeKindIcon(p.kind), size: 18),
                  label: Text(p.name),
                  onPressed: () => setState(() => _setDest(
                      PlaceInfo(name: p.name, address: p.address, lat: p.lat, lng: p.lng))),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
              labelText: 'Trip name', prefixIcon: Icon(Icons.edit_road_outlined)),
        ),
        const SizedBox(height: 16),
        Text('Share for', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final d in const [
              Duration(minutes: 30),
              Duration(hours: 1),
              Duration(hours: 2),
              Duration(hours: 4),
              Duration(hours: 8),
            ])
              ChoiceChip(
                label: Text(durationLabel(d)),
                selected: _duration == d,
                onSelected: (_) => setState(() => _duration = d),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Send to', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (_s.family.items.isEmpty)
          Text('No contacts yet. You can still send the trip link with any app.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _s.family.items)
                FilterChip(
                  label: Text(m.name),
                  selected: _recipients.contains(m.id),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _recipients.add(m.id);
                    } else {
                      _recipients.remove(m.id);
                    }
                  }),
                ),
            ],
          ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _busy ? null : _start,
          icon: _busy
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.play_arrow_rounded),
          label: const Text('Start trip & share'),
        ),
      ],
    );
  }
}
