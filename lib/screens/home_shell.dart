import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'share_screen.dart';
import 'track_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.user});
  final User user;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          ShareScreen(user: widget.user),
          const TrackScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.my_location_outlined),
            selectedIcon: Icon(Icons.my_location),
            label: 'Share',
          ),
          NavigationDestination(
            icon: Icon(Icons.travel_explore_outlined),
            selectedIcon: Icon(Icons.travel_explore),
            label: 'Track',
          ),
        ],
      ),
    );
  }
}
