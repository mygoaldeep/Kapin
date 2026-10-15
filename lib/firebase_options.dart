// Firebase config. Values come from --dart-define so the project builds
// (locally and in CI) without committing keys. You can replace this whole
// file with the one `flutterfire configure` generates.
//
//   flutter run \
//     --dart-define=FIREBASE_API_KEY=... \
//     --dart-define=FIREBASE_APP_ID=... \
//     --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
//     --dart-define=FIREBASE_PROJECT_ID=... \
//     --dart-define=FIREBASE_STORAGE_BUCKET=...
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  /// Build with --dart-define=DEMO_MODE=true to force demo mode.
  static const bool forceDemo = bool.fromEnvironment('DEMO_MODE');

  static bool get isConfigured =>
      !forceDemo &&
      android.apiKey.isNotEmpty &&
      android.appId.isNotEmpty &&
      android.projectId.isNotEmpty;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Only Android is configured. Run `flutterfire configure` for other platforms.');
    }
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
  );
}
