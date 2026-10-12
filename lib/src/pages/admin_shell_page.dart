import 'package:flutter/material.dart';

import '../app.dart';
import '../ui.dart';
import 'admin_dashboard_page.dart';
import 'landing_page.dart';

class AdminShellPage extends StatelessWidget {
  const AdminShellPage({super.key});

  Future<void> _logout(BuildContext context) async {
    AppScope.of(context).session.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LandingPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).session.user;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Admin dashboard'),
            Text(
              user?.fullName ?? 'Administrator',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: kRentGoText.withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: const SafeArea(child: AdminDashboardPage()),
    );
  }
}
