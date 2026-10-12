import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as latlong;

class RentGoGoogleMap extends StatefulWidget {
  const RentGoGoogleMap({
    super.key,
    required this.initialCamera,
    this.markers = const {},
    this.polylines = const {},
    this.mapType = MapType.normal,
    this.onMapCreated,
    this.myLocationEnabled = false,
    this.onTap,
  });

  final CameraPosition initialCamera;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final MapType mapType;
  final void Function(GoogleMapController controller)? onMapCreated;
  final bool myLocationEnabled;
  final void Function(LatLng position)? onTap;

  @override
  State<RentGoGoogleMap> createState() => _RentGoGoogleMapState();
}

class _RentGoGoogleMapState extends State<RentGoGoogleMap> {
  late final flutter_map.MapController _controller;

  @override
  void initState() {
    super.initState();
    _controller = flutter_map.MapController();
  }

  @override
  void didUpdateWidget(covariant RentGoGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCamera = oldWidget.initialCamera;
    final newCamera = widget.initialCamera;
    if (oldCamera.target != newCamera.target ||
        oldCamera.zoom != newCamera.zoom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.move(_toFlutterLatLng(newCamera.target), newCamera.zoom);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return flutter_map.FlutterMap(
      mapController: _controller,
      options: flutter_map.MapOptions(
        initialCenter: _toFlutterLatLng(widget.initialCamera.target),
        initialZoom: widget.initialCamera.zoom,
        interactionOptions: const flutter_map.InteractionOptions(
          flags:
              flutter_map.InteractiveFlag.drag |
              flutter_map.InteractiveFlag.pinchZoom |
              flutter_map.InteractiveFlag.doubleTapZoom |
              flutter_map.InteractiveFlag.scrollWheelZoom,
        ),
        onTap: widget.onTap == null
            ? null
            : (_, point) =>
                  widget.onTap!(LatLng(point.latitude, point.longitude)),
      ),
      children: [
        flutter_map.TileLayer(
          urlTemplate: widget.mapType == MapType.hybrid
              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.rentgo.tunisia',
        ),
        if (widget.polylines.isNotEmpty)
          flutter_map.PolylineLayer(
            polylines: [
              for (final polyline in widget.polylines)
                flutter_map.Polyline(
                  points: [
                    for (final point in polyline.points)
                      _toFlutterLatLng(point),
                  ],
                  color: polyline.color,
                  strokeWidth: polyline.width.toDouble(),
                ),
            ],
          ),
        flutter_map.MarkerLayer(
          markers: [
            for (final marker in widget.markers)
              if (marker.visible)
                flutter_map.Marker(
                  point: _toFlutterLatLng(marker.position),
                  width: 58,
                  height: 58,
                  child: _RentGoMapMarker(marker: marker),
                ),
          ],
        ),
      ],
    );
  }

  latlong.LatLng _toFlutterLatLng(LatLng point) {
    return latlong.LatLng(point.latitude, point.longitude);
  }
}

class _RentGoMapMarker extends StatelessWidget {
  const _RentGoMapMarker({required this.marker});

  final Marker marker;

  @override
  Widget build(BuildContext context) {
    final markerTitle = marker.infoWindow.title ?? '';
    final markerSnippet = marker.infoWindow.snippet ?? '';
    final tooltip = [
      markerTitle,
      markerSnippet,
    ].where((value) => value.trim().isNotEmpty).join('\n');

    final presentation = _markerPresentation(marker);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: marker.onTap,
      child: Tooltip(
        message: tooltip.isEmpty ? 'Position' : tooltip,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: presentation.background,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(presentation.icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  _MarkerPresentation _markerPresentation(Marker marker) {
    final id = marker.markerId.value.toLowerCase();
    final title = marker.infoWindow.title?.toLowerCase() ?? '';

    if (id.startsWith('parking-') || title.contains('parking')) {
      return const _MarkerPresentation(
        icon: Icons.local_parking_rounded,
        background: Color(0xFF2563EB),
      );
    }
    if (id.startsWith('bike-') ||
        title.contains('bike') ||
        title.contains('velo')) {
      return const _MarkerPresentation(
        icon: Icons.pedal_bike_rounded,
        background: Color(0xFF14B8A6),
      );
    }
    if (id.startsWith('scooter-') ||
        title.contains('scooter') ||
        title.contains('trottinette')) {
      return const _MarkerPresentation(
        icon: Icons.electric_scooter_rounded,
        background: Color(0xFFFF982F),
      );
    }
    if (id.startsWith('selected-place')) {
      return const _MarkerPresentation(
        icon: Icons.place_rounded,
        background: Color(0xFF0EA5E9),
      );
    }
    return const _MarkerPresentation(
      icon: Icons.location_on_rounded,
      background: Color(0xFF64748B),
    );
  }
}

class _MarkerPresentation {
  const _MarkerPresentation({required this.icon, required this.background});

  final IconData icon;
  final Color background;
}
