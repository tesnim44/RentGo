import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../app.dart';
import '../maps_config.dart';
import '../models.dart';
import '../places_service.dart';
import '../ui.dart';
import '../widgets/google_map_view.dart';
import 'active_rental_page.dart';
import 'vehicle_detail_page.dart';
import 'wallet_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<_HomeData> _future;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _future = _load();
      _initialized = true;
    }
  }

  Future<_HomeData> _load() async {
    final scope = AppScope.of(context);
    final token = scope.session.token;
    if (token == null) {
      throw ApiException('Session expired. Please login again.');
    }

    final vehicles = await scope.api.fetchVehicles(token);
    final activeRental = await scope.api.fetchActiveRental(token);
    try {
      final wallet = await scope.api.fetchWallet(token);
      scope.session.updateWalletBalance(wallet.balance);
    } catch (_) {
      // Keep the last known wallet balance if the wallet route is unavailable.
    }
    return _HomeData(vehicles: vehicles, activeRental: activeRental);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _openQrDialog() async {
    final scope = AppScope.of(context);
    final controller = TextEditingController();
    final result = await showDialog<Vehicle>(
      context: context,
      builder: (dialogContext) {
        bool busy = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final qr = controller.text.trim();
              if (qr.isEmpty) return;
              setDialogState(() => busy = true);
              try {
                final token = scope.session.token;
                if (token == null) throw ApiException('Login required.');
                final vehicle = await scope.api.fetchVehicleByQr(token, qr);
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(vehicle);
              } on ApiException catch (e) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text(e.message)));
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => busy = false);
                }
              }
            }

            return Dialog.fullscreen(
              backgroundColor: const Color(0xFF09272B),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton.filled(
                          onPressed: busy
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.12,
                            ),
                          ),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 54),
                      Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Stack(
                          children: const [
                            _QrCorner(alignment: Alignment.topLeft),
                            _QrCorner(alignment: Alignment.topRight),
                            _QrCorner(alignment: Alignment.bottomLeft),
                            _QrCorner(alignment: Alignment.bottomRight),
                            Center(
                              child: SizedBox(
                                width: 258,
                                child: Divider(
                                  color: Color(0xFF1FC7C0),
                                  thickness: 2,
                                ),
                              ),
                            ),
                            Center(
                              child: Icon(
                                Icons.qr_code_2_rounded,
                                size: 72,
                                color: Color(0x331FC7C0),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Alignez le QR code du vehicule',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextField(
                        controller: controller,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Saisir le code manuellement (RG-TR-042)',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.12),
                          suffixIcon: IconButton(
                            onPressed: busy ? null : submit,
                            icon: busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                  ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                        ),
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => submit(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: busy ? null : submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF982F),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text(
                            'Scanner',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
    if (result != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VehicleDetailPage(vehicle: result)),
      );
      if (mounted) await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _future,
      builder: (context, snapshot) {
        final user = AppScope.of(context).session.user;
        final data = snapshot.data;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kRentGoPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.electric_scooter_rounded,
                      color: kRentGoPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RentGo Tunisia',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          'Hello ${user?.fullName.split(' ').first ?? 'rider'}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: kRentGoText.withValues(alpha: 0.6),
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const WalletPage()),
                      );
                      if (mounted) _refresh();
                    },
                    icon: const Icon(Icons.account_balance_wallet_rounded),
                  ),
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if ((user?.walletBalance ?? 0) <= 0) ...[
                AppPanel(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Color(0xFFFF982F),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Wallet a 0 TND. Rechargez pour reserver ou demarrer une location.',
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const WalletPage(),
                            ),
                          );
                        },
                        child: const Text('Wallet'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
              AppHeroFrame(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your city, your ride.',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: Colors.white, height: 1.0),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Find a vehicle in seconds and keep the trip under control from the app.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.84),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          MetricTile(
                            value: '${data?.vehicles.length ?? '--'}',
                            label: 'Nearby vehicles',
                            icon: Icons.pedal_bike_rounded,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          MetricTile(
                            value: data?.activeRental != null ? '1' : '0',
                            label: 'Active rides',
                            icon: Icons.route_rounded,
                            color: Colors.white,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'QR code',
                              icon: Icons.qr_code_scanner_rounded,
                              expanded: true,
                              onPressed: _openQrDialog,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _refresh,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text('Refresh'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (snapshot.hasError)
                AppPanel(
                  child: Text(
                    snapshot.error.toString(),
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                )
              else if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (data?.activeRental != null) ...[
                  SectionHeader(
                    title: 'Current ride',
                    subtitle: 'Your ongoing rental is still active.',
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ActiveRentalPage(
                              initialRental: data!.activeRental!,
                            ),
                          ),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ActiveRentalSummary(rental: data!.activeRental!),
                  const SizedBox(height: 20),
                ],
                SectionHeader(
                  title: 'Sousse map',
                  subtitle: 'Velos et trottinettes disponibles autour de vous.',
                  trailing: TextButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: const Text('Sync'),
                  ),
                ),
                const SizedBox(height: 12),
                _SousseFleetMap(
                  vehicles: data?.vehicles ?? const [],
                  userName: user?.fullName.split(' ').first ?? 'rider',
                  onScan: _openQrDialog,
                  onVehicleTap: (vehicle) async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VehicleDetailPage(vehicle: vehicle),
                      ),
                    );
                    if (mounted) _refresh();
                  },
                ),
                const SizedBox(height: 20),
                SectionHeader(
                  title: 'Available fleet',
                  subtitle: 'Tap a vehicle to review details and start a ride.',
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data?.vehicles.length ?? 0,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.83,
                  ),
                  itemBuilder: (context, index) {
                    final vehicle = data!.vehicles[index];
                    return VehicleMiniCard(
                      vehicle: vehicle,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VehicleDetailPage(vehicle: vehicle),
                          ),
                        );
                        if (mounted) _refresh();
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HomeData {
  const _HomeData({required this.vehicles, required this.activeRental});

  final List<Vehicle> vehicles;
  final Rental? activeRental;
}

class _SousseFleetMap extends StatefulWidget {
  const _SousseFleetMap({
    required this.vehicles,
    required this.userName,
    required this.onScan,
    required this.onVehicleTap,
  });

  static const LatLng _sousseCenter = LatLng(kSousseLatitude, kSousseLongitude);

  final List<Vehicle> vehicles;
  final String userName;
  final VoidCallback onScan;
  final ValueChanged<Vehicle> onVehicleTap;

  @override
  State<_SousseFleetMap> createState() => _SousseFleetMapState();
}

class _SousseFleetMapState extends State<_SousseFleetMap> {
  static const _places = PlacesService();
  static const _parkings = [
    _ParkingLocation('Parking Corniche', 35.8282, 10.6387, 3),
    _ParkingLocation('Parking Boujaafar', 35.8241, 10.6348, 4),
    _ParkingLocation('Parking Hammam Sousse', 35.8356, 10.6248, 6),
  ];

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _filter = 'all';
  MapType _mapType = MapType.normal;
  CameraPosition _camera = const CameraPosition(
    target: _SousseFleetMap._sousseCenter,
    zoom: 14.2,
  );
  List<PlaceSuggestion> _suggestions = const [];
  bool _searching = false;
  Marker? _placeMarker;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String value) async {
    _searchDebounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await _places.autocomplete(value);
        if (!mounted) return;
        setState(() {
          _suggestions = results;
          _searching = false;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _suggestions = const [];
          _searching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recherche de lieu impossible: $error')),
        );
      }
    });
  }

  Future<void> _selectPlace(PlaceSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    try {
      final position = await _places.details(suggestion.placeId);
      if (!mounted) return;
      setState(() {
        _searchController.text = suggestion.title;
        _suggestions = const [];
        _placeMarker = Marker(
          markerId: const MarkerId('selected-place'),
          position: position,
          infoWindow: InfoWindow(
            title: suggestion.title,
            snippet: suggestion.subtitle,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        );
        _camera = CameraPosition(target: position, zoom: 16);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lieu introuvable: $error')));
    }
  }

  void _goToSousse() {
    setState(() {
      _camera = const CameraPosition(
        target: _SousseFleetMap._sousseCenter,
        zoom: 14.2,
      );
    });
  }

  Set<Marker> _markersFor(
    List<Vehicle> vehicles, {
    required bool showParkings,
  }) {
    return {
      Marker(
        markerId: const MarkerId('sousse-center'),
        position: _SousseFleetMap._sousseCenter,
        infoWindow: const InfoWindow(title: 'Sousse'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
      ?_placeMarker,
      if (showParkings)
        for (final parking in _parkings)
          Marker(
            markerId: MarkerId('parking-${parking.name}'),
            position: LatLng(parking.latitude, parking.longitude),
            infoWindow: InfoWindow(
              title: parking.name,
              snippet: '${parking.freeSpaces} places libres',
            ),
          ),
      for (final vehicle in vehicles)
        Marker(
          markerId: MarkerId(
            '${vehicle.isBike ? 'bike' : 'scooter'}-${vehicle.id}',
          ),
          position: LatLng(vehicle.latitude, vehicle.longitude),
          onTap: () => widget.onVehicleTap(vehicle),
          infoWindow: InfoWindow(
            title: vehicle.typeLabel,
            snippet: vehicle.isBooked
                ? 'Reserve'
                : '${vehicle.batteryLevel}% batterie',
            onTap: () => widget.onVehicleTap(vehicle),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            vehicle.isBooked
                ? BitmapDescriptor.hueOrange
                : (vehicle.isBike
                      ? BitmapDescriptor.hueCyan
                      : BitmapDescriptor.hueYellow),
          ),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final positionedVehicles = widget.vehicles
        .where((vehicle) => vehicle.latitude != 0 && vehicle.longitude != 0)
        .where((vehicle) {
          if (_filter == 'bike') return vehicle.isBike;
          if (_filter == 'scooter') return !vehicle.isBike;
          if (_filter == 'charged') return vehicle.batteryLevel > 50;
          if (_filter == 'parking') return false;
          return true;
        })
        .toList(growable: false);
    final allPositioned = widget.vehicles
        .where((vehicle) => vehicle.latitude != 0 && vehicle.longitude != 0)
        .toList(growable: false);
    final bikeCount = allPositioned.where((vehicle) => vehicle.isBike).length;
    final scooterCount = allPositioned.length - bikeCount;
    final chargedCount = allPositioned
        .where((vehicle) => vehicle.batteryLevel > 50)
        .length;
    final showParkings = _filter == 'all' || _filter == 'parking';

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        height: 560,
        child: Stack(
          children: [
            Positioned.fill(
              child: RentGoGoogleMap(
                initialCamera: _camera,
                mapType: _mapType,
                markers: _markersFor(
                  positionedVehicles,
                  showParkings: showParkings,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.94),
                        Colors.white.withValues(alpha: 0.78),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              top: 18,
              child: Text(
                'Bonjour ${widget.userName} 👋',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0E1F26),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              top: 58,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: kRentGoText.withValues(alpha: 0.58),
                            size: 23,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              textInputAction: TextInputAction.search,
                              decoration: const InputDecoration(
                                hintText: 'Ou allez-vous ?',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                              onChanged: _onSearchChanged,
                            ),
                          ),
                          if (_searching)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (_searchController.text.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _suggestions = const [];
                                  _placeMarker = null;
                                });
                              },
                              icon: const Icon(Icons.close_rounded, size: 20),
                            ),
                        ],
                      ),
                    ),
                    if (_suggestions.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.place_outlined),
                              title: Text(suggestion.title),
                              subtitle: suggestion.subtitle.isEmpty
                                  ? null
                                  : Text(suggestion.subtitle),
                              onTap: () => _selectPlace(suggestion),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_suggestions.isEmpty)
              Positioned(
                left: 0,
                right: 0,
                top: 126,
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _MapFilterChip(
                        label: 'Tous',
                        selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                      _MapFilterChip(
                        label: 'Velos',
                        count: bikeCount,
                        selected: _filter == 'bike',
                        onTap: () => setState(() => _filter = 'bike'),
                      ),
                      _MapFilterChip(
                        label: 'Trottinettes',
                        count: scooterCount,
                        selected: _filter == 'scooter',
                        onTap: () => setState(() => _filter = 'scooter'),
                      ),
                      _MapFilterChip(
                        label: 'Parkings',
                        count: _parkings.length,
                        selected: _filter == 'parking',
                        onTap: () => setState(() => _filter = 'parking'),
                      ),
                      _MapFilterChip(
                        label: 'Batterie > 50%',
                        count: chargedCount,
                        selected: _filter == 'charged',
                        onTap: () => setState(() => _filter = 'charged'),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              right: 18,
              top: 260,
              child: Column(
                children: [
                  _MapFloatingButton(
                    icon: Icons.my_location_rounded,
                    onTap: _goToSousse,
                  ),
                  const SizedBox(height: 16),
                  _MapFloatingButton(
                    icon: Icons.layers_rounded,
                    onTap: () {
                      setState(() {
                        _mapType = _mapType == MapType.normal
                            ? MapType.hybrid
                            : MapType.normal;
                      });
                    },
                  ),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 22,
              child: SizedBox(
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: widget.onScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF982F),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                  label: const Text(
                    'Scanner pour demarrer',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParkingLocation {
  const _ParkingLocation(
    this.name,
    this.latitude,
    this.longitude,
    this.freeSpaces,
  );

  final String name;
  final double latitude;
  final double longitude;
  final int freeSpaces;
}

class _MapFilterChip extends StatelessWidget {
  const _MapFilterChip({
    required this.label,
    required this.onTap,
    this.count,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final int? count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? const Color(0xFF19B8B3)
        : const Color(0xFFE7FAF7).withValues(alpha: 0.96);
    final foreground = selected ? Colors.white : kRentGoPrimary;
    final text = count == null ? label : label;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(22),
        elevation: selected ? 5 : 1,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Text(
              text,
              style: TextStyle(
                color: foreground,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapFloatingButton extends StatelessWidget {
  const _MapFloatingButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(icon, color: const Color(0xFF13B7B3), size: 25),
        ),
      ),
    );
  }
}

class _QrCorner extends StatelessWidget {
  const _QrCorner({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final top = alignment.y < 0;
    final left = alignment.x < 0;
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 40,
          height: 40,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: top
                    ? const BorderSide(color: Color(0xFF1FC7C0), width: 5)
                    : BorderSide.none,
                bottom: !top
                    ? const BorderSide(color: Color(0xFF1FC7C0), width: 5)
                    : BorderSide.none,
                left: left
                    ? const BorderSide(color: Color(0xFF1FC7C0), width: 5)
                    : BorderSide.none,
                right: !left
                    ? const BorderSide(color: Color(0xFF1FC7C0), width: 5)
                    : BorderSide.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveRentalSummary extends StatefulWidget {
  const _ActiveRentalSummary({required this.rental});

  final Rental rental;

  @override
  State<_ActiveRentalSummary> createState() => _ActiveRentalSummaryState();
}

class _ActiveRentalSummaryState extends State<_ActiveRentalSummary> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rental = widget.rental;
    final color = statusColor(rental.status);
    final elapsed = rental.startTime == null
        ? Duration.zero
        : DateTime.now().difference(rental.startTime!);
    final estimated = calculateRideFare(
      elapsed: elapsed,
      pricePerMinute: rental.pricePerMinute,
    );

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  rental.vehicleLabel == 'Bike'
                      ? Icons.pedal_bike_rounded
                      : Icons.electric_scooter_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rental.vehicleLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Started ${formatDateTime(rental.startTime)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: kRentGoText.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(label: statusLabel(rental.status), color: color),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              MetricTile(
                value: formatElapsedRideTime(elapsed),
                label: 'Elapsed',
                icon: Icons.timer_rounded,
                color: color,
              ),
              const SizedBox(width: 12),
              MetricTile(
                value: formatMoney(estimated),
                label: 'Estimate',
                icon: Icons.payments_rounded,
                color: kRentGoAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
