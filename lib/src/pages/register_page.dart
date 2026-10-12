import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import '../ui.dart';
import 'otp_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cinController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cinController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final cin = _cinController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name, phone number, email and password are required.')),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final otpProvider = await AppScope.of(context).api.register(
        fullName: name,
        phoneNumber: phone,
        email: email,
        cin: cin.isEmpty ? null : cin,
        password: password,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OtpPage(
            phoneNumber: phone,
            deliveryProvider: otpProvider,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
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
              Text('Create account', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Register with your phone number, then verify the OTP sent by the backend.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: kRentGoText.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 28),
              AppPanel(
                child: Column(
                  children: [
                    AppTextField(
                      controller: _nameController,
                      label: 'Full name',
                      prefixIcon: Icons.person_rounded,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _phoneController,
                      label: 'Phone number',
                      hint: '+216 12 345 678',
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_rounded,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'you@email.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_rounded,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _cinController,
                      label: 'CIN',
                      hint: 'Optional',
                      keyboardType: TextInputType.text,
                      prefixIcon: Icons.badge_rounded,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _passwordController,
                      label: 'Password',
                      obscureText: _obscurePassword,
                      prefixIcon: Icons.lock_rounded,
                      suffixIcon: _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      onSuffixPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _confirmController,
                      label: 'Confirm password',
                      obscureText: _obscureConfirm,
                      prefixIcon: Icons.lock_reset_rounded,
                      suffixIcon: _obscureConfirm ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      onSuffixPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Continue',
                      icon: Icons.arrow_forward_rounded,
                      expanded: true,
                      isBusy: _busy,
                      onPressed: _busy ? null : _register,
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
