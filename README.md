# Location Sharing (Flutter)

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

## Setup
```bash
# 1. Generate the native shells inside this folder
flutter create --org com.example --project-name location_sharing .

# 2. Dependencies
flutter pub get
#    If versions have moved on: flutter pub upgrade --major-versions

# 3. Firebase (creates lib/firebase_options.dart)
dart pub global activate flutterfire_cli
flutterfire configure
```
Then in the Firebase console: enable Email/Password auth, create Firestore,
and publish `firestore.rules`.

### Android
- Merge `android_setup/AndroidManifest.snippet.xml` into
  `android/app/src/main/AndroidManifest.xml`.
- Apply `android_setup/build.gradle.snippet.kts` to `android/app/build.gradle.kts`.
- Put your key in `android/local.properties`: `MAPS_API_KEY=...`
  (enable Maps SDK for Android in Google Cloud).

### iOS (optional)
Add `NSLocationWhenInUseUsageDescription` to `Info.plist` and provide the Maps key
as described in the `google_maps_flutter` docs.

```bash
flutter run
```

## Limits to know
- Sharing runs while the app is in the foreground. Continuous background
  sharing needs an Android foreground service (and background-location
  permission), which is not included.
- Expiry is enforced by the client and by the Firestore read rule. For
  production add App Check and a Cloud Function that deactivates expired shares.
