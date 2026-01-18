import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Location service for handling location permissions and fetching location
class LocationService {
  static LocationService? _instance;

  // Private constructor for singleton
  LocationService._();

  /// Get the singleton instance
  static LocationService get instance {
    _instance ??= LocationService._();
    return _instance!;
  }

  Timer? _locationTimer;
  Function(Position)? _onLocationUpdate;

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Request location permission
  Future<bool> requestLocationPermission() async {
    // Check if location services are enabled
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Check current permission status
    var status = await Permission.location.status;

    if (status.isDenied) {
      // Request permission
      status = await Permission.location.request();
    }

    if (status.isPermanentlyDenied) {
      // Open app settings if permanently denied
      await openAppSettings();
      return false;
    }

    return status.isGranted;
  }

  /// Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Minimum distance (in meters) to trigger update
        ),
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Start periodic location updates
  void startLocationUpdates({
    required int intervalSeconds,
    required Function(Position) onLocationUpdate,
  }) {
    // Stop any existing timer
    stopLocationUpdates();

    _onLocationUpdate = onLocationUpdate;

    // Immediately get location once
    _fetchAndSendLocation();

    // Start periodic timer
    _locationTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => _fetchAndSendLocation(),
    );
  }

  /// Fetch location and send to callback
  Future<void> _fetchAndSendLocation() async {
    final position = await getCurrentLocation();
    if (position != null && _onLocationUpdate != null) {
      _onLocationUpdate!(position);
    }
  }

  /// Stop location updates
  void stopLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _onLocationUpdate = null;
  }

  /// Check if currently tracking
  bool get isTracking => _locationTimer != null;

  /// Calculate distance between two points (in meters)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}
