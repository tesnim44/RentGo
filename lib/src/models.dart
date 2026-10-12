import 'package:flutter/material.dart';

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString());
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

String _pickString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null) return value.toString();
  }
  return '';
}

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    this.cin,
    this.email,
    this.isVerified,
    this.isSuspended,
    this.walletBalance = 0,
    this.createdAt,
  });

  final String id;
  final String fullName;
  final String phoneNumber;
  final String role;
  final String? cin;
  final String? email;
  final bool? isVerified;
  final bool? isSuspended;
  final double walletBalance;
  final DateTime? createdAt;

  bool get hasWalletFunds => walletBalance > 0;

  AppUser copyWith({double? walletBalance}) {
    return AppUser(
      id: id,
      fullName: fullName,
      phoneNumber: phoneNumber,
      role: role,
      cin: cin,
      email: email,
      isVerified: isVerified,
      isSuspended: isSuspended,
      walletBalance: walletBalance ?? this.walletBalance,
      createdAt: createdAt,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: _pickString(json, ['id']),
      fullName: _pickString(json, ['fullName', 'full_name']),
      phoneNumber: _pickString(json, ['phoneNumber', 'phone_number']),
      role: _pickString(json, ['role']) == ''
          ? 'user'
          : _pickString(json, ['role']),
      cin: json['cin']?.toString(),
      email: json['email']?.toString(),
      isVerified: json['isVerified'] ?? json['is_verified'],
      isSuspended: json['isSuspended'] ?? json['is_suspended'],
      walletBalance:
          _asDouble(json['walletBalance'] ?? json['wallet_balance']) ?? 0,
      createdAt: _asDateTime(json['createdAt'] ?? json['created_at']),
    );
  }
}

class UserSession {
  const UserSession({required this.token, required this.user});

  final String token;
  final AppUser user;
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.type,
    required this.status,
    required this.batteryLevel,
    required this.latitude,
    required this.longitude,
    required this.pricePerMinute,
    this.qrCode,
    this.bookedByUserId,
    this.createdAt,
  });

  final String id;
  final String type;
  final String status;
  final int batteryLevel;
  final double latitude;
  final double longitude;
  final double pricePerMinute;
  final String? qrCode;
  final String? bookedByUserId;
  final DateTime? createdAt;

  bool get isBike => type.toLowerCase() == 'bike';
  String get typeLabel => isBike ? 'Bike' : 'Scooter';
  bool get isAvailable => status.trim().toLowerCase() == 'available';
  bool get isBooked => status.trim().toLowerCase() == 'booked';

  bool isReservedBy(String? userId) {
    if (userId == null || userId.isEmpty || bookedByUserId == null) {
      return false;
    }
    return isBooked && bookedByUserId == userId;
  }

  bool canStartRide(String? userId) => isAvailable || isReservedBy(userId);

  Vehicle copyWith({String? status, String? bookedByUserId}) {
    return Vehicle(
      id: id,
      type: type,
      status: status ?? this.status,
      batteryLevel: batteryLevel,
      latitude: latitude,
      longitude: longitude,
      pricePerMinute: pricePerMinute,
      qrCode: qrCode,
      bookedByUserId: bookedByUserId ?? this.bookedByUserId,
      createdAt: createdAt,
    );
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: _pickString(json, ['id']),
      type: _pickString(json, ['type']),
      status: _pickString(json, ['status']),
      batteryLevel: _asInt(json['battery_level'] ?? json['batteryLevel']) ?? 0,
      latitude: _asDouble(json['latitude']) ?? 0,
      longitude: _asDouble(json['longitude']) ?? 0,
      pricePerMinute:
          _asDouble(json['price_per_minute'] ?? json['pricePerMinute']) ?? 0,
      qrCode: json['qr_code']?.toString() ?? json['qrCode']?.toString(),
      bookedByUserId:
          json['booked_by_user_id']?.toString() ??
          json['bookedByUserId']?.toString(),
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
    );
  }
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.amount,
    required this.direction,
    required this.method,
    required this.status,
    this.reference,
    this.rentalId,
    this.createdAt,
  });

  final String id;
  final double amount;
  final String direction;
  final String method;
  final String status;
  final String? reference;
  final String? rentalId;
  final DateTime? createdAt;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: _pickString(json, ['id']),
      amount: _asDouble(json['amount']) ?? 0,
      direction: _pickString(json, ['direction']),
      method: _pickString(json, ['method']),
      status: _pickString(json, ['status']),
      reference: json['reference']?.toString(),
      rentalId: json['rental_id']?.toString() ?? json['rentalId']?.toString(),
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
    );
  }
}

class WalletInfo {
  const WalletInfo({required this.balance, this.transactions = const []});

  final double balance;
  final List<WalletTransaction> transactions;

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    final rawTransactions = json['transactions'];
    return WalletInfo(
      balance: _asDouble(json['walletBalance'] ?? json['wallet_balance']) ?? 0,
      transactions: rawTransactions is List
          ? rawTransactions
                .whereType<Map>()
                .map(
                  (item) => WalletTransaction.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class Rental {
  const Rental({
    required this.id,
    required this.userId,
    required this.vehicleId,
    required this.status,
    required this.startTime,
    this.endTime,
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    this.durationMinutes,
    this.totalPrice,
    this.vehicleType,
    this.batteryLevel,
    this.vehicleLatitude,
    this.vehicleLongitude,
    this.pricePerMinute,
    this.locationTrack = const [],
  });

  final String id;
  final String userId;
  final String vehicleId;
  final String status;
  final DateTime? startTime;
  final DateTime? endTime;
  final double? startLatitude;
  final double? startLongitude;
  final double? endLatitude;
  final double? endLongitude;
  final int? durationMinutes;
  final double? totalPrice;
  final String? vehicleType;
  final int? batteryLevel;
  final double? vehicleLatitude;
  final double? vehicleLongitude;
  final double? pricePerMinute;
  final List<RentalLocation> locationTrack;

  bool get isOngoing => status == 'ongoing';

  String get vehicleLabel {
    final type = vehicleType?.toLowerCase();
    if (type == 'bike') return 'Bike';
    if (type == 'scooter') return 'Scooter';
    return 'Vehicle';
  }

  factory Rental.fromJson(Map<String, dynamic> json) {
    return Rental(
      id: _pickString(json, ['id']),
      userId: _pickString(json, ['user_id', 'userId']),
      vehicleId: _pickString(json, ['vehicle_id', 'vehicleId']),
      status: _pickString(json, ['status']),
      startTime: _asDateTime(json['start_time'] ?? json['startTime']),
      endTime: _asDateTime(json['end_time'] ?? json['endTime']),
      startLatitude: _asDouble(json['start_latitude'] ?? json['startLatitude']),
      startLongitude: _asDouble(
        json['start_longitude'] ?? json['startLongitude'],
      ),
      endLatitude: _asDouble(json['end_latitude'] ?? json['endLatitude']),
      endLongitude: _asDouble(json['end_longitude'] ?? json['endLongitude']),
      durationMinutes: _asInt(
        json['duration_minutes'] ?? json['durationMinutes'],
      ),
      totalPrice: _asDouble(json['total_price'] ?? json['totalPrice']),
      vehicleType:
          json['vehicle_type']?.toString() ?? json['vehicleType']?.toString(),
      batteryLevel: _asInt(json['battery_level'] ?? json['batteryLevel']),
      vehicleLatitude: _asDouble(
        json['vehicle_latitude'] ?? json['vehicleLatitude'],
      ),
      vehicleLongitude: _asDouble(
        json['vehicle_longitude'] ?? json['vehicleLongitude'],
      ),
      pricePerMinute: _asDouble(
        json['price_per_minute'] ?? json['pricePerMinute'],
      ),
      locationTrack: (json['location_track'] ?? json['locationTrack']) is List
          ? ((json['location_track'] ?? json['locationTrack']) as List)
                .whereType<Map>()
                .map(
                  (item) =>
                      RentalLocation.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
  }
}

class RentalLocation {
  const RentalLocation({
    required this.latitude,
    required this.longitude,
    this.recordedAt,
  });

  final double latitude;
  final double longitude;
  final DateTime? recordedAt;

  factory RentalLocation.fromJson(Map<String, dynamic> json) {
    return RentalLocation(
      latitude: _asDouble(json['latitude']) ?? 0,
      longitude: _asDouble(json['longitude']) ?? 0,
      recordedAt: _asDateTime(json['recorded_at'] ?? json['recordedAt']),
    );
  }
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

extension ColorMix on Color {
  Color blend(Color other, double amount) {
    return Color.lerp(this, other, amount) ?? this;
  }
}
