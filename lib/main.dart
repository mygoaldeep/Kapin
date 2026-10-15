import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart'; // values come from --dart-define (see file)
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'services/backend.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Backend.instance = await _initBackend();
  runApp(const LocationSharingApp());
}

/// Uses real Firebase when its settings are present; otherwise (or if it
/// fails to start) falls back to the in-memory demo backend so the app is
/// always usable for testing.
Future<Backend> _initBackend() async {
  try {
    if (!DefaultFirebaseOptions.isConfigured) return Backend.demo();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 15));
    return Backend.firebase();
  } catch (_) {
    return Backend.demo();
  }
}

class LocationSharingApp extends StatelessWidget {
  const LocationSharingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Backend.instance.auth;
    return MaterialApp(
      title: 'Kapin',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: StreamBuilder<AppUser?>(
        stream: auth.authChanges,
        initialData: auth.current,
        builder: (context, snap) {
          final user = snap.data;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: user == null
                ? const AuthScreen(key: ValueKey('auth'))
                : HomeShell(key: ValueKey(user.uid), user: user),
          );
        },
      ),
    );
  }
}
