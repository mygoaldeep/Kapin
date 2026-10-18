import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/records.dart';
import 'backend.dart';
import 'json_store.dart';
import 'share_controller.dart';

class AppSettings extends ChangeNotifier {
  AppSettings(this._uid);
  final String _uid;

  bool recordHistory = true;
  String emergencyNumber = '112';

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      recordHistory = sp.getBool('kapin.$_uid.recordHistory') ?? true;
      emergencyNumber = sp.getString('kapin.$_uid.emergencyNumber') ?? '112';
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setRecordHistory(bool v) async {
    recordHistory = v;
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setBool('kapin.$_uid.recordHistory', v);
    } catch (_) {}
  }

  Future<void> setEmergencyNumber(String v) async {
    emergencyNumber = v.trim().isEmpty ? '112' : v.trim();
    notifyListeners();
    try {
      (await SharedPreferences.getInstance())
          .setString('kapin.$_uid.emergencyNumber', emergencyNumber);
    } catch (_) {}
  }
}

/// Everything signed-in features share. Created once per signed-in user.
class AppServices {
  AppServices(this.user)
      : share = ShareController(user.uid),
        settings = AppSettings(user.uid),
        saved = JsonStore<SavedPlace>(
          prefsKey: 'kapin.${user.uid}.saved',
          fromJson: SavedPlace.fromJson,
          toJson: (e) => e.toJson(),
        ),
        family = JsonStore<FamilyMember>(
          prefsKey: 'kapin.${user.uid}.family',
          fromJson: FamilyMember.fromJson,
          toJson: (e) => e.toJson(),
        ),
        history = JsonStore<HistoryEntry>(
          prefsKey: 'kapin.${user.uid}.history',
          fromJson: HistoryEntry.fromJson,
          toJson: (e) => e.toJson(),
          maxItems: 500,
        ),
        trips = JsonStore<TripRecord>(
          prefsKey: 'kapin.${user.uid}.trips',
          fromJson: TripRecord.fromJson,
          toJson: (e) => e.toJson(),
          maxItems: 50,
        ) {
    share.onFix = _onFix;
    share.addListener(_watchTrip);
    _init();
  }

  static late AppServices current;

  final AppUser user;
  final ShareController share;
  final AppSettings settings;
  final JsonStore<SavedPlace> saved;
  final JsonStore<FamilyMember> family;
  final JsonStore<HistoryEntry> history;
  final JsonStore<TripRecord> trips;

  Position? _lastLogged;
  DateTime? _lastLoggedAt;
  bool _closingTrip = false;

  Future<void> _init() async {
    await Future.wait([settings.load(), saved.load(), family.load(), history.load(), trips.load()]);
    // A trip can't still be running after the app was closed.
    for (final t in trips.items.where((t) => t.isActive).toList()) {
      await trips.replaceWhere(
          (x) => x.id == t.id, t.copyWith(status: 'ended', endedAt: DateTime.now()));
    }
  }

  TripRecord? get activeTrip {
    for (final t in trips.items) {
      if (t.isActive) return t;
    }
    return null;
  }

  Future<void> logEvent(double lat, double lng, String address, String type,
      {String note = ''}) {
    return history.add(
      HistoryEntry(
        id: newId(),
        time: DateTime.now(),
        lat: lat,
        lng: lng,
        address: address,
        type: type,
        note: note,
      ),
      atStart: true,
    );
  }

  void _onFix(Position p, String address) {
    if (!settings.recordHistory) return;
    final last = _lastLogged;
    final at = _lastLoggedAt;
    final now = DateTime.now();
    if (last != null && at != null) {
      final moved =
          Geolocator.distanceBetween(last.latitude, last.longitude, p.latitude, p.longitude);
      if (moved < 100 && now.difference(at) < const Duration(minutes: 10)) return;
    }
    _lastLogged = p;
    _lastLoggedAt = now;
    logEvent(p.latitude, p.longitude, address, 'location');
  }

  void _watchTrip() {
    final t = activeTrip;
    if (t == null || _closingTrip) return;
    final p = share.position;
    if (p != null && share.isSharing) {
      final d = Geolocator.distanceBetween(p.latitude, p.longitude, t.destLat, t.destLng);
      if (d < 75) {
        finishTrip(t, 'arrived');
        return;
      }
    }
    if (!share.isSharing && DateTime.now().isAfter(t.plannedEnd)) {
      finishTrip(t, 'expired');
    }
  }

  /// Ends a trip, stops the share, and logs it.
  Future<void> finishTrip(TripRecord t, String status) async {
    if (_closingTrip) return;
    _closingTrip = true;
    try {
      await trips.replaceWhere(
          (x) => x.id == t.id, t.copyWith(status: status, endedAt: DateTime.now()));
      final p = share.position;
      if (p != null && (status == 'arrived' || status == 'stopped')) {
        await logEvent(p.latitude, p.longitude, share.address, 'arrival',
            note: status == 'arrived' ? 'Arrived at ${t.destName}' : 'Stopped trip to ${t.destName}');
      }
      if (status == 'arrived') HapticFeedback.heavyImpact();
      if (share.isSharing) await share.stopSharing();
    } finally {
      _closingTrip = false;
    }
  }

  void dispose() {
    share.removeListener(_watchTrip);
    share.dispose();
    settings.dispose();
    saved.dispose();
    family.dispose();
    history.dispose();
    trips.dispose();
  }
}
