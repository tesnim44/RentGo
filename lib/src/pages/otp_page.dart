import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import '../ui.dart';
import 'login_page.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key, required this.phoneNumber, this.deliveryProvider});

  final String phoneNumber;
  final String? deliveryProvider;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController _codeController = TextEditingController();
  bool _busy = false;
  bool _resendBusy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the OTP code.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await AppScope.of(context).api.verifyOtp(phoneNumber: widget.phoneNumber, code: code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account verified. You can login now.')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => LoginPage(initialPhoneNumber: widget.phoneNumber)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() => _resendBusy = true);
    try {
      await AppScope.of(context).api.resendOtp(phoneNumber: widget.phoneNumber);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new OTP code has been sent.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Resend failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _resendBusy = false);
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
              Text('Verify OTP', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                widget.deliveryProvider == 'console'
                    ? 'Test mode: the 6-digit code is displayed in the backend console.'
                    : 'We send a 6-digit code by SMS to ${widget.phoneNumber}.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: kRentGoText.withValues(alpha: 0.65)),
              ),
              if (widget.deliveryProvider == 'console') ...[
                const SizedBox(height: 8),
                Text(
                  'Configure real Twilio credentials in backend/.env to receive SMS on your phone.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kRentGoText.withValues(alpha: 0.55)),
                ),
              ],
              const SizedBox(height: 28),
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Phone number', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(widget.phoneNumber, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 18),
                    AppTextField(
                      controller: _codeController,
                      label: 'OTP code',
                      hint: '6 digits',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.verified_rounded,
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Verify',
                      icon: Icons.check_circle_rounded,
                      expanded: true,
                      isBusy: _busy,
                      onPressed: _busy ? null : _verify,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _resendBusy ? null : _resendCode,
                      icon: _resendBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: const Text('Resend code'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
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
