import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';

/// Model representing a location tracking request
class TrackingRequestModel {
  final String requestId;
  final String trackerId; // Who wants to track
  final String trackedId; // Who will be tracked
  final String trackerUsername;
  final String trackedUsername;
  final String status; // pending, accepted, rejected, stopped
  final DateTime createdAt;

  TrackingRequestModel({
    required this.requestId,
    required this.trackerId,
    required this.trackedId,
    required this.trackerUsername,
    required this.trackedUsername,
    required this.status,
    required this.createdAt,
  });

  /// Create from Firestore document
  factory TrackingRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TrackingRequestModel(
      requestId: doc.id,
      trackerId: data['trackerId'] ?? '',
      trackedId: data['trackedId'] ?? '',
      trackerUsername: data['trackerUsername'] ?? '',
      trackedUsername: data['trackedUsername'] ?? '',
      status: data['status'] ?? AppConstants.statusPending,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'trackerId': trackerId,
      'trackedId': trackedId,
      'trackerUsername': trackerUsername,
      'trackedUsername': trackedUsername,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Check if request is pending
  bool get isPending => status == AppConstants.statusPending;

  /// Check if request is accepted (active tracking)
  bool get isAccepted => status == AppConstants.statusAccepted;

  /// Check if request is rejected
  bool get isRejected => status == AppConstants.statusRejected;

  /// Check if tracking is stopped
  bool get isStopped => status == AppConstants.statusStopped;

  @override
  String toString() {
    return 'TrackingRequestModel(tracker: $trackerUsername, tracked: $trackedUsername, status: $status)';
  }
}
