import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/place_info.dart';
import '../services/app_services.dart';
import '../services/links.dart';
import '../utils.dart';
import '../widgets/app_map.dart';
import '../widgets/map_panel.dart';
import 'saved_places_screen.dart';
import 'trip_screen.dart';

/// Shows one place on the map with actions: directions, save, share, trip.
class PlaceMapScreen extends StatefulWidget {
  const PlaceMapScreen({super.key, required this.place});
  final PlaceInfo place;

  @override
  State<PlaceMapScreen> createState() => _PlaceMapScreenState();
}

class _PlaceMapScreenState extends State<PlaceMapScreen> {
  final _ctl = AppMapController();

  @override
  void initState() {
    super.initState();
    _ctl.move(LatLng(widget.place.lat, widget.place.lng), zoom: 16);
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final here = AppServices.current.share.position;
    final dist = here == null
        ? place.distanceM
        : Geolocator.distanceBetween(here.latitude, here.longitude, place.lat, place.lng);
    final point = LatLng(place.lat, place.lng);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AppMap(
              controller: _ctl,
              focus: point,
              markerAt: point,
              bottomPadding: 300,
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
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MapPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  if (place.address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(place.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                  if (dist != null) ...[
                    const SizedBox(height: 8),
                    Chip(
                      avatar: const Icon(Icons.near_me_outlined, size: 18),
                      label: Text('${distanceLabel(dist)} away'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => openUri(context, directionsUri(place.lat, place.lng),
                        failMessage: 'Could not open a maps app.'),
                    icon: const Icon(Icons.directions_outlined),
                    label: const Text('Directions'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => showSavePlaceSheet(context, place),
                          icon: const Icon(Icons.bookmark_add_outlined),
                          label: const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Share.share(
                              '${place.name}\n${place.address}\n${mapsLink(place.lat, place.lng)}'.trim()),
                          icon: const Icon(Icons.ios_share),
                          label: const Text('Share'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => TripScreen(initialDestination: place))),
                          icon: const Icon(Icons.route_outlined),
                          label: const Text('Trip'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
