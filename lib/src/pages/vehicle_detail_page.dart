import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../app.dart';
import '../models.dart';
import '../ui.dart';
import 'active_rental_page.dart';
import 'report_issue_page.dart';
import 'wallet_page.dart';

class VehicleDetailPage extends StatefulWidget {
  const VehicleDetailPage({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  late Vehicle _vehicle = widget.vehicle;
  bool _busy = false;
  bool _reserving = false;

  bool get _hasWalletFunds =>
      AppScope.of(context).session.user?.hasWalletFunds ?? false;

  Future<void> _openWallet() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WalletPage()));
    if (mounted) setState(() {});
  }

  Future<void> _requireWallet() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Rechargez votre wallet (solde 0 TND) avant de reserver ou demarrer.',
        ),
      ),
    );
    await _openWallet();
  }

  Future<void> _startRide() async {
    final scope = AppScope.of(context);
    final token = scope.session.token;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final userId = scope.session.user?.id;

    if (!_hasWalletFunds) {
      await _requireWallet();
      return;
    }

    if (!_vehicle.canStartRide(userId)) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Ce vehicule est ${statusLabel(_vehicle.status).toLowerCase()}.',
          ),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    var openedRidePage = false;
    try {
      if (token == null) throw ApiException('Login required.');
      final position = await _currentPosition();

      final rental = await scope.api.startRental(
        token: token,
        vehicleId: _vehicle.id,
        latitude: position?.latitude ?? _vehicle.latitude,
        longitude: position?.longitude ?? _vehicle.longitude,
      );

      if (!mounted) return;
      openedRidePage = true;
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => ActiveRentalPage(initialRental: rental),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (e.statusCode == 402) await _openWallet();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to start ride: $e')),
      );
    } finally {
      if (mounted && !openedRidePage) {
        setState(() => _busy = false);
      }
    }
  }

  Future<Position?> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _reserveVehicle() async {
    final scope = AppScope.of(context);
    final token = scope.session.token;
    final messenger = ScaffoldMessenger.of(context);

    if (!_hasWalletFunds) {
      await _requireWallet();
      return false;
    }

    if (!_vehicle.isAvailable) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Ce vehicule est ${statusLabel(_vehicle.status).toLowerCase()}.',
          ),
        ),
      );
      return false;
    }

    setState(() => _reserving = true);
    try {
      if (token == null) throw ApiException('Login required.');
      final reserved = await scope.api.reserveVehicle(token, _vehicle.id);
      if (!mounted) return false;
      setState(() => _vehicle = reserved);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Vehicule reserve. Il apparait comme booked.'),
        ),
      );
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (e.statusCode == 402) await _openWallet();
    } catch (e) {
      if (!mounted) return false;
      messenger.showSnackBar(
        SnackBar(content: Text('Reservation impossible: $e')),
      );
    } finally {
      if (mounted) setState(() => _reserving = false);
    }
    return false;
  }

  Future<void> _openReservationForm() async {
    if (!_vehicle.isAvailable || _reserving) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _ReservationFormSheet(vehicle: _vehicle, onConfirm: _reserveVehicle),
    );
  }

  Future<void> _cancelReservation() async {
    final scope = AppScope.of(context);
    final token = scope.session.token;
    if (token == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la reservation ?'),
        content: const Text(
          'Le vehicule redeviendra disponible pour les autres utilisateurs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Garder'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _reserving = true);
    try {
      final updated = await scope.api.cancelReservation(token, _vehicle.id);
      if (!mounted) return;
      setState(() => _vehicle = updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reservation annulee.')));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _reserving = false);
    }
  }

  void _ringVehicle() {
    // TODO: remplacer par scope.api.ringVehicle(widget.vehicle.id) une fois l'endpoint dispo.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Le vehicule sonne...')));
  }

  Future<void> _reportIssue() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportIssuePage(vehicle: widget.vehicle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = _vehicle;
    final color = statusColor(vehicle.status);
    final userId = AppScope.of(context).session.user?.id;
    final canStart = vehicle.canStartRide(userId) && _hasWalletFunds && !_busy;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 360,
            child: Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(
                        vehicle.latitude,
                        vehicle.longitude,
                      ),
                      initialZoom: 14,
                      interactionOptions: const InteractionOptions(
                        flags:
                            InteractiveFlag.drag |
                            InteractiveFlag.pinchZoom |
                            InteractiveFlag.doubleTapZoom,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.rentgo.tunisia',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(vehicle.latitude, vehicle.longitude),
                            width: 52,
                            height: 52,
                            child: CircleAvatar(
                              backgroundColor: const Color(0xFF16BFB8),
                              child: Icon(
                                vehicle.isBike
                                    ? Icons.pedal_bike_rounded
                                    : Icons.electric_scooter_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 44,
                  child: IconButton.filled(
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(backgroundColor: Colors.white),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: kRentGoText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -74),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              decoration: const BoxDecoration(
                color: Color(0xFF314143),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(42),
                  bottom: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _VehicleHeroVisual(vehicle: vehicle)),
                      const SizedBox(width: 14),
                      Column(
                        children: [
                          StatusPill(
                            label: statusLabel(vehicle.status),
                            color: color,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${vehicle.batteryLevel}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'Batterie',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    vehicle.isBike
                        ? 'RentGo Electric Bike'
                        : 'RentGo Electric Scooter',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'QR ${vehicle.qrCode ?? 'N/A'}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.84),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _SpecPill(
                        icon: Icons.bolt_rounded,
                        label: '${vehicle.batteryLevel}%',
                      ),
                      const SizedBox(width: 10),
                      _SpecPill(
                        icon: Icons.speed_rounded,
                        label: vehicle.isBike ? '25 Km/h' : '40 Km/h',
                      ),
                      const SizedBox(width: 10),
                      _SpecPill(
                        icon: Icons.payments_rounded,
                        label:
                            '${vehicle.pricePerMinute.toStringAsFixed(3)} TND/min',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _DetailAction(
                      icon: Icons.schedule_rounded,
                      label: _reserving
                          ? '...'
                          : (vehicle.isReservedBy(userId)
                                ? 'Annuler'
                                : 'Reserve'),
                      onPressed: _reserving
                          ? null
                          : (vehicle.isReservedBy(userId)
                                ? _cancelReservation
                                : (vehicle.isAvailable
                                      ? _openReservationForm
                                      : null)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DetailAction(
                      icon: Icons.notifications_rounded,
                      label: 'Ring',
                      onPressed: _ringVehicle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DetailAction(
                      icon: Icons.report_problem_rounded,
                      label: 'Issue',
                      onPressed: _reportIssue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -2),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppButton(
                label: _hasWalletFunds ? 'Start ride' : 'Recharger le wallet',
                icon: _hasWalletFunds
                    ? Icons.play_arrow_rounded
                    : Icons.account_balance_wallet_rounded,
                expanded: true,
                isBusy: _busy,
                onPressed: _busy
                    ? null
                    : (_hasWalletFunds
                          ? (canStart ? _startRide : null)
                          : _openWallet),
              ),
            ),
          ),
          const SizedBox(height: 0),
          AppPanel(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vehicle details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                _InfoRow(label: 'Vehicle id', value: vehicle.id),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'Position',
                  value:
                      '${vehicle.latitude.toStringAsFixed(5)}, ${vehicle.longitude.toStringAsFixed(5)}',
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'Status',
                  value: statusLabel(vehicle.status),
                  valueColor: color,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservationFormSheet extends StatefulWidget {
  const _ReservationFormSheet({required this.vehicle, required this.onConfirm});

  final Vehicle vehicle;
  final Future<bool> Function() onConfirm;

  @override
  State<_ReservationFormSheet> createState() => _ReservationFormSheetState();
}

class _ReservationFormSheetState extends State<_ReservationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _accepted = false;
  bool _submitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || !_accepted) return;
    setState(() => _submitting = true);
    final didReserve = await widget.onConfirm();
    if (!mounted) return;
    setState(() => _submitting = false);
    if (didReserve) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reserver ce vehicule',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'La reservation est immediate et bloque ce vehicule pour votre compte.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: kRentGoText.withValues(alpha: 0.62),
                ),
              ),
              const SizedBox(height: 20),
              AppPanel(
                margin: EdgeInsets.zero,
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFE7FAF7),
                      child: Icon(
                        vehicle.isBike
                            ? Icons.pedal_bike_rounded
                            : Icons.electric_scooter_rounded,
                        color: kRentGoPrimary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.isBike
                                ? 'Velo electrique'
                                : 'Trottinette electrique',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${vehicle.batteryLevel}% batterie · ${vehicle.pricePerMinute.toStringAsFixed(3)} TND/min',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: kRentGoText.withValues(alpha: 0.62),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              CheckboxListTile(
                value: _accepted,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Je confirme reserver ce vehicule maintenant.',
                ),
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _accepted = value ?? false),
              ),
              if (!_accepted)
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Text(
                    'Confirmez la reservation pour continuer.',
                    style: TextStyle(color: Color(0xFFC2410C)),
                  ),
                ),
              const SizedBox(height: 18),
              AppButton(
                label: 'Confirmer la reservation',
                icon: Icons.event_available_rounded,
                expanded: true,
                isBusy: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleHeroVisual extends StatelessWidget {
  const _VehicleHeroVisual({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final imagePath = vehicle.isBike
        ? 'assets/images/bike.png'
        : 'assets/images/scooter.png';

    return SizedBox(
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
          ),
          Image.asset(
            imagePath,
            height: 240,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                vehicle.isBike
                    ? Icons.pedal_bike_rounded
                    : Icons.electric_scooter_rounded,
                color: Colors.white,
                size: vehicle.isBike ? 170 : 190,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SpecPill extends StatelessWidget {
  const _SpecPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF04A58C),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        foregroundColor: kRentGoText,
        backgroundColor: Colors.white,
        side: BorderSide.none,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: kRentGoText.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: valueColor ?? kRentGoText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
