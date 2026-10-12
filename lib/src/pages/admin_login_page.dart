import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import '../ui.dart';
import 'admin_shell_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin phone and password are required.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final scope = AppScope.of(context);
      final session = await scope.api.login(
        phoneNumber: phone,
        password: password,
      );

      if (session.user.role.toLowerCase() != 'admin') {
        throw ApiException('This account is not an admin account.');
      }

      if (!mounted) return;
      scope.session.setSession(session);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminShellPage()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Admin login failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin access',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Login with an administrator account to manage income, users, parking capacity and fleet activity.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: kRentGoText.withValues(alpha: 0.65),
                    ),
              ),
              const SizedBox(height: 28),
              AppPanel(
                child: Column(
                  children: [
                    AppTextField(
                      controller: _phoneController,
                      label: 'Admin phone number',
                      hint: '+216 12 345 678',
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.admin_panel_settings_rounded,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _passwordController,
                      label: 'Admin password',
                      obscureText: _obscure,
                      prefixIcon: Icons.lock_rounded,
                      suffixIcon: _obscure
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      onSuffixPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Enter admin dashboard',
                      icon: Icons.dashboard_rounded,
                      expanded: true,
                      isBusy: _busy,
                      onPressed: _busy ? null : _login,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
