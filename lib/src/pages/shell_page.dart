import 'package:flutter/material.dart';

import 'history_page.dart';
import 'home_page.dart';
import 'profile_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomePage(),
      const HistoryPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
