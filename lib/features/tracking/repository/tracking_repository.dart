import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/firebase_service.dart';
import '../model/location_model.dart';
import '../model/tracking_request_model.dart';

/// Repository for handling tracking-related operations
class TrackingRepository {
  final FirebaseFirestore _firestore = FirebaseService.instance.firestore;

  /// Send a tracking request to a friend
  Future<void> sendTrackingRequest({
    required String trackerId,
    required String trackerUsername,
    required String trackedId,
    required String trackedUsername,
  }) async {
    // Check if request already exists
    final existingRequest = await _getExistingRequest(trackerId, trackedId);
    if (existingRequest != null && !existingRequest.isStopped) {
      throw Exception('Tracking request already exists');
    }

    // Create tracking request
    final request = TrackingRequestModel(
      requestId: '',
      trackerId: trackerId,
      trackedId: trackedId,
      trackerUsername: trackerUsername,
      trackedUsername: trackedUsername,
      status: AppConstants.statusPending,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.trackingRequestsCollection)
        .add(request.toMap());
  }

  /// Get pending tracking requests (incoming - where I am being requested to be tracked)
  Future<List<TrackingRequestModel>> getPendingTrackingRequests(
    String userId,
  ) async {
    final querySnapshot = await _firestore
        .collection(AppConstants.trackingRequestsCollection)
        .where('trackedId', isEqualTo: userId)
        .where('status', isEqualTo: AppConstants.statusPending)
        .orderBy('createdAt', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => TrackingRequestModel.fromFirestore(doc))
        .toList();
  }

  /// Get active tracking sessions where I am being tracked
  Future<List<TrackingRequestModel>> getActiveTrackingAsTracked(
    String userId,
  ) async {
    final querySnapshot = await _firestore
        .collection(AppConstants.trackingRequestsCollection)
        .where('trackedId', isEqualTo: userId)
        .where('status', isEqualTo: AppConstants.statusAccepted)
        .get();

    return querySnapshot.docs
        .map((doc) => TrackingRequestModel.fromFirestore(doc))
        .toList();
  }

  /// Get active tracking sessions where I am tracking others
  Future<List<TrackingRequestModel>> getActiveTrackingAsTracker(
    String userId,
  ) async {
    final querySnapshot = await _firestore
        .collection(AppConstants.trackingRequestsCollection)
        .where('trackerId', isEqualTo: userId)
        .where('status', isEqualTo: AppConstants.statusAccepted)
        .get();

    return querySnapshot.docs
        .map((doc) => TrackingRequestModel.fromFirestore(doc))
        .toList();
  }

  /// Accept a tracking request
  Future<void> acceptTrackingRequest(String requestId) async {
    await _firestore
        .collection(AppConstants.trackingRequestsCollection)
        .doc(requestId)
        .update({'status': AppConstants.statusAccepted});
  }

  /// Reject a tracking request
  Future<void> rejectTrackingRequest(String requestId) async {
    await _firestore
        .collection(AppConstants.trackingRequestsCollection)
        .doc(requestId)
        .update({'status': AppConstants.statusRejected});
  }

  /// Stop tracking (revoke permission)
  Future<void> stopTracking(String requestId) async {
    await _firestore
        .collection(AppConstants.trackingRequestsCollection)
        .doc(requestId)
        .update({'status': AppConstants.statusStopped});
  }

  /// Update my location
  Future<void> updateLocation({
    required String userId,
    required double latitude,
    required double longitude,
    bool? isActiveOnMap,
  }) async {
    final updates = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    if (isActiveOnMap != null) {
      updates['isActiveOnMap'] = isActiveOnMap;
      updates['lastActiveAt'] = Timestamp.fromDate(DateTime.now());
    }

    await _firestore
        .collection(AppConstants.locationsCollection)
        .doc(userId)
        .set(updates, SetOptions(merge: true));
  }

  /// Update active status on map
  Future<void> updateActiveStatus({
    required String userId,
    required bool isActive,
  }) async {
    await _firestore
        .collection(AppConstants.locationsCollection)
        .doc(userId)
        .set({
          'isActiveOnMap': isActive,
          'lastActiveAt': Timestamp.fromDate(DateTime.now()),
        }, SetOptions(merge: true));
  }

  /// Get latest location of a user
  Future<LocationModel?> getLatestLocation(String userId) async {
    final doc = await _firestore
        .collection(AppConstants.locationsCollection)
        .doc(userId)
        .get();

    if (!doc.exists) {
      return null;
    }

    return LocationModel.fromFirestore(doc);
  }

  /// Stream of location updates for a user
  Stream<LocationModel?> watchLocation(String userId) {
    return _firestore
        .collection(AppConstants.locationsCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return LocationModel.fromFirestore(doc);
        });
  }

  /// Stream of ALL active locations (for Global Map)
  Stream<List<LocationModel>> streamAllActiveLocations(List<String> userIds) {
    if (userIds.isEmpty) {
      return Stream.value([]);
    }

    if (userIds.length <= 10) {
      return _firestore
          .collection(AppConstants.locationsCollection)
          .where(FieldPath.documentId, whereIn: userIds)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => LocationModel.fromFirestore(doc))
                .toList(),
          );
    } else {
      return _firestore
          .collection(AppConstants.locationsCollection)
          .where(FieldPath.documentId, whereIn: userIds.take(10).toList())
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => LocationModel.fromFirestore(doc))
                .toList(),
          );
    }
  }

  /// Stream of only ACTIVE friend locations (users who are actively on map)
  Stream<List<LocationModel>> streamActiveFriendLocations(
    List<String> friendIds,
  ) {
    if (friendIds.isEmpty) {
      return Stream.value([]);
    }

    // Get locations and filter for active users
    final idsToQuery = friendIds.take(10).toList();

    return _firestore
        .collection(AppConstants.locationsCollection)
        .where(FieldPath.documentId, whereIn: idsToQuery)
        .where('isActiveOnMap', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LocationModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Check if I can track a specific user
  Future<bool> canTrackUser(String trackerId, String trackedId) async {
    final querySnapshot = await _firestore
        .collection(AppConstants.trackingRequestsCollection)
        .where('trackerId', isEqualTo: trackerId)
        .where('trackedId', isEqualTo: trackedId)
        .where('status', isEqualTo: AppConstants.statusAccepted)
        .limit(1)
        .get();

    return querySnapshot.docs.isNotEmpty;
  }

  /// Get existing tracking request between two users
  Future<TrackingRequestModel?> _getExistingRequest(
    String trackerId,
    String trackedId,
  ) async {
    final querySnapshot = await _firestore
        .collection(AppConstants.trackingRequestsCollection)
        .where('trackerId', isEqualTo: trackerId)
        .where('trackedId', isEqualTo: trackedId)
        .where(
          'status',
          whereIn: [AppConstants.statusPending, AppConstants.statusAccepted],
        )
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return null;
    }

    return TrackingRequestModel.fromFirestore(querySnapshot.docs.first);
  }

  /// Stream of pending tracking requests count
  Stream<int> watchPendingRequestsCount(String userId) {
    return _firestore
        .collection(AppConstants.trackingRequestsCollection)
        .where('trackedId', isEqualTo: userId)
        .where('status', isEqualTo: AppConstants.statusPending)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
