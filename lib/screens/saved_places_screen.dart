import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/place_info.dart';
import '../models/records.dart';
import '../services/app_services.dart';
import '../services/links.dart';
import '../services/location_service.dart';
import '../utils.dart';
import '../widgets/common.dart';
import 'place_map_screen.dart';

/// Bottom sheet to save a place with a name and kind.
Future<void> showSavePlaceSheet(BuildContext context, PlaceInfo place, {String? initialKind}) async {
  final name = TextEditingController(text: place.name);
  var kind = initialKind ?? 'favorite';
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 4, 20, MediaQuery.viewInsetsOf(ctx).bottom + MediaQuery.paddingOf(ctx).bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Save place',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.edit_outlined)),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in placeKinds.entries)
                    ChoiceChip(
                      avatar: Icon(placeKindIcon(e.key), size: 18),
                      label: Text(e.value),
                      selected: kind == e.key,
                      onSelected: (_) => setSheet(() => kind = e.key),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    },
  );
  final finalName = name.text.trim();
  if (saved != true) return;
  await AppServices.current.saved.add(
    SavedPlace(
      id: newId(),
      name: finalName.isEmpty ? place.name : finalName,
      kind: kind,
      lat: place.lat,
      lng: place.lng,
      address: place.address,
    ),
    atStart: true,
  );
  if (context.mounted) toast(context, 'Saved "${finalName.isEmpty ? place.name : finalName}"');
}

class SavedPlacesScreen extends StatefulWidget {
  const SavedPlacesScreen({super.key, this.pickMode = false});
  final bool pickMode;

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  final _s = AppServices.current;
  bool _locating = false;

  Future<void> _saveCurrent() async {
    setState(() => _locating = true);
    try {
      final p = _s.share.position ?? await LocationService.current();
      final addr = _s.share.address.isNotEmpty
          ? _s.share.address
          : await LocationService.addressFor(p.latitude, p.longitude);
      if (!mounted) return;
      setState(() => _locating = false);
      await showSavePlaceSheet(
        context,
        PlaceInfo(name: 'My location', address: addr, lat: p.latitude, lng: p.longitude),
        initialKind: 'home',
      );
    } on AppException catch (e) {
      toast(context, e.message);
    } catch (_) {
      toast(context, 'Could not get your location.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.pickMode ? 'Choose a saved place' : 'Saved places')),
      floatingActionButton: widget.pickMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _locating ? null : _saveCurrent,
              icon: _locating
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_location_alt_outlined),
              label: const Text('Save current location'),
            ),
      body: ListenableBuilder(
        listenable: _s.saved,
        builder: (context, _) {
          final items = _s.saved.items;
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'No saved places yet',
              message:
                  'Save Home, Work, school and other spots. You can also save any result from Find a place or Nearby places.',
            );
          }
          final here = _s.share.position;
          return ListView.separated(
            padding: listPadding(context).copyWith(bottom: MediaQuery.paddingOf(context).bottom + 96),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = items[i];
              final dist = here == null
                  ? null
                  : Geolocator.distanceBetween(here.latitude, here.longitude, p.lat, p.lng);
              final info = PlaceInfo(
                  name: p.name, address: p.address, lat: p.lat, lng: p.lng, distanceM: dist);
              return Material(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
                child: ListTile(
                  onTap: () {
                    if (widget.pickMode) {
                      Navigator.pop(context, info);
                    } else {
                      Navigator.push(
                          context, MaterialPageRoute(builder: (_) => PlaceMapScreen(place: info)));
                    }
                  },
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(placeKindIcon(p.kind), color: scheme.onPrimaryContainer),
                  ),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    [if (dist != null) distanceLabel(dist), if (p.address.isNotEmpty) p.address].join(' \u00b7 '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: widget.pickMode
                      ? null
                      : IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            _s.saved.removeWhere((x) => x.id == p.id);
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(SnackBar(
                                content: Text('Removed "${p.name}"'),
                                action: SnackBarAction(
                                    label: 'Undo', onPressed: () => _s.saved.add(p, atStart: true)),
                              ));
                          },
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
