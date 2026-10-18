import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/place_info.dart';

class PlacesException implements Exception {
  PlacesException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PlaceCategory {
  const PlaceCategory(this.id, this.label, this.icon, this.filters);
  final String id;
  final String label;
  final IconData icon;

  /// OpenStreetMap tag filters, e.g. `amenity=hospital`.
  final List<String> filters;
}

const placeCategories = <PlaceCategory>[
  PlaceCategory('hospital', 'Hospitals', Icons.local_hospital_outlined, ['amenity=hospital', 'amenity=clinic']),
  PlaceCategory('pharmacy', 'Pharmacies', Icons.medication_outlined, ['amenity=pharmacy']),
  PlaceCategory('police', 'Police', Icons.local_police_outlined, ['amenity=police']),
  PlaceCategory('fuel', 'Fuel', Icons.local_gas_station_outlined, ['amenity=fuel']),
  PlaceCategory('restaurant', 'Restaurants', Icons.restaurant_outlined, ['amenity=restaurant', 'amenity=fast_food']),
  PlaceCategory('cafe', 'Cafes', Icons.local_cafe_outlined, ['amenity=cafe']),
  PlaceCategory('atm', 'ATMs & banks', Icons.account_balance_outlined, ['amenity=atm', 'amenity=bank']),
  PlaceCategory('market', 'Supermarkets', Icons.local_grocery_store_outlined, ['shop=supermarket']),
  PlaceCategory('school', 'Schools', Icons.school_outlined, ['amenity=school']),
  PlaceCategory('hotel', 'Hotels', Icons.hotel_outlined, ['tourism=hotel']),
];

/// Place search (OpenStreetMap Nominatim) and nearby places (Overpass API).
/// Free and key-less; fine for testing. For heavy production use, host your
/// own instances or switch to the Google Places API.
class PlacesService {
  static const _headers = {
    'User-Agent': 'Kapin/1.0 (live location sharing app)',
    'Accept': 'application/json',
  };

  static Future<List<PlaceInfo>> search(String query, {double? nearLat, double? nearLng}) async {
    final params = <String, String>{
      'q': query,
      'format': 'jsonv2',
      'limit': '12',
    };
    if (nearLat != null && nearLng != null) {
      // Prefer (not require) results around the user.
      params['viewbox'] = '${nearLng - 0.6},${nearLat + 0.6},${nearLng + 0.6},${nearLat - 0.6}';
    }
    final http.Response res;
    try {
      res = await http
          .get(Uri.https('nominatim.openstreetmap.org', '/search', params), headers: _headers)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw PlacesException('Could not reach the search service. Check your connection.');
    }
    if (res.statusCode != 200) {
      throw PlacesException('Search failed (${res.statusCode}). Try again in a moment.');
    }
    final list = jsonDecode(res.body) as List;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      final display = (m['display_name'] as String?) ?? '';
      final parts = display.split(', ');
      final rawName = (m['name'] as String?) ?? '';
      final name = rawName.isNotEmpty ? rawName : (parts.isNotEmpty ? parts.first : 'Place');
      final lat = double.parse('${m['lat']}');
      final lng = double.parse('${m['lon']}');
      final dist = (nearLat != null && nearLng != null)
          ? Geolocator.distanceBetween(nearLat, nearLng, lat, lng)
          : null;
      return PlaceInfo(name: name, address: display, lat: lat, lng: lng, distanceM: dist);
    }).toList();
  }

  static Future<List<PlaceInfo>> nearby(
    double lat,
    double lng,
    PlaceCategory category, {
    int radius = 2000,
  }) async {
    final filters = category.filters.map((f) {
      final kv = f.split('=');
      return 'nwr(around:$radius,$lat,$lng)["${kv[0]}"="${kv[1]}"];';
    }).join();
    final query = '[out:json][timeout:20];($filters);out center 60;';

    final http.Response res;
    try {
      res = await http
          .get(Uri.https('overpass-api.de', '/api/interpreter', {'data': query}),
              headers: _headers)
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      throw PlacesException('Could not load nearby places. Check your connection.');
    }
    if (res.statusCode != 200) {
      throw PlacesException('The places service is busy (${res.statusCode}). Try again shortly.');
    }

    final elements = (jsonDecode(res.body)['elements'] as List?) ?? const [];
    final seen = <String>{};
    final out = <PlaceInfo>[];
    for (final e in elements) {
      final m = e as Map<String, dynamic>;
      final center = m['center'] as Map<String, dynamic>?;
      final pLat = (m['lat'] ?? center?['lat']) as num?;
      final pLng = (m['lon'] ?? center?['lon']) as num?;
      if (pLat == null || pLng == null) continue;
      final tags = (m['tags'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      final name = (tags['name'] ?? tags['name:en'] ?? tags['brand'] ?? category.label) as String;
      final street = [tags['addr:housenumber'], tags['addr:street'], tags['addr:city']]
          .where((v) => v != null && '$v'.trim().isNotEmpty)
          .join(' ');
      final key = '$name|${pLat.toStringAsFixed(4)}|${pLng.toStringAsFixed(4)}';
      if (!seen.add(key)) continue;
      out.add(PlaceInfo(
        name: name,
        address: street,
        lat: pLat.toDouble(),
        lng: pLng.toDouble(),
        distanceM: Geolocator.distanceBetween(lat, lng, pLat.toDouble(), pLng.toDouble()),
      ));
    }
    out.sort((a, b) => (a.distanceM ?? 0).compareTo(b.distanceM ?? 0));
    return out.take(40).toList();
  }
}
