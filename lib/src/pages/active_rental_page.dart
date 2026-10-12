import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../app.dart';
import '../models.dart';
import '../ui.dart';
import '../widgets/google_map_view.dart';
import 'rental_checkout_pages.dart';

class ActiveRentalPage extends StatefulWidget {
  const ActiveRentalPage({super.key, this.initialRental});

  final Rental? initialRental;

  @override
  State<ActiveRentalPage> createState() => _ActiveRentalPageState();
}

class _ActiveRentalPageState extends State<ActiveRentalPage> {
  late Future<Rental?> _future;
  Rental? _rental;
  Timer? _timer;
  StreamSubscription<Position>? _locationSubscription;
  final List<RentalLocation> _locationTrack = [];
  bool _initialized = false;
  bool _paused = false;
  bool _sendingLocation = false;
  String? _trackingMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _rental = widget.initialRental;
      _future = _load();
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) setState(() {});
      });
      _initialized = true;
    }
  }

  Future<Rental?> _load() async {
    final rental = _rental ?? await _fetchActiveRental();
    _rental = rental;
    if (rental != null) {
      _locationTrack
        ..clear()
        ..addAll(rental.locationTrack);
      unawaited(_startLocationTracking(rental));
    }
    return rental;
  }

  Future<Rental?> _fetchActiveRental() async {
    final token = AppScope.of(context).session.token;
    if (token == null) throw ApiException('Login required.');
    return AppScope.of(context).api.fetchActiveRental(token);
  }

  Future<void> _startLocationTracking(Rental rental) async {
    if (_locationSubscription != null) return;
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        setState(
          () => _trackingMessage =
              'Activez la localisation pour enregistrer le trajet.',
        );
      }
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(
          () => _trackingMessage =
              'Autorisez la localisation pour enregistrer le trajet.',
        );
      }
      return;
    }

    if (mounted) setState(() => _trackingMessage = null);
    _locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen(
          (position) => _recordPosition(rental, position),
          onError: (_) {
            if (mounted) {
              setState(
                () =>
                    _trackingMessage = 'Position temporairement indisponible.',
              );
            }
          },
        );

    try {
      final position = await Geolocator.getCurrentPosition();
      await _recordPosition(rental, position);
    } catch (_) {
      // The stream may still provide a later position.
    }
  }

  Future<void> _recordPosition(Rental rental, Position position) async {
    if (_sendingLocation || _paused) return;
    final token = AppScope.of(context).session.token;
    if (token == null) return;
    _sendingLocation = true;
    try {
      final location = await AppScope.of(context).api.recordRentalLocation(
        token: token,
        rentalId: rental.id,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _locationTrack.add(location);
        _trackingMessage = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _trackingMessage = 'Impossible d’enregistrer cette position.',
        );
      }
    } finally {
      _sendingLocation = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _paused ? 'Location mise en pause.' : 'Location reprise.',
        ),
      ),
    );
    // TODO: remplacer par un vrai appel API une fois l'endpoint dispo, ex:
    // final scope = AppScope.of(context);
    // await scope.api.pauseRental(token: scope.session.token!, rentalId: rental.id);
    // ou scope.api.resumeRental(...) selon _paused.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Rental?>(
        future: _future,
        builder: (context, snapshot) {
          final rental = snapshot.data ?? _rental;

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              rental == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (rental == null) {
            return const Center(child: Text('No active rental found.'));
          }

          final started = rental.startTime;
          final elapsed = started == null
              ? Duration.zero
              : DateTime.now().difference(started);
          final estimated = calculateRideFare(
            elapsed: elapsed,
            pricePerMinute: rental.pricePerMinute,
          );

          final pricePerMinute = rental.pricePerMinute ?? 0.9;
          final routeStart = LatLng(
            rental.startLatitude ?? 35.82539,
            rental.startLongitude ?? 10.63699,
          );
          final routePoints = [
            routeStart,
            ..._locationTrack.map(
              (point) => LatLng(point.latitude, point.longitude),
            ),
          ];
          final currentPosition = routePoints.length > 1
              ? routePoints.last
              : LatLng(
                  rental.vehicleLatitude ?? routeStart.latitude,
                  rental.vehicleLongitude ?? routeStart.longitude,
                );
          final distanceKm = _distanceKm(routePoints);

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 44, 24, 28),
                decoration: const BoxDecoration(color: Color(0xFF1CB7B0)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location en cours',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${rental.vehicleLabel} · Station de depart Station Corniche Sousse',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _RideMetricCard(
                          icon: Icons.speed_rounded,
                          label: 'Duree',
                          value: formatElapsedRideTime(
                            elapsed,
                          ).split('.').first,
                          subtitle: _paused ? 'En pause' : 'En cours',
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _RideMetricCard(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Cout estime',
                          value:
                              '${(1 + (estimated ?? 0)).toStringAsFixed(3).replaceAll('.', ',')} TND',
                          subtitle:
                              '1,000 + ${pricePerMinute.toStringAsFixed(3).replaceAll('.', ',')}/min',
                          accent: const Color(0xFFF28B3C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: SizedBox(
                    height: 280,
                    child: RentGoGoogleMap(
                      initialCamera: CameraPosition(
                        target: currentPosition,
                        zoom: 14.3,
                      ),
                      polylines: routePoints.length < 2
                          ? const {}
                          : {
                              Polyline(
                                polylineId: const PolylineId('ride-route'),
                                points: routePoints,
                                color: const Color(0xFFFF982F),
                                width: 5,
                              ),
                            },
                      markers: {
                        Marker(
                          markerId: const MarkerId('ride-start'),
                          position: routeStart,
                          infoWindow: const InfoWindow(title: 'Depart'),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueCyan,
                          ),
                        ),
                        Marker(
                          markerId: MarkerId(
                            '${rental.vehicleType == 'bike' ? 'bike' : 'scooter'}-active',
                          ),
                          position: currentPosition,
                          infoWindow: const InfoWindow(title: 'Votre position'),
                        ),
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _RideStatTile(
                      icon: Icons.speed_rounded,
                      label: 'Vitesse moy.',
                      value: '14 km/h',
                    ),
                    const SizedBox(width: 14),
                    _RideStatTile(
                      icon: Icons.route_rounded,
                      label: 'Distance',
                      value:
                          '${distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km',
                    ),
                    const SizedBox(width: 14),
                    _RideStatTile(
                      icon: Icons.battery_full_rounded,
                      label: 'Batterie',
                      value: '${rental.batteryLevel ?? 68}%',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 120),
              if (_trackingMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Text(
                    _trackingMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: kRentGoText.withValues(alpha: 0.62),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: OutlinedButton(
                  onPressed: _togglePause,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    foregroundColor: const Color(0xFF1CB7B0),
                    side: const BorderSide(
                      color: Color(0xFF1CB7B0),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    _paused ? 'Reprendre' : 'Mettre en pause',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: SizedBox(
                  height: 58,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReturnStationPage(rental: rental),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF982F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Terminer la location',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double _distanceKm(List<LatLng> points) {
    if (points.length < 2) return 0;
    var meters = 0.0;
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final dLat = _toRadians(current.latitude - previous.latitude);
      final dLng = _toRadians(current.longitude - previous.longitude);
      final a =
          math.pow(math.sin(dLat / 2), 2) +
          math.cos(_toRadians(previous.latitude)) *
              math.cos(_toRadians(current.latitude)) *
              math.pow(math.sin(dLng / 2), 2);
      meters += 12742000 * math.asin(math.sqrt(a));
    }
    return meters / 1000;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
}

class _RideMetricCard extends StatelessWidget {
  const _RideMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    this.accent = const Color(0xFF1CB7B0),
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: kRentGoText.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: kRentGoText.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class _RideStatTile extends StatelessWidget {
  const _RideStatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFE7FAF7),
              child: Icon(icon, color: const Color(0xFF1CB7B0), size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: kRentGoText.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
