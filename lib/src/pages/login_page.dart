import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import '../ui.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';
import 'shell_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialPhoneNumber});

  final String? initialPhoneNumber;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _phoneController = TextEditingController(
    text: widget.initialPhoneNumber ?? '',
  );
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
        const SnackBar(
          content: Text('Phone number and password are required.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final scope = AppScope.of(context);
      final api = scope.api;
      final session = await api.login(phoneNumber: phone, password: password);
      if (session.user.role.toLowerCase() == 'admin') {
        throw ApiException('Use the admin login to access this account.');
      }
      if (!mounted) return;
      scope.session.setSession(session);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ShellPage()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
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
                'Welcome back',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Login to continue your trip and manage your rentals.',
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
                      label: 'Phone number',
                      hint: '+216 12 345 678',
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_rounded,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _passwordController,
                      label: 'Password',
                      obscureText: _obscure,
                      prefixIcon: Icons.lock_rounded,
                      suffixIcon: _obscure
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      onSuffixPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordPage(),
                          ),
                        ),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Login',
                      icon: Icons.login_rounded,
                      expanded: true,
                      isBusy: _busy,
                      onPressed: _busy ? null : _login,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No account yet?',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      );
                    },
                    child: const Text('Create one'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
