import 'package:flutter/material.dart';

import '../ui.dart';
import 'admin_login_page.dart';
import 'login_page.dart';
import 'register_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4F1EA), Color(0xFFEAF7F4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kRentGoPrimary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.electric_scooter_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RentGo Tunisia', style: Theme.of(context).textTheme.titleLarge),
                        Text(
                          'Bike & scooter rental',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kRentGoText.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                AppHeroFrame(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusPill(label: 'Prototype-ready mobile experience', color: Colors.white.withValues(alpha: 0.9)),
                        const SizedBox(height: 18),
                        Text(
                          'Move through the city with a cleaner, faster ride.',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, height: 1.02),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Find a nearby bike or scooter, unlock with QR, start the ride, and manage your trip from one clean app.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.86)),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            MetricTile(
                              value: '24/7',
                              label: 'Availability',
                              icon: Icons.access_time_rounded,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            MetricTile(
                              value: '0.15',
                              label: 'From TND/min',
                              icon: Icons.payments_rounded,
                              color: Colors.white,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        AppButton(
                          label: 'Get started',
                          icon: Icons.arrow_forward_rounded,
                          expanded: true,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const RegisterPage()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                AppPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What you can do', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      const _FeatureRow(
                        icon: Icons.pin_drop_rounded,
                        title: 'Find nearby vehicles',
                        subtitle: 'See available bikes and scooters around you.',
                      ),
                      const SizedBox(height: 14),
                      const _FeatureRow(
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'Scan or type a QR code',
                        subtitle: 'Unlock a vehicle by using the QR code on the device.',
                      ),
                      const SizedBox(height: 14),
                      const _FeatureRow(
                        icon: Icons.receipt_long_rounded,
                        title: 'Track trips and costs',
                        subtitle: 'Review the full ride history and payment summary.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Login',
                        icon: Icons.login_rounded,
                        expanded: true,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LoginPage()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RegisterPage()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          side: const BorderSide(color: kRentGoPrimary),
                        ),
                        child: const Text('Register'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AdminLoginPage()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kRentGoText,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      side: BorderSide(color: kRentGoText.withValues(alpha: 0.18)),
                    ),
                    icon: const Icon(Icons.admin_panel_settings_rounded),
                    label: const Text('Admin access'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kRentGoPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: kRentGoPrimary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kRentGoText.withValues(alpha: 0.65)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
