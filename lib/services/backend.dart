import '../models/share_session.dart';
import 'demo_backend.dart';
import 'firebase_backend.dart';

/// Code of the pre-seeded share available in demo mode.
const demoShareCode = 'DEMO1234';

class AppUser {
  const AppUser({required this.uid, this.email});
  final String uid;
  final String? email;
}

class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class AuthBackend {
  AppUser? get current;
  Stream<AppUser?> get authChanges;
  Future<void> signIn(String email, String password);
  Future<void> register(String email, String password);
  Future<void> signOut();
}

abstract class ShareBackend {
  String newId();
  Future<void> create(ShareSession session);
  Future<void> updatePosition(String id, double lat, double lng, String address);
  Future<void> deactivate(String id);

  /// Emits null if the share doesn't exist. Emits an error if it is
  /// inactive/expired or the caller isn't allowed to read it.
  Stream<ShareSession?> watch(String id);
}

/// Either the real Firebase backend or an in-memory demo backend.
class Backend {
  Backend({required this.auth, required this.shares, required this.isDemo});

  final AuthBackend auth;
  final ShareBackend shares;
  final bool isDemo;

  static late Backend instance;

  factory Backend.firebase() =>
      Backend(auth: FirebaseAuthBackend(), shares: FirebaseShareBackend(), isDemo: false);

  factory Backend.demo() =>
      Backend(auth: DemoAuthBackend(), shares: DemoShareBackend(), isDemo: true);
}
