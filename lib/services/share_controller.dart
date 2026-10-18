import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/place_info.dart';
import '../models/share_session.dart';
import 'backend.dart';
import 'location_service.dart';

/// Owns location, reverse geocoding and the active share session.
/// While a share is live, position updates are pushed to the backend.
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

  /// Called whenever a fresh position + address is known (used for history).
  void Function(Position position, String address)? onFix;

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
      position = await LocationService.current();
      await _refreshAddress(position!);
      onFix?.call(position!, address);
    } catch (e) {
      error = e is AppException ? e.message : 'Could not get your location.';
    }
    locating = false;
    notifyListeners();
  }

  Future<void> _refreshAddress(Position p) async {
    _lastGeocoded = p;
    address = await LocationService.addressFor(p.latitude, p.longitude);
  }

  /// Starts sharing if not already sharing. Returns the live session, or null.
  Future<ShareSession?> ensureSharing(Duration duration) async {
    if (session != null) return session;
    if (position == null) await locate();
    if (position == null) return null;
    await startSharing(duration);
    return session;
  }

  Future<void> startSharing(Duration duration, {String? tripName, PlaceInfo? destination}) async {
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
        tripName: tripName,
        destinationName: destination?.name,
        destinationLat: destination?.lat,
        destinationLng: destination?.lng,
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
    onFix?.call(p, address);
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
