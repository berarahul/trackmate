import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';

/// Model representing a friend request
class FriendRequestModel {
  final String requestId;
  final String fromUserId;
  final String fromUsername;
  final String toUserId;
  final String toUsername;
  final String status; // pending, accepted, rejected
  final DateTime createdAt;

  FriendRequestModel({
    required this.requestId,
    required this.fromUserId,
    required this.fromUsername,
    required this.toUserId,
    required this.toUsername,
    required this.status,
    required this.createdAt,
  });

  /// Create FriendRequestModel from Firestore document
  factory FriendRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FriendRequestModel(
      requestId: doc.id,
      fromUserId: data['fromUserId'] ?? '',
      fromUsername: data['fromUsername'] ?? '',
      toUserId: data['toUserId'] ?? '',
      toUsername: data['toUsername'] ?? '',
      status: data['status'] ?? AppConstants.statusPending,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'toUserId': toUserId,
      'toUsername': toUsername,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Check if request is pending
  bool get isPending => status == AppConstants.statusPending;

  /// Check if request is accepted
  bool get isAccepted => status == AppConstants.statusAccepted;

  /// Check if request is rejected
  bool get isRejected => status == AppConstants.statusRejected;

  @override
  String toString() {
    return 'FriendRequestModel(from: $fromUsername, to: $toUsername, status: $status)';
  }
}
