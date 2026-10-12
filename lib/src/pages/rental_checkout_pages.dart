import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import '../ui.dart';
import 'shell_page.dart';
import 'wallet_page.dart';

class ReturnStation {
  const ReturnStation({
    required this.name,
    required this.distance,
    required this.freePlaces,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String distance;
  final int freePlaces;
  final double latitude;
  final double longitude;
}

const kReturnStations = [
  ReturnStation(
    name: 'Station Corniche Sousse',
    distance: '180 m',
    freePlaces: 3,
    latitude: 35.8282,
    longitude: 10.6387,
  ),
  ReturnStation(
    name: 'Station ESSTHS Hammam Sousse',
    distance: '640 m',
    freePlaces: 6,
    latitude: 35.8356,
    longitude: 10.6248,
  ),
  ReturnStation(
    name: 'Station Boujaafar',
    distance: '1,2 km',
    freePlaces: 4,
    latitude: 35.8241,
    longitude: 10.6348,
  ),
];

class ReturnStationPage extends StatefulWidget {
  const ReturnStationPage({super.key, required this.rental});

  final Rental rental;

  @override
  State<ReturnStationPage> createState() => _ReturnStationPageState();
}

class _ReturnStationPageState extends State<ReturnStationPage> {
  ReturnStation _selected = kReturnStations.first;

  @override
  Widget build(BuildContext context) {
    final vehicleCode = widget.rental.vehicleId.length > 8
        ? 'RG-TR-042'
        : widget.rental.vehicleId;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1CB7B0),
        foregroundColor: Colors.white,
        title: const Text('Terminer la location'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          children: [
            Text(
              'Restituez le vehicule dans une station autorisee',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Selectionnez la station ou vous laissez $vehicleCode.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: kRentGoText.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 24),
            for (final station in kReturnStations) ...[
              _StationCard(
                station: station,
                selected: station == _selected,
                onTap: () => setState(() => _selected = station),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFD9F5E9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF17B978),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Vous etes dans la zone de la station',
                      style: TextStyle(
                        color: Color(0xFF17A866),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            AppButton(
              label: 'Continuer au paiement',
              icon: Icons.payments_rounded,
              expanded: true,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PaymentPage(rental: widget.rental, station: _selected),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key, required this.rental, required this.station});

  final Rental rental;
  final ReturnStation station;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _busy = false;
  double _walletBalance = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _walletBalance = AppScope.of(context).session.user?.walletBalance ?? 0;
  }

  Duration get _elapsed {
    final start = widget.rental.startTime;
    if (start == null) return const Duration(seconds: 11);
    final value = DateTime.now().difference(start);
    return value.inSeconds < 1 ? const Duration(seconds: 11) : value;
  }

  double get _unlockFee => 1.0;
  double get _usageFee =>
      _elapsed.inSeconds / 60 * (widget.rental.pricePerMinute ?? 0.9);
  double get _total => _unlockFee + _usageFee;

  Future<void> _pay() async {
    final scope = AppScope.of(context);
    final token = scope.session.token;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      if (token == null) throw ApiException('Login required.');
      if (_walletBalance < _total) {
        throw ApiException(
          'Solde wallet insuffisant. Rechargez votre wallet pour terminer la location.',
          statusCode: 402,
        );
      }
      final closed = await scope.api.endRental(
        token: token,
        rentalId: widget.rental.id,
        latitude: widget.station.latitude,
        longitude: widget.station.longitude,
      );
      if (closed.walletBalance != null) {
        scope.session.updateWalletBalance(closed.walletBalance!);
      }
      if (!mounted) return;
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReceiptPage(
            rental: closed.rental,
            station: widget.station,
            method: 'Wallet RentGo',
            total: closed.rental.totalPrice ?? _total,
            elapsed: _elapsed,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (e.statusCode == 402) {
        await navigator.push(
          MaterialPageRoute(builder: (_) => const WalletPage()),
        );
        if (!mounted) return;
        setState(() {
          _walletBalance = AppScope.of(context).session.user?.walletBalance ?? _walletBalance;
        });
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to process payment: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1CB7B0),
        foregroundColor: Colors.white,
        title: const Text('Paiement'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          children: [
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recapitulatif',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _PaymentRow(
                    label: 'Duree',
                    value: formatMinutes((_elapsed.inSeconds / 60).ceil()),
                  ),
                  _PaymentRow(
                    label: 'Deblocage',
                    value: _unlockFee.toStringAsFixed(3).replaceAll('.', ','),
                  ),
                  _PaymentRow(
                    label: 'Temps d’utilisation',
                    value: _usageFee.toStringAsFixed(3).replaceAll('.', ','),
                  ),
                  const Divider(height: 28),
                  _PaymentRow(
                    label: 'Total',
                    value:
                        '${_total.toStringAsFixed(3).replaceAll('.', ',')} TND',
                    large: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'PAIEMENT',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: kRentGoText.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 12),
            _PaymentMethod(
              label: 'Wallet RentGo',
              subtitle: 'Solde: ${formatMoney(_walletBalance)}',
              icon: Icons.account_balance_wallet_rounded,
              selected: true,
              onTap: () {},
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WalletPage()),
                );
                if (!mounted) return;
                setState(() {
                  _walletBalance =
                      AppScope.of(context).session.user?.walletBalance ?? _walletBalance;
                });
              },
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('Recharger via carte, D17 ou Sobflous'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _walletBalance < _total
                    ? const Color(0xFFFFF0CF)
                    : const Color(0xFFD9F5E9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Icon(
                    _walletBalance < _total
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded,
                    color: _walletBalance < _total
                        ? const Color(0xFFFF982F)
                        : const Color(0xFF17A866),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _walletBalance < _total
                          ? 'Solde insuffisant. Rechargez le wallet pour payer ce trajet.'
                          : 'Le trajet sera debite uniquement depuis votre wallet.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            AppButton(
              label: _walletBalance < _total
                  ? 'Recharger le wallet'
                  : 'Payer ${formatMoney(_total)}',
              icon: Icons.lock_rounded,
              expanded: true,
              isBusy: _busy,
              onPressed: _busy
                  ? null
                  : (_walletBalance < _total
                      ? () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const WalletPage()),
                          );
                          if (!mounted) return;
                          setState(() {
                            _walletBalance = AppScope.of(context)
                                    .session
                                    .user
                                    ?.walletBalance ??
                                _walletBalance;
                          });
                        }
                      : _pay),
            ),
          ],
        ),
      ),
    );
  }
}

class ReceiptPage extends StatelessWidget {
  const ReceiptPage({
    super.key,
    required this.rental,
    required this.station,
    required this.method,
    required this.total,
    required this.elapsed,
  });

  final Rental rental;
  final ReturnStation station;
  final String method;
  final double total;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final receiptNumber =
        'RG-2026-${rental.id.hashCode.abs().toString().padLeft(5, '0').substring(0, 5)}';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1CB7B0),
        foregroundColor: Colors.white,
        title: const Text('Recu'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ShellPage(initialIndex: 1)),
            (route) => false,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Color(0xFFD9F5E9),
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF20B874),
                size: 54,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Paiement reussi',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              "Merci d'avoir roule avec RentGo",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: kRentGoText.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 22),
            AppPanel(
              child: Column(
                children: [
                  _ReceiptRow(label: 'Recu n°', value: receiptNumber),
                  _ReceiptRow(
                    label: 'Date',
                    value: formatDateTime(DateTime.now()),
                  ),
                  _ReceiptRow(label: 'Vehicule', value: rental.vehicleLabel),
                  _ReceiptRow(
                    label: 'Station de depart',
                    value: 'Station Corniche Sousse',
                  ),
                  _ReceiptRow(label: "Station d'arrivee", value: station.name),
                  _ReceiptRow(
                    label: 'Duree',
                    value: formatMinutes((elapsed.inSeconds / 60).ceil()),
                  ),
                  const Divider(height: 26),
                  _ReceiptRow(
                    label: 'Mode de paiement',
                    value: method,
                  ),
                  const Divider(height: 26),
                  _ReceiptRow(
                    label: 'Total paye',
                    value:
                        '${total.toStringAsFixed(3).replaceAll('.', ',')} TND',
                    large: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Telecharger'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AppButton(
                    label: 'Noter ce trajet',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RatingPage(rental: rental),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RatingPage extends StatefulWidget {
  const RatingPage({super.key, required this.rental});

  final Rental rental;

  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> {
  int _rating = 0;
  String _category = 'Freins';
  final Set<String> _tags = {};
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Merci, votre retour a ete enregistre.')),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ShellPage(initialIndex: 1)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1CB7B0),
        foregroundColor: Colors.white,
        title: const Text('Noter ce trajet'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
          children: [
            AppPanel(
              child: Column(
                children: [
                  Text(
                    "Comment s'est passe votre trajet ?",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var index = 1; index <= 5; index++)
                        IconButton(
                          onPressed: () => setState(() => _rating = index),
                          icon: Icon(
                            index <= _rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                          ),
                          color: const Color(0xFFFFB547),
                          iconSize: 38,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ETIQUETTES RAPIDES',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: kRentGoText.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final tag in [
                  'Bon etat',
                  'Batterie faible',
                  'Freins',
                  'Selle abimee',
                  'Ecran casse',
                ])
                  FilterChip(
                    label: Text(tag),
                    selected: _tags.contains(tag),
                    onSelected: (_) => setState(
                      () => _tags.contains(tag)
                          ? _tags.remove(tag)
                          : _tags.add(tag),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Text('Commentaire', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              controller: _commentController,
              minLines: 4,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Dites-nous en plus...',
              ),
            ),
            const SizedBox(height: 24),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Signaler un probleme',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Categorie'),
                    items: const [
                      DropdownMenuItem(value: 'Freins', child: Text('Freins')),
                      DropdownMenuItem(
                        value: 'Batterie',
                        child: Text('Batterie'),
                      ),
                      DropdownMenuItem(value: 'Roue', child: Text('Roue')),
                      DropdownMenuItem(value: 'Ecran', child: Text('Ecran')),
                    ],
                    onChanged: (value) =>
                        setState(() => _category = value ?? _category),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Photo'),
                    style: OutlinedButton.styleFrom(
                      fixedSize: const Size(112, 98),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Envoyer',
              icon: Icons.send_rounded,
              expanded: true,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _StationCard extends StatelessWidget {
  const _StationCard({
    required this.station,
    required this.selected,
    required this.onTap,
  });

  final ReturnStation station;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected ? const Color(0xFF18BDB7) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? const Color(0xFF18BDB7)
                    : Colors.grey.shade300,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Color(0xFF18BDB7),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            station.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      station.distance,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: kRentGoText.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF7EA),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '${station.freePlaces} places libres',
                  style: const TextStyle(
                    color: Color(0xFF17A866),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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
                  color: selected
                      ? const Color(0xFF18BDB7)
                      : Colors.grey.shade300,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.label,
    required this.value,
    this.large = false,
  });

  final String label;
  final String value;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: kRentGoText.withValues(alpha: 0.62),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: large ? 28 : 18,
              fontWeight: FontWeight.w900,
              color: large ? const Color(0xFF0A1F26) : kRentGoText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.large = false,
  });

  final String label;
  final String value;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: kRentGoText.withValues(alpha: 0.62),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: large ? const Color(0xFF1CB7B0) : kRentGoText,
                fontSize: large ? 28 : 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
