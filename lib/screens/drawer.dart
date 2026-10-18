import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/backend.dart';
import '../theme.dart';
import 'check_in_screen.dart';
import 'family_screen.dart';
import 'find_place_screen.dart';
import 'history_screen.dart';
import 'nearby_screen.dart';
import 'saved_places_screen.dart';
import 'sos_screen.dart';
import 'trip_screen.dart';

/// The app menu (top-left hamburger).
class KapinDrawer extends StatelessWidget {
  const KapinDrawer({super.key, required this.user, required this.onSelectTab});
  final AppUser user;

  /// Switch the bottom-nav tab (0 = Share, 1 = Track).
  final void Function(int index) onSelectTab;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final email = user.email ?? 'Signed in';

    Widget item(IconData icon, String label, Widget Function() screen, {Color? color}) {
      return ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        onTap: () {
          final nav = Navigator.of(context);
          nav.pop();
          nav.push(MaterialPageRoute(builder: (_) => screen()));
        },
      );
    }

    Widget tab(IconData icon, String label, int index) => ListTile(
          leading: Icon(icon),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          onTap: () {
            Navigator.of(context).pop();
            onSelectTab(index);
          },
        );

    Widget heading(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(28, 14, 16, 4),
          child: Text(t.toUpperCase(),
              style: text.labelSmall?.copyWith(
                  letterSpacing: 1, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
        );

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.paddingOf(context).top + 24, 24, 24),
            decoration: BoxDecoration(gradient: brandGradient(scheme)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  child: Text(email[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 14),
                Text('Kapin',
                    style: text.titleLarge
                        ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                Text(email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.88))),
                if (Backend.instance.isDemo) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('TEST MODE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8)),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                heading('Home'),
                tab(Icons.my_location_outlined, 'Share my location', 0),
                tab(Icons.travel_explore_outlined, 'Track someone', 1),
                heading('Places'),
                item(Icons.search, 'Find a place', () => const FindPlaceScreen()),
                item(Icons.explore_outlined, 'Nearby places', () => const NearbyScreen()),
                item(Icons.bookmark_border_rounded, 'Saved places', () => const SavedPlacesScreen()),
                heading('People & trips'),
                item(Icons.family_restroom_outlined, 'Family & friends', () => const FamilyScreen()),
                item(Icons.route_outlined, 'Share a trip', () => const TripScreen()),
                item(Icons.check_circle_outline, 'Check in', () => const CheckInScreen()),
                heading('Safety'),
                item(Icons.sos_rounded, 'SOS', () => const SosScreen(), color: scheme.error),
                item(Icons.history_rounded, 'Location history', () => const HistoryScreen()),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.of(context).pop();
                await AppServices.current.share.stopSharing();
                await Backend.instance.auth.signOut();
              },
            ),
          ),
        ],
      ),
    );
  }
}
