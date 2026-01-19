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
  List<TrackingRequestModel> _activeAsTracked = []; // Users tracking ME
  List<TrackingRequestModel> _activeAsTracker = []; // Users I am tracking
  LocationModel? _trackedUserLocation;
  List<LocationModel> _globalLocations = []; // All tracked users locations
  List<LocationModel> _activeFriendLocations = []; // Only active friends on map
  bool _isLoading = false;
  bool _isSharing = false;
  bool _isActiveOnMap = false;
  String? _errorMessage;
  StreamSubscription? _locationSubscription;
  StreamSubscription? _globalLocationSubscription;
  StreamSubscription? _activeFriendLocationSubscription;

  // Getters
  List<TrackingRequestModel> get pendingRequests => _pendingRequests;
  List<TrackingRequestModel> get activeAsTracked => _activeAsTracked;
  List<TrackingRequestModel> get activeAsTracker => _activeAsTracker;
  LocationModel? get trackedUserLocation => _trackedUserLocation;
  List<LocationModel> get globalLocations => _globalLocations;
  List<LocationModel> get activeFriendLocations => _activeFriendLocations;
  bool get isLoading => _isLoading;
  bool get isSharing => _isSharing;
  bool get isActiveOnMap => _isActiveOnMap;
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

  /// Set user as active on map (called when user taps Map tab)
  Future<void> setMapActive(String userId, bool isActive) async {
    _isActiveOnMap = isActive;
    notifyListeners();

    try {
      await _repository.updateActiveStatus(userId: userId, isActive: isActive);
    } catch (e) {
      debugPrint('Error updating active status: $e');
    }
  }

  /// Start sharing my location (for tracked user)
  Future<void> startSharingLocation(
    String userId, {
    bool setActiveOnMap = false,
  }) async {
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
          isActiveOnMap: setActiveOnMap ? _isActiveOnMap : null,
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

  /// Start streaming all active locations (Global Map)
  void startGlobalLocationStream() {
    _globalLocationSubscription?.cancel();

    // Collect IDs of users I am tracking
    final trackedIds = _activeAsTracker.map((e) => e.trackedId).toList();

    if (trackedIds.isEmpty) {
      _globalLocations = [];
      notifyListeners();
      return;
    }

    _globalLocationSubscription = _repository
        .streamAllActiveLocations(trackedIds)
        .listen(
          (locations) {
            _globalLocations = locations;
            notifyListeners();
          },
          onError: (e) {
            _errorMessage = e.toString();
            notifyListeners();
          },
        );
  }

  /// Start streaming only ACTIVE friend locations (friends who have map tab open)
  void startActiveFriendLocationStream(List<String> friendIds) {
    _activeFriendLocationSubscription?.cancel();

    if (friendIds.isEmpty) {
      _activeFriendLocations = [];
      notifyListeners();
      return;
    }

    _activeFriendLocationSubscription = _repository
        .streamActiveFriendLocations(friendIds)
        .listen(
          (locations) {
            _activeFriendLocations = locations;
            notifyListeners();
          },
          onError: (e) {
            _errorMessage = e.toString();
            notifyListeners();
          },
        );
  }

  /// Stop watching global location
  void stopGlobalLocationStream() {
    _globalLocationSubscription?.cancel();
    _globalLocationSubscription = null;
    _globalLocations = [];
    notifyListeners();
  }

  /// Stop watching active friend locations
  void stopActiveFriendLocationStream() {
    _activeFriendLocationSubscription?.cancel();
    _activeFriendLocationSubscription = null;
    _activeFriendLocations = [];
    notifyListeners();
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
    _globalLocationSubscription?.cancel();
    _activeFriendLocationSubscription?.cancel();
    _locationService.stopLocationUpdates();
    super.dispose();
  }
}
