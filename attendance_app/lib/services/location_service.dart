// ignore_for_file: prefer_single_quotes

import 'package:geolocator/geolocator.dart';

class LocationResult {
  final Position position;
  final double distance;
  final bool inRange;

  LocationResult({
    required this.position,
    required this.distance,
    required this.inRange,
  });
}

class LocationService {

  // Office configuration
  static const double officeLat = 16.026648547578503;
  static const double officeLng = 120.42173542356102;
  static const double allowedRadius = 100;

  // =====================================================
  // VERIFY USER LOCATION
  // =====================================================

  Future<LocationResult> verifyLocation() async {

    bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception("Location Disabled");
    }

    LocationPermission permission =
        await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception("Permission Denied");
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      officeLat,
      officeLng,
    );

    final inRange = distance <= allowedRadius;

    return LocationResult(
      position: position,
      distance: distance,
      inRange: inRange,
    );
  }
}