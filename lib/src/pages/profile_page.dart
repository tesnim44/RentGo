import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import '../ui.dart';
import 'landing_page.dart';
import 'wallet_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<AppUser> _future;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _future = _load();
      _initialized = true;
    }
  }

  Future<AppUser> _load() async {
    final scope = AppScope.of(context);
    final token = scope.session.token;
    if (token == null) throw ApiException('Login required.');
    final profile = await scope.api.fetchProfile(token);
    scope.session.setSession(UserSession(token: token, user: profile));
    return profile;
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _logout() async {
    AppScope.of(context).session.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LandingPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser>(
      future: _future,
      builder: (context, snapshot) {
        final user = snapshot.data ?? AppScope.of(context).session.user;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kRentGoPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.person_rounded, color: kRentGoPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profile', style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        'Manage your account and session.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kRentGoText.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (snapshot.hasError)
              AppPanel(
                child: Text(
                  snapshot.error.toString(),
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: kRentGoPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.person_rounded, color: kRentGoPrimary, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.fullName ?? 'User', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 4),
                            Text(
                              user?.phoneNumber ?? '--',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kRentGoText.withValues(alpha: 0.65)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _InfoRow(label: 'Role', value: user?.role ?? 'user'),
                  const SizedBox(height: 10),
                  _InfoRow(label: 'CIN', value: user?.cin ?? 'Not provided'),
                  const SizedBox(height: 10),
                  _InfoRow(label: 'Verified', value: (user?.isVerified ?? false) ? 'Yes' : 'No'),
                  const SizedBox(height: 10),
                  _InfoRow(label: 'Wallet', value: formatMoney(user?.walletBalance)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Wallet RentGo', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    formatMoney(user?.walletBalance),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (user?.walletBalance ?? 0) <= 0
                        ? 'Solde a 0 TND : rechargez pour reserver ou demarrer une location.'
                        : 'Rechargez via carte, D17 ou Sobflous. Les trajets sont debites ici.',
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Ouvrir le wallet',
                    icon: Icons.account_balance_wallet_rounded,
                    expanded: true,
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const WalletPage()),
                      );
                      if (mounted) _refresh();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Account actions', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.refresh_rounded, color: kRentGoPrimary),
                    title: const Text('Refresh profile'),
                    subtitle: const Text('Reload data from the backend'),
                    onTap: _refresh,
                  ),
                  const Divider(height: 18),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout_rounded, color: Colors.red),
                    title: const Text('Logout'),
                    subtitle: const Text('Clear the local session'),
                    onTap: _logout,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kRentGoText.withValues(alpha: 0.6)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
