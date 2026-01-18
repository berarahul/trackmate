import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/storage_service.dart';
import '../model/location_model.dart';
import '../model/tracking_request_model.dart';
import '../repository/tracking_repository.dart';

/// Provider for managing tracking state
class TrackingProvider extends ChangeNotifier {
  final TrackingRepository _repository = TrackingRepository();
  final LocationService _locationService = LocationService.instance;

  List<TrackingRequestModel> _pendingRequests = [];
  List<TrackingRequestModel> _activeAsTracked = [];
  List<TrackingRequestModel> _activeAsTracker = [];
  LocationModel? _trackedUserLocation;
  bool _isLoading = false;
  bool _isSharing = false;
  String? _errorMessage;
  StreamSubscription? _locationSubscription;

  // Getters
  List<TrackingRequestModel> get pendingRequests => _pendingRequests;
  List<TrackingRequestModel> get activeAsTracked => _activeAsTracked;
  List<TrackingRequestModel> get activeAsTracker => _activeAsTracker;
  LocationModel? get trackedUserLocation => _trackedUserLocation;
  bool get isLoading => _isLoading;
  bool get isSharing => _isSharing;
  String? get errorMessage => _errorMessage;
  int get pendingRequestsCount => _pendingRequests.length;

  /// Load pending tracking requests
  Future<void> loadPendingRequests(String userId) async {
    try {
      _pendingRequests = await _repository.getPendingTrackingRequests(userId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Load active tracking sessions
  Future<void> loadActiveTrackingSessions(String userId) async {
    try {
      _activeAsTracked = await _repository.getActiveTrackingAsTracked(userId);
      _activeAsTracker = await _repository.getActiveTrackingAsTracker(userId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Send tracking request
  Future<bool> sendTrackingRequest({
    required String trackerId,
    required String trackerUsername,
    required String trackedId,
    required String trackedUsername,
  }) async {
    try {
      await _repository.sendTrackingRequest(
        trackerId: trackerId,
        trackerUsername: trackerUsername,
        trackedId: trackedId,
        trackedUsername: trackedUsername,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Accept tracking request
  Future<bool> acceptTrackingRequest(String requestId, String userId) async {
    try {
      await _repository.acceptTrackingRequest(requestId);
      await loadPendingRequests(userId);
      await loadActiveTrackingSessions(userId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Reject tracking request
  Future<bool> rejectTrackingRequest(String requestId, String userId) async {
    try {
      await _repository.rejectTrackingRequest(requestId);
      await loadPendingRequests(userId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Stop tracking (revoke permission)
  Future<bool> stopTracking(String requestId, String userId) async {
    try {
      await _repository.stopTracking(requestId);
      await loadActiveTrackingSessions(userId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Start sharing my location (for tracked user)
  Future<void> startSharingLocation(String userId) async {
    if (_isSharing) return;

    final interval = StorageService.instance.getLocationInterval();

    _isSharing = true;
    notifyListeners();

    _locationService.startLocationUpdates(
      intervalSeconds: interval,
      onLocationUpdate: (Position position) async {
        await _repository.updateLocation(
          userId: userId,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      },
    );
  }

  /// Stop sharing my location
  void stopSharingLocation() {
    _locationService.stopLocationUpdates();
    _isSharing = false;
    notifyListeners();
  }

  /// Update location interval and restart if sharing
  Future<void> updateLocationInterval(String userId, int newInterval) async {
    await StorageService.instance.setLocationInterval(newInterval);

    if (_isSharing) {
      stopSharingLocation();
      await startSharingLocation(userId);
    }
  }

  /// Start watching a tracked user's location
  void startWatchingLocation(String trackedUserId) {
    _locationSubscription?.cancel();

    _locationSubscription = _repository
        .watchLocation(trackedUserId)
        .listen(
          (location) {
            _trackedUserLocation = location;
            notifyListeners();
          },
          onError: (e) {
            _errorMessage = e.toString();
            notifyListeners();
          },
        );
  }

  /// Stop watching location
  void stopWatchingLocation() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _trackedUserLocation = null;
    notifyListeners();
  }

  /// Get latest location once
  Future<LocationModel?> getLatestLocation(String userId) async {
    try {
      return await _repository.getLatestLocation(userId);
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    }
  }

  /// Check if I can track a specific user
  Future<bool> canTrackUser(String trackerId, String trackedId) async {
    return await _repository.canTrackUser(trackerId, trackedId);
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _locationService.stopLocationUpdates();
    super.dispose();
  }
}
