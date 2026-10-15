# Kapin (Flutter)

A Flutter rebuild of the Kotlin/Compose location-sharing MVP, with a modern
Material 3 UI and live updates. Same Firebase data model, so the existing
Firestore documents and rules approach carry over.

## What's new
- Material 3 theme from a seed color, automatic light/dark
- Full-bleed map with a floating bottom panel and a one-tap recenter
- Live sharing: position streams to Firestore while a share is active
- Choose a duration (15 min / 1 h / 8 h) with a live countdown; auto-stops at expiry
- Copy or share the code with the system share sheet
- New **Track** tab: enter a code to follow someone's live location
- Friendly sign-in errors, password toggle, form validation
- Firestore rules now also enforce expiry on reads

## Build

### GitHub Actions (no local setup)
The workflow generates the Android project, patches it (`tool/patch_android.py`)
and builds a debug APK you can download from the run's Artifacts.
Add these repository secrets (Settings > Secrets and variables > Actions):
`MAPS_API_KEY`, `FIREBASE_API_KEY`, `FIREBASE_APP_ID`,
`FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_STORAGE_BUCKET`
(from your Firebase Android app config / `google-services.json`).
The APK builds even with empty secrets, but the app needs real values to run.

### Locally
```bash
flutter create --org com.kapin --project-name location_sharing --platforms=android .
rm -f test/widget_test.dart
python3 tool/patch_android.py
flutter pub get
export MAPS_API_KEY=your_maps_key
flutter run \
  --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_STORAGE_BUCKET=...
```
Or run `flutterfire configure` and let it overwrite `lib/firebase_options.dart`.

In Firebase: enable Email/Password auth, create Firestore, publish `firestore.rules`.
Enable Maps SDK for Android in Google Cloud.

## Limits to know
- Sharing runs while the app is in the foreground. Continuous background
  sharing needs an Android foreground service (and background-location
  permission), which is not included.
- Expiry is enforced by the client and by the Firestore read rule. For
  production add App Check and a Cloud Function that deactivates expired shares.
