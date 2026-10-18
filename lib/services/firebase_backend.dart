import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/share_session.dart';
import 'backend.dart';

class FirebaseAuthBackend implements AuthBackend {
  final _auth = FirebaseAuth.instance;

  AppUser? _map(User? u) => u == null ? null : AppUser(uid: u.uid, email: u.email);

  @override
  AppUser? get current => _map(_auth.currentUser);

  @override
  Stream<AppUser?> get authChanges => _auth.authStateChanges().map(_map);

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_friendly(e));
    }
  }

  @override
  Future<void> register(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_friendly(e));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  String _friendly(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'network-request-failed':
        return 'No connection. Check your internet and retry.';
      case 'too-many-requests':
        return 'Too many attempts. Try again in a few minutes.';
      default:
        return e.message ?? 'Something went wrong.';
    }
  }
}

class FirebaseShareBackend implements ShareBackend {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _ref(String id) => _db.collection('shares').doc(id);

  @override
  String newId() => _db.collection('shares').doc().id;

  @override
  Future<void> create(ShareSession s) => _ref(s.id).set({
        'ownerId': s.ownerId,
        'latitude': s.latitude,
        'longitude': s.longitude,
        'address': s.address,
        'active': s.active,
        'expiresAt': s.expiresAt.millisecondsSinceEpoch,
        'updatedAt': FieldValue.serverTimestamp(),
        if (s.tripName != null) 'tripName': s.tripName,
        if (s.destinationName != null) 'destinationName': s.destinationName,
        if (s.destinationLat != null) 'destinationLat': s.destinationLat,
        if (s.destinationLng != null) 'destinationLng': s.destinationLng,
      });

  @override
  Future<void> updatePosition(String id, double lat, double lng, String address) =>
      _ref(id).update({
        'latitude': lat,
        'longitude': lng,
        'address': address,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> deactivate(String id) => _ref(id).update({'active': false});

  @override
  Stream<ShareSession?> watch(String id) => _ref(id).snapshots().map((snap) {
        if (!snap.exists) return null;
        final m = snap.data() ?? const <String, dynamic>{};
        return ShareSession(
          id: snap.id,
          ownerId: m['ownerId'] as String? ?? '',
          latitude: (m['latitude'] as num?)?.toDouble() ?? 0,
          longitude: (m['longitude'] as num?)?.toDouble() ?? 0,
          address: m['address'] as String? ?? '',
          active: m['active'] as bool? ?? false,
          expiresAt:
              DateTime.fromMillisecondsSinceEpoch((m['expiresAt'] as num?)?.toInt() ?? 0),
          updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
          tripName: m['tripName'] as String?,
          destinationName: m['destinationName'] as String?,
          destinationLat: (m['destinationLat'] as num?)?.toDouble(),
          destinationLng: (m['destinationLng'] as num?)?.toDouble(),
        );
      });
}
