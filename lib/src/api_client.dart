import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

class ApiClient {
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? _defaultBaseUrl();

  static const Duration _timeout = Duration(seconds: 12);

  final String baseUrl;

  static String _defaultBaseUrl() {
    const override = String.fromEnvironment('RGO_API_BASE_URL');
    if (override.isNotEmpty) {
      return override.endsWith('/api') ? override : '$override/api';
    }

    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000/api';
      case TargetPlatform.iOS:
        return 'http://localhost:3000/api';
      default:
        return 'http://localhost:3000/api';
    }
  }

  Uri _uri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }

  Map<String, String> _jsonHeaders({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _decodeBody(http.Response response) {
    if (response.body.trim().isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      return null;
    }
  }

  Never _throwApiError(
    http.Response response, [
    String fallback = 'Request failed',
  ]) {
    final body = _decodeBody(response);
    final message = body is Map<String, dynamic> && body['message'] != null
        ? body['message'].toString()
        : fallback;
    throw ApiException(message, statusCode: response.statusCode);
  }

  Future<String?> register({
    required String fullName,
    required String phoneNumber,
    required String email,
    String? cin,
    required String password,
  }) async {
    final response = await http
        .post(
          _uri('/auth/register'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'fullName': fullName,
            'phoneNumber': phoneNumber,
            'email': email,
            if (cin != null && cin.isNotEmpty) 'cin': cin,
            'password': password,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response, 'Unable to register');
    }

    final body = _decodeBody(response);
    if (body is Map<String, dynamic> && body['otpDelivery'] is Map) {
      return (body['otpDelivery'] as Map)['provider']?.toString();
    }
    return null;
  }

  Future<void> verifyOtp({
    required String phoneNumber,
    required String code,
  }) async {
    final response = await http
        .post(
          _uri('/auth/verify-otp'),
          headers: _jsonHeaders(),
          body: jsonEncode({'phoneNumber': phoneNumber, 'code': code}),
        )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response, 'Unable to verify code');
    }
  }

  Future<void> resendOtp({required String phoneNumber}) async {
    final response = await http
        .post(
          _uri('/auth/resend-otp'),
          headers: _jsonHeaders(),
          body: jsonEncode({'phoneNumber': phoneNumber}),
        )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response, 'Unable to resend code');
    }
  }

  Future<UserSession> login({
    required String phoneNumber,
    required String password,
  }) async {
    final response = await http
        .post(
          _uri('/auth/login'),
          headers: _jsonHeaders(),
          body: jsonEncode({'phoneNumber': phoneNumber, 'password': password}),
        )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response, 'Unable to login');
    }

    final json = _decodeBody(response) as Map<String, dynamic>;
    return UserSession(
      token: json['token'].toString(),
      user: AppUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
    );
  }

  Future<AppUser> fetchProfile(String token) async {
    final response = await http
        .get(_uri('/auth/me'), headers: _jsonHeaders(token: token))
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response, 'Unable to load profile');
    }
    return AppUser.fromJson(
      Map<String, dynamic>.from(_decodeBody(response) as Map),
    );
  }

  Future<List<Vehicle>> fetchVehicles(String token) async {
    final response = await http
        .get(_uri('/vehicles'), headers: _jsonHeaders(token: token))
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response, 'Unable to load vehicles');
    }
    final body = _decodeBody(response) as List<dynamic>;
    return body
        .map((item) => Vehicle.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<Vehicle> fetchVehicle(String token, String id) async {
    final response = await http
        .get(
          _uri('/vehicles/${Uri.encodeComponent(id)}'),
          headers: _jsonHeaders(token: token),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response, 'Unable to load vehicle');
    }
    return Vehicle.fromJson(
      Map<String, dynamic>.from(_decodeBody(response) as Map),
    );
  }

  Future<Vehicle> fetchVehicleByQr(String token, String qrCode) async {
    final response = await http
        .get(
          _uri('/vehicles/qr/${Uri.encodeComponent(qrCode)}'),
          headers: _jsonHeaders(token: token),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response, 'Unable to resolve QR code');
    }
    return Vehicle.fromJson(
      Map<String, dynamic>.from(_decodeBody(response) as Map),
    );
  }

  Future<Vehicle> reserveVehicle(String token, String id) async {
    final response = await http
        .post(
          _uri('/vehicles/${Uri.encodeComponent(id)}/reserve'),
          headers: _jsonHeaders(token: token),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response, 'Unable to reserve vehicle');
    }
    final body = _decodeBody(response) as Map<String, dynamic>;
    final vehicleJson = body['vehicle'] is Map
        ? Map<String, dynamic>.from(body['vehicle'] as Map)
        : body;
    return Vehicle.fromJson(vehicleJson);
  }

  Future<void> requestPasswordReset(String email) async {
    final response = await http
        .post(
          _uri('/auth/forgot-password'),
          headers: _jsonHeaders(),
          body: jsonEncode({'email': email}),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response, 'Unable to request password reset');
    }
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    final response = await http
        .post(
          _uri('/auth/reset-password'),
          headers: _jsonHeaders(),
          body: jsonEncode({'token': token, 'password': password}),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response, 'Unable to reset password');
    }
  }

  Future<Vehicle> cancelReservation(String token, String id) async {
    final response = await http
        .post(
          _uri('/vehicles/${Uri.encodeComponent(id)}/cancel-reservation'),
          headers: _jsonHeaders(token: token),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response, 'Unable to cancel reservation');
    }
    final body = _decodeBody(response) as Map<String, dynamic>;
    final vehicleJson = body['vehicle'] is Map
        ? Map<String, dynamic>.from(body['vehicle'] as Map)
        : body;
    return Vehicle.fromJson(vehicleJson);
  }

  Future<WalletInfo> fetchWallet(String token) async {
    final response = await http
        .get(_uri('/wallet'), headers: _jsonHeaders(token: token))
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response, 'Unable to load wallet');
    }
    return WalletInfo.fromJson(
      Map<String, dynamic>.from(_decodeBody(response) as Map),
    );
  }

  Future<WalletInfo> topUpWallet({
    required String token,
    required double amount,
    required String method,
  }) async {
    final response = await http
        .post(
          _uri('/wallet/top-up'),
          headers: _jsonHeaders(token: token),
          body: jsonEncode({'amount': amount, 'method': method}),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response, 'Unable to top up wallet');
    }
    final body = Map<String, dynamic>.from(_decodeBody(response) as Map);
    return WalletInfo(
      balance: double.tryParse('${body['walletBalance']}') ?? 0,
      transactions: body['transaction'] is Map
          ? [
              WalletTransaction.fromJson(
                Map<String, dynamic>.from(body['transaction'] as Map),
              ),
            ]
          : const [],
    );
  }

  Future<Rental?> fetchActiveRental(String token) async {
    final response = await http
        .get(_uri('/rentals/active'), headers: _jsonHeaders(token: token))
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response, 'Unable to load active rental');
    }
    final body = _decodeBody(response) as Map<String, dynamic>;
    final rental = body['rental'];
    if (rental == null) return null;
    return Rental.fromJson(Map<String, dynamic>.from(rental as Map));
  }

  Future<List<Rental>> fetchRentals(String token) async {
    final response = await http
        .get(_uri('/rentals/history'), headers: _jsonHeaders(token: token))
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response, 'Unable to load rentals');
    }
    final body = _decodeBody(response) as List<dynamic>;
    return body
        .map((item) => Rental.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<Rental> startRental({
    required String token,
    required String vehicleId,
    double? latitude,
    double? longitude,
  }) async {
    final response = await http
        .post(
          _uri('/rentals/start'),
          headers: _jsonHeaders(token: token),
          body: jsonEncode({
            'vehicleId': vehicleId,
            'latitude': ?latitude,
            'longitude': ?longitude,
          }),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response, 'Unable to start rental');
    }
    final body = _decodeBody(response) as Map<String, dynamic>;
    final rentalJson = Map<String, dynamic>.from(body['rental'] as Map);
    rentalJson['pricePerMinute'] ??= body['pricePerMinute'];
    return Rental.fromJson(rentalJson);
  }

  Future<RentalLocation> recordRentalLocation({
    required String token,
    required String rentalId,
    required double latitude,
    required double longitude,
  }) async {
    final response = await http
        .post(
          _uri('/rentals/${Uri.encodeComponent(rentalId)}/locations'),
          headers: _jsonHeaders(token: token),
          body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response, 'Unable to record location');
    }
    final body = _decodeBody(response) as Map<String, dynamic>;
    return RentalLocation.fromJson(
      Map<String, dynamic>.from(body['location'] as Map),
    );
  }

  Future<({Rental rental, double? walletBalance})> endRental({
    required String token,
    required String rentalId,
    double? latitude,
    double? longitude,
  }) async {
    final response = await http
        .post(
          _uri('/rentals/$rentalId/end'),
          headers: _jsonHeaders(token: token),
          body: jsonEncode({'latitude': ?latitude, 'longitude': ?longitude}),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response, 'Unable to end rental');
    }
    final body = _decodeBody(response) as Map<String, dynamic>;
    return (
      rental: Rental.fromJson(Map<String, dynamic>.from(body['rental'] as Map)),
      walletBalance: double.tryParse('${body['walletBalance'] ?? ''}'),
    );
  }
}
