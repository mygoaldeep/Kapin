import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart'; // values come from --dart-define (see file)
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'screens/splash_screen.dart';
import 'services/backend.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Android 15+ draws edge-to-edge; opt in explicitly on every version.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const Bootstrap());
}

/// Uses real Firebase when its settings are present; otherwise (or if it
/// fails to start) falls back to the in-memory demo backend. Never throws.
Future<Backend> _initBackend() async {
  try {
    if (!DefaultFirebaseOptions.isConfigured) return Backend.demo();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 12));
    return Backend.firebase();
  } catch (_) {
    return Backend.demo();
  }
}

/// Paints the first frame immediately (branded splash) while the backend starts,
/// so the app can never sit on a blank launch screen.
class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late final Future<Backend> _init = _initBackend().then((b) => Backend.instance = b);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Backend>(
      future: _init,
      builder: (context, snap) {
        if (!snap.hasData) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            home: const SplashScreen(),
          );
        }
        return const LocationSharingApp();
      },
    );
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
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
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
