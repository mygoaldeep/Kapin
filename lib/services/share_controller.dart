import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/share_session.dart';
import 'backend.dart';

class AppException implements Exception {
  AppException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Owns location, reverse geocoding and the active share session.
/// While a share is live, position updates are pushed to Firestore.
class ShareController extends ChangeNotifier {
  ShareController(this.userId);

  final String userId;
  final _shares = Backend.instance.shares;

  Position? position;
  String address = '';
  ShareSession? session;
  String? error;
  bool locating = false;
  bool busy = false;

  /// Ticks every second while sharing; separate so only the countdown rebuilds.
  final remaining = ValueNotifier<Duration>(Duration.zero);

  StreamSubscription<Position>? _positionSub;
  Timer? _ticker;
  Position? _lastGeocoded;

  bool get isSharing => session != null;

  Future<void> locate() async {
    locating = true;
    error = null;
    notifyListeners();
    try {
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
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _refreshAddress(position!);
    } catch (e) {
      error = e is AppException ? e.message : 'Could not get your location.';
    }
    locating = false;
    notifyListeners();
  }

  Future<void> _refreshAddress(Position p) async {
    _lastGeocoded = p;
    try {
      final marks = await placemarkFromCoordinates(p.latitude, p.longitude);
      if (marks.isEmpty) {
        address = 'Address unavailable';
        return;
      }
      final m = marks.first;
      final parts = <String?>[m.street, m.locality, m.country]
          .where((s) => s != null && s.trim().isNotEmpty)
          .cast<String>();
      address = parts.isEmpty ? 'Address unavailable' : parts.join(', ');
    } catch (_) {
      address = 'Address unavailable';
    }
  }

  Future<void> startSharing(Duration duration) async {
    final p = position;
    if (p == null || busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final s = ShareSession(
        id: _shares.newId(), // random, unguessable id
        ownerId: userId,
        latitude: p.latitude,
        longitude: p.longitude,
        address: address,
        active: true,
        expiresAt: DateTime.now().add(duration),
      );
      await _shares.create(s);
      session = s;
      _beginTracking();
    } catch (_) {
      error = 'Could not start sharing. Check your connection and try again.';
    }
    busy = false;
    notifyListeners();
  }

  void _beginTracking() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen(_onPosition, onError: (_) {});

    _ticker?.cancel();
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final s = session;
    if (s == null) return;
    final left = s.expiresAt.difference(DateTime.now());
    remaining.value = left;
    if (left <= Duration.zero) stopSharing();
  }

  Future<void> _onPosition(Position p) async {
    position = p;
    final s = session;
    if (s == null) {
      notifyListeners();
      return;
    }
    final last = _lastGeocoded;
    if (last == null ||
        Geolocator.distanceBetween(last.latitude, last.longitude, p.latitude, p.longitude) > 100) {
      await _refreshAddress(p);
    }
    notifyListeners();
    try {
      await _shares.updatePosition(s.id, p.latitude, p.longitude, address);
    } catch (_) {/* transient; next update retries */}
  }

  Future<void> stopSharing() async {
    final s = session;
    if (s == null) return;
    _positionSub?.cancel();
    _positionSub = null;
    _ticker?.cancel();
    _ticker = null;
    session = null;
    notifyListeners();
    try {
      await _shares.deactivate(s.id);
    } catch (_) {
      error = 'Sharing stopped locally, but the server could not be updated.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _ticker?.cancel();
    remaining.dispose();
    super.dispose();
  }
}
