import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../models.dart';
import '../ui.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  static const _presets = [5.0, 10.0, 20.0, 50.0];
  static const _methods = [
    _TopUpMethod(id: 'card', label: 'Carte bancaire', subtitle: 'Visa / Mastercard', icon: Icons.credit_card_rounded),
    _TopUpMethod(id: 'd17', label: 'D17', subtitle: 'Application mobile', icon: Icons.phone_iphone_rounded),
    _TopUpMethod(id: 'sobflous', label: 'Sobflous', subtitle: 'Portefeuille electronique', icon: Icons.account_balance_wallet_rounded),
  ];

  final TextEditingController _amountController = TextEditingController(text: '10');
  final _formKey = GlobalKey<FormState>();
  final _cardholderController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _phoneController = TextEditingController();
  late Future<WalletInfo> _future;
  bool _initialized = false;
  bool _busy = false;
  String _method = 'card';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _future = _load();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _cardholderController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<WalletInfo> _load() async {
    final scope = AppScope.of(context);
    final token = scope.session.token;
    if (token == null) throw ApiException('Login required.');
    final wallet = await scope.api.fetchWallet(token);
    scope.session.updateWalletBalance(wallet.balance);
    return wallet;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  double? _parseAmount() {
    final raw = _amountController.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) return null;
    return amount;
  }

  Future<void> _topUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = _parseAmount();
    final messenger = ScaffoldMessenger.of(context);
    if (amount == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Montant invalide.')));
      return;
    }

    final scope = AppScope.of(context);
    final token = scope.session.token;
    if (token == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Login required.')));
      return;
    }

    setState(() => _busy = true);
    try {
      final wallet = await scope.api.topUpWallet(
        token: token,
        amount: amount,
        method: _method,
      );
      scope.session.updateWalletBalance(wallet.balance);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Wallet recharge: ${formatMoney(wallet.balance)}')),
      );
      _clearSensitivePaymentDetails();
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Recharge impossible: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearSensitivePaymentDetails() {
    _cardNumberController.clear();
    _expiryController.clear();
    _cvvController.clear();
  }

  void _selectMethod(String method) {
    if (_method == method) return;
    setState(() {
      _method = method;
      _clearSensitivePaymentDetails();
    });
  }

  String? _validateAmount(String? _) {
    if (_parseAmount() == null) return 'Saisissez un montant superieur a 0 TND.';
    return null;
  }

  String? _validateCardholder(String? value) {
    if (_method != 'card') return null;
    if ((value ?? '').trim().split(RegExp(r'\s+')).length < 2) {
      return 'Saisissez le nom complet du titulaire.';
    }
    return null;
  }

  String? _validateCardNumber(String? value) {
    if (_method != 'card') return null;
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length < 13 || digits.length > 19 || !_passesLuhn(digits)) {
      return 'Saisissez un numero de carte valide.';
    }
    return null;
  }

  String? _validateExpiry(String? value) {
    if (_method != 'card') return null;
    final match = RegExp(r'^(0[1-9]|1[0-2])\/(\d{2})$').firstMatch((value ?? '').trim());
    if (match == null) return 'Utilisez le format MM/AA.';

    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    final now = DateTime.now();
    if (DateTime(year, month + 1).isBefore(DateTime(now.year, now.month))) {
      return 'Cette carte est expiree.';
    }
    return null;
  }

  String? _validateCvv(String? value) {
    if (_method != 'card') return null;
    if (!RegExp(r'^\d{3,4}$').hasMatch((value ?? '').trim())) {
      return 'Le cryptogramme doit contenir 3 ou 4 chiffres.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (_method == 'card') return null;
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    final localNumber = digits.startsWith('216') ? digits.substring(3) : digits;
    if (localNumber.length != 8) {
      return 'Saisissez un numero tunisien a 8 chiffres.';
    }
    return null;
  }

  bool _passesLuhn(String digits) {
    var sum = 0;
    var doubleDigit = false;
    for (var index = digits.length - 1; index >= 0; index--) {
      var value = int.parse(digits[index]);
      if (doubleDigit) {
        value *= 2;
        if (value > 9) value -= 9;
      }
      sum += value;
      doubleDigit = !doubleDigit;
    }
    return sum % 10 == 0;
  }

  @override
  Widget build(BuildContext context) {
    final sessionBalance = AppScope.of(context).session.user?.walletBalance ?? 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1CB7B0),
        foregroundColor: Colors.white,
        title: const Text('Wallet RentGo'),
      ),
      body: FutureBuilder<WalletInfo>(
        future: _future,
        builder: (context, snapshot) {
          final wallet = snapshot.data;
          final balance = wallet?.balance ?? sessionBalance;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solde disponible',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: kRentGoText.withValues(alpha: 0.62),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatMoney(balance),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      balance <= 0
                          ? 'Rechargez votre wallet pour reserver ou demarrer une location.'
                          : 'Les trajets sont payes uniquement depuis ce wallet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (snapshot.hasError) ...[
                const SizedBox(height: 16),
                AppPanel(
                  child: Text(
                    snapshot.error.toString(),
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Text('Recharger', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final amount in _presets)
                    ChoiceChip(
                      label: Text('${amount.toStringAsFixed(0)} TND'),
                      selected: _parseAmount() == amount,
                      onSelected: (_) {
                        setState(() => _amountController.text = amount.toStringAsFixed(0));
                      },
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _validateAmount,
                decoration: const InputDecoration(
                  labelText: 'Montant (TND)',
                  prefixIcon: Icon(Icons.payments_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              for (final method in _methods)
                _PaymentMethod(
                  label: method.label,
                  subtitle: method.subtitle,
                  icon: method.icon,
                  selected: _method == method.id,
                  onTap: () => _selectMethod(method.id),
                ),
              const SizedBox(height: 4),
              _PaymentDetailsForm(
                method: _method,
                cardholderController: _cardholderController,
                cardNumberController: _cardNumberController,
                expiryController: _expiryController,
                cvvController: _cvvController,
                phoneController: _phoneController,
                validateCardholder: _validateCardholder,
                validateCardNumber: _validateCardNumber,
                validateExpiry: _validateExpiry,
                validateCvv: _validateCvv,
                validatePhone: _validatePhone,
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Ajouter de l\'argent',
                icon: Icons.add_card_rounded,
                expanded: true,
                isBusy: _busy,
                onPressed: _busy ? null : _topUp,
              ),
              const SizedBox(height: 24),
              Text('Transactions', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (wallet == null && snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if ((wallet?.transactions ?? const []).isEmpty)
                AppPanel(
                  child: Text(
                    'Aucune transaction pour le moment.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: kRentGoText.withValues(alpha: 0.62),
                    ),
                  ),
                )
              else
                for (final tx in wallet!.transactions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppPanel(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: tx.direction == 'credit'
                                ? const Color(0xFFE7FAF7)
                                : const Color(0xFFFFF0CF),
                            child: Icon(
                              tx.direction == 'credit'
                                  ? Icons.south_west_rounded
                                  : Icons.north_east_rounded,
                              color: tx.direction == 'credit'
                                  ? kRentGoPrimary
                                  : const Color(0xFFFF982F),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.method.toUpperCase(),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  formatDateTime(tx.createdAt),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: kRentGoText.withValues(alpha: 0.62),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${tx.direction == 'credit' ? '+' : '-'}${formatMoney(tx.amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: tx.direction == 'credit'
                                  ? const Color(0xFF17A866)
                                  : kRentGoText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PaymentDetailsForm extends StatelessWidget {
  const _PaymentDetailsForm({
    required this.method,
    required this.cardholderController,
    required this.cardNumberController,
    required this.expiryController,
    required this.cvvController,
    required this.phoneController,
    required this.validateCardholder,
    required this.validateCardNumber,
    required this.validateExpiry,
    required this.validateCvv,
    required this.validatePhone,
  });

  final String method;
  final TextEditingController cardholderController;
  final TextEditingController cardNumberController;
  final TextEditingController expiryController;
  final TextEditingController cvvController;
  final TextEditingController phoneController;
  final FormFieldValidator<String> validateCardholder;
  final FormFieldValidator<String> validateCardNumber;
  final FormFieldValidator<String> validateExpiry;
  final FormFieldValidator<String> validateCvv;
  final FormFieldValidator<String> validatePhone;

  @override
  Widget build(BuildContext context) {
    final isCard = method == 'card';
    final methodLabel = method == 'd17' ? 'D17' : 'Sobflous';

    return AppPanel(
      margin: const EdgeInsets.only(top: 2, bottom: 10),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCard ? 'Informations de carte' : 'Informations $methodLabel',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            isCard
                ? 'Les donnees de carte sont verifiees sur cet appareil et ne sont pas enregistrees.'
                : 'Utilisez le numero associe a votre compte $methodLabel.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: kRentGoText.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 14),
          if (isCard) ...[
            TextFormField(
              controller: cardholderController,
              textCapitalization: TextCapitalization.words,
              validator: validateCardholder,
              decoration: const InputDecoration(
                labelText: 'Titulaire de la carte',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: cardNumberController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _CardNumberFormatter(),
              ],
              validator: validateCardNumber,
              decoration: const InputDecoration(
                labelText: 'Numero de carte',
                hintText: '1234 5678 9012 3456',
                prefixIcon: Icon(Icons.credit_card_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: expiryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _ExpiryDateFormatter(),
                    ],
                    validator: validateExpiry,
                    decoration: const InputDecoration(
                      labelText: 'Expiration',
                      hintText: 'MM/AA',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: cvvController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    obscuringCharacter: '•',
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    validator: validateCvv,
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      hintText: '123',
                    ),
                  ),
                ),
              ],
            ),
          ] else
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                LengthLimitingTextInputFormatter(14),
              ],
              validator: validatePhone,
              decoration: InputDecoration(
                labelText: 'Numero $methodLabel',
                hintText: '+216 12 345 678',
                prefixIcon: const Icon(Icons.phone_iphone_rounded),
              ),
            ),
        ],
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '').substring(
      0,
      newValue.text.replaceAll(RegExp(r'\D'), '').length.clamp(0, 19),
    );
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && index % 4 == 0) buffer.write(' ');
      buffer.write(digits[index]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.substring(0, digits.length.clamp(0, 4));
    final formatted = limited.length > 2
        ? '${limited.substring(0, 2)}/${limited.substring(2)}'
        : limited;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _TopUpMethod {
  const _TopUpMethod({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
}

class _PaymentMethod extends StatelessWidget {
  const _PaymentMethod({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: selected ? const Color(0xFF18BDB7) : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFE7FAF7),
                  child: Icon(icon, color: const Color(0xFF18BDB7)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: kRentGoText.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? const Color(0xFF18BDB7) : Colors.grey.shade300,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
