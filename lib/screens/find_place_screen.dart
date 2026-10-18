import 'dart:async';

import 'package:flutter/material.dart';

import '../models/place_info.dart';
import '../services/app_services.dart';
import '../services/places_service.dart';
import '../utils.dart';
import '../widgets/common.dart';
import 'place_map_screen.dart';
import 'saved_places_screen.dart';

class FindPlaceScreen extends StatefulWidget {
  const FindPlaceScreen({super.key, this.pickMode = false});

  /// When true, tapping a result returns it to the caller instead of opening it.
  final bool pickMode;

  @override
  State<FindPlaceScreen> createState() => _FindPlaceScreenState();
}

class _FindPlaceScreenState extends State<FindPlaceScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<PlaceInfo> _results = const [];
  bool _loading = false;
  bool _searched = false;
  String? _error;
  int _token = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.trim().length < 3) {
      setState(() {
        _results = const [];
        _searched = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 800), _search);
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) return;
    final token = ++_token;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final here = AppServices.current.share.position;
      final r = await PlacesService.search(q, nearLat: here?.latitude, nearLng: here?.longitude);
      if (!mounted || token != _token) return;
      setState(() {
        _results = r;
        _searched = true;
        _loading = false;
      });
    } on PlacesException catch (e) {
      if (!mounted || token != _token) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _open(PlaceInfo p) {
    if (widget.pickMode) {
      Navigator.pop(context, p);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PlaceMapScreen(place: p)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.pickMode ? 'Choose destination' : 'Find a place')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (_) {
                _debounce?.cancel();
                _search();
              },
              decoration: InputDecoration(
                hintText: 'Street, business or landmark',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _query.clear();
                          _onChanged('');
                        },
                      ),
              ),
            ),
          ),
          if (widget.pickMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(Icons.bookmark_outline, size: 18),
                  label: const Text('Pick from saved places'),
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final p = await nav.push<PlaceInfo>(MaterialPageRoute(
                        builder: (_) => const SavedPlacesScreen(pickMode: true)));
                    if (p != null && mounted) nav.pop(p);
                  },
                ),
              ),
            ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _body(scheme)),
        ],
      ),
    );
  }

  Widget _body(ColorScheme scheme) {
    if (_error != null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Search unavailable',
        message: _error!,
        action: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
            onPressed: _search,
            child: const Text('Retry')),
      );
    }
    if (!_searched && !_loading) {
      return const EmptyState(
        icon: Icons.travel_explore_rounded,
        title: 'Find a place',
        message: 'Type at least 3 letters. Results near you are shown first.',
      );
    }
    if (_searched && _results.isEmpty && !_loading) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results',
        message: 'Try a different spelling or add the city name.',
      );
    }
    return ListView.separated(
      padding: listPadding(context),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final p = _results[i];
        return Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          child: ListTile(
            onTap: () => _open(p),
            leading: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.place_rounded, color: scheme.onPrimaryContainer),
            ),
            title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(p.address, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: p.distanceM == null
                ? null
                : Text(distanceLabel(p.distanceM),
                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
          ),
        );
      },
    );
  }
}
