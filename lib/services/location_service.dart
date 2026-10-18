import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class AppException implements Exception {
  AppException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LocationService {
  /// Gets the current position, asking for permission if needed.
  static Future<Position> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw AppException('Location services are turned off.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw AppException('Location permission was denied.');
    }
    if (perm == LocationPermission.deniedForever) {
      throw AppException('Location permission is blocked. Enable it in system settings.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  static Future<String> addressFor(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return 'Address unavailable';
      final m = marks.first;
      final parts = <String?>[m.street, m.locality, m.country]
          .where((s) => s != null && s.trim().isNotEmpty)
          .cast<String>();
      return parts.isEmpty ? 'Address unavailable' : parts.join(', ');
    } catch (_) {
      return 'Address unavailable';
    }
  }
}
