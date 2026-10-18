import 'package:flutter/material.dart';

import '../models/place_info.dart';
import '../services/app_services.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';
import '../utils.dart';
import '../widgets/common.dart';
import 'place_map_screen.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  PlaceCategory _category = placeCategories.first;
  int _radius = 2000;
  List<PlaceInfo> _results = const [];
  bool _loading = false;
  String? _error;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ++_token;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = AppServices.current.share;
      final p = s.position ?? await LocationService.current();
      final r = await PlacesService.nearby(p.latitude, p.longitude, _category, radius: _radius);
      if (!mounted || token != _token) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted || token != _token) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } on PlacesException catch (e) {
      if (!mounted || token != _token) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() {
        _error = 'Something went wrong. Try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby places')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: placeCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final c = placeCategories[i];
                return ChoiceChip(
                  avatar: Icon(c.icon, size: 18),
                  label: Text(c.label),
                  selected: _category.id == c.id,
                  onSelected: (_) {
                    setState(() => _category = c);
                    _load();
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1000, label: Text('1 km')),
                  ButtonSegment(value: 3000, label: Text('3 km')),
                  ButtonSegment(value: 5000, label: Text('5 km')),
                ],
                selected: {_radius},
                showSelectedIcon: false,
                onSelectionChanged: (s) {
                  setState(() => _radius = s.first);
                  _load();
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
        icon: Icons.location_off_outlined,
        title: 'Couldn\'t load places',
        message: _error!,
        action: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
            onPressed: _load,
            child: const Text('Retry')),
      );
    }
    if (!_loading && _results.isEmpty) {
      return EmptyState(
        icon: _category.icon,
        title: 'No ${_category.label.toLowerCase()} found',
        message: 'Nothing mapped within ${_radius ~/ 1000} km. Try a wider radius.',
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
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => PlaceMapScreen(place: p))),
            leading: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(_category.icon, color: scheme.onPrimaryContainer),
            ),
            title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: p.address.isEmpty ? null : Text(p.address, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text(distanceLabel(p.distanceM),
                style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
          ),
        );
      },
    );
  }
}
