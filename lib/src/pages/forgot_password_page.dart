import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import '../ui.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez une adresse email valide.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.of(context).api.requestPasswordReset(email);
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _sent
              ? AppPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.mark_email_read_rounded,
                        color: kRentGoPrimary,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Check your inbox',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'If this email matches an account, we sent a password-reset link.',
                      ),
                      const SizedBox(height: 18),
                      AppButton(
                        label: 'Back to login',
                        expanded: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Forgot password?',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the email address for your RentGo account.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: kRentGoText.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 28),
                    AppPanel(
                      child: Column(
                        children: [
                          AppTextField(
                            controller: _emailController,
                            label: 'Email address',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.email_outlined,
                          ),
                          const SizedBox(height: 20),
                          AppButton(
                            label: 'Send reset link',
                            icon: Icons.send_rounded,
                            expanded: true,
                            isBusy: _busy,
                            onPressed: _busy ? null : _submit,
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
