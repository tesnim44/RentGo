import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'maps_config.dart';

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.title,
    required this.subtitle,
  });

  final String placeId;
  final String title;
  final String subtitle;
}

class PlacesService {
  const PlacesService();

  Future<List<PlaceSuggestion>> autocomplete(String query) async {
    final input = query.trim();
    if (input.length < 2) return const [];

    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
      'input': input,
      'key': kGoogleMapsApiKey,
      'language': 'fr',
      'components': 'country:tn',
      'location': '$kSousseLatitude,$kSousseLongitude',
      'radius': '40000',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status']?.toString() ?? '';
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      throw Exception(body['error_message']?.toString() ?? 'Places autocomplete failed ($status).');
    }

    final predictions = body['predictions'] as List<dynamic>? ?? const [];
    return predictions.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final structured = map['structured_formatting'] is Map
          ? Map<String, dynamic>.from(map['structured_formatting'] as Map)
          : const <String, dynamic>{};
      return PlaceSuggestion(
        placeId: map['place_id']?.toString() ?? '',
        title: structured['main_text']?.toString() ?? map['description']?.toString() ?? '',
        subtitle: structured['secondary_text']?.toString() ?? '',
      );
    }).where((item) => item.placeId.isNotEmpty).toList(growable: false);
  }

  Future<LatLng> details(String placeId) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'key': kGoogleMapsApiKey,
      'fields': 'geometry/location',
      'language': 'fr',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status']?.toString() ?? '';
    if (status != 'OK') {
      throw Exception(body['error_message']?.toString() ?? 'Place details failed ($status).');
    }

    final result = Map<String, dynamic>.from(body['result'] as Map? ?? const {});
    final geometry = Map<String, dynamic>.from(result['geometry'] as Map? ?? const {});
    final location = Map<String, dynamic>.from(geometry['location'] as Map? ?? const {});
    final lat = (location['lat'] as num?)?.toDouble();
    final lng = (location['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      throw Exception('Lieu introuvable.');
    }
    return LatLng(lat, lng);
  }
}
