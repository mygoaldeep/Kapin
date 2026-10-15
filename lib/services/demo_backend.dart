import 'dart:async';
import 'dart:math';

import '../models/share_session.dart';
import 'backend.dart';

/// In-memory stand-in for Firebase, used until real credentials are provided.
/// Nothing is stored on a server and everything resets when the app restarts.
class DemoAuthBackend implements AuthBackend {
  final _ctrl = StreamController<AppUser?>.broadcast();
  final _accounts = <String, String>{}; // email -> password
  AppUser? _user;

  @override
  AppUser? get current => _user;

  @override
  Stream<AppUser?> get authChanges async* {
    yield _user;
    yield* _ctrl.stream;
  }

  void _set(String email) {
    _user = AppUser(uid: 'demo-${email.toLowerCase().hashCode.abs()}', email: email);
    _ctrl.add(_user);
  }

  @override
  Future<void> signIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final key = email.toLowerCase();
    final known = _accounts[key];
    if (known != null && known != password) {
      throw AuthFailure('Incorrect email or password.');
    }
    _accounts[key] = password; // test mode: any new email just works
    _set(email);
  }

  @override
  Future<void> register(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final key = email.toLowerCase();
    if (_accounts.containsKey(key)) {
      throw AuthFailure('An account with this email already exists.');
    }
    _accounts[key] = password;
    _set(email);
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _ctrl.add(null);
  }
}

class DemoShareBackend implements ShareBackend {
  DemoShareBackend() {
    _shares[demoShareCode] = ShareSession(
      id: demoShareCode,
      ownerId: 'demo-friend',
      latitude: 51.5007,
      longitude: -0.1246,
      address: 'Demo friend (moves every few seconds)',
      active: true,
      expiresAt: DateTime.now().add(const Duration(days: 365)),
      updatedAt: DateTime.now(),
    );
    // Make the demo friend wander so live updates are visible.
    Timer.periodic(const Duration(seconds: 3), (_) {
      final c = _ctrls[demoShareCode];
      final s = _shares[demoShareCode];
      if (c == null || !c.hasListener || s == null) return;
      _shares[demoShareCode] = s.copyWith(
        latitude: s.latitude + (_rand.nextDouble() - 0.5) * 0.0004,
        longitude: s.longitude + (_rand.nextDouble() - 0.5) * 0.0004,
        updatedAt: DateTime.now(),
      );
      _emit(demoShareCode);
    });
  }

  final _shares = <String, ShareSession>{};
  final _ctrls = <String, StreamController<ShareSession?>>{};
  final _rand = Random();

  @override
  String newId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(10, (_) => chars[_rand.nextInt(chars.length)]).join();
  }

  @override
  Future<void> create(ShareSession s) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _shares[s.id] = s.copyWith(updatedAt: DateTime.now());
    _emit(s.id);
  }

  @override
  Future<void> updatePosition(String id, double lat, double lng, String address) async {
    final s = _shares[id];
    if (s == null) return;
    _shares[id] = s.copyWith(
        latitude: lat, longitude: lng, address: address, updatedAt: DateTime.now());
    _emit(id);
  }

  @override
  Future<void> deactivate(String id) async {
    final s = _shares[id];
    if (s == null) return;
    _shares[id] = s.copyWith(active: false);
    _emit(id);
  }

  void _emit(String id) {
    final c = _ctrls[id];
    final s = _shares[id];
    if (c == null || s == null) return;
    if (s.isLive) {
      c.add(s);
    } else {
      c.addError(StateError('permission-denied')); // mirrors the Firestore rule
    }
  }

  @override
  Stream<ShareSession?> watch(String id) async* {
    final c = _ctrls.putIfAbsent(id, () => StreamController<ShareSession?>.broadcast());
    final s = _shares[id];
    if (s == null) {
      yield null;
    } else if (!s.isLive) {
      throw StateError('permission-denied');
    } else {
      yield s;
    }
    yield* c.stream;
  }
}
