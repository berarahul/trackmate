import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/firebase_service.dart';
import '../../auth/model/user_model.dart';
import '../model/friend_model.dart';
import '../model/friend_request_model.dart';

/// Repository for handling friend-related operations
class FriendsRepository {
  final FirebaseFirestore _firestore = FirebaseService.instance.firestore;

  /// Search users by username (case-insensitive)
  Future<List<UserModel>> searchUsers(
    String query,
    String currentUserId,
  ) async {
    if (query.trim().isEmpty) {
      return [];
    }

    // Search by username prefix (case-insensitive)
    final queryLower = query.toLowerCase();
    final querySnapshot = await _firestore
        .collection(AppConstants.usersCollection)
        .where('usernameLower', isGreaterThanOrEqualTo: queryLower)
        .where('usernameLower', isLessThanOrEqualTo: '$queryLower\uf8ff')
        .limit(20)
        .get();

    // Filter out current user
    return querySnapshot.docs
        .map((doc) => UserModel.fromFirestore(doc))
        .where((user) => user.uid != currentUserId)
        .toList();
  }

  /// Send a friend request
  Future<void> sendFriendRequest({
    required String fromUserId,
    required String fromUsername,
    required String toUserId,
    required String toUsername,
  }) async {
    // Check if request already exists
    final existingRequest = await _checkExistingRequest(fromUserId, toUserId);
    if (existingRequest != null) {
      throw Exception('Friend request already sent');
    }

    // Check if already friends
    final alreadyFriends = await areFriends(fromUserId, toUserId);
    if (alreadyFriends) {
      throw Exception('Already friends');
    }

    // Create friend request
    final request = FriendRequestModel(
      requestId: '', // Will be set by Firestore
      fromUserId: fromUserId,
      fromUsername: fromUsername,
      toUserId: toUserId,
      toUsername: toUsername,
      status: AppConstants.statusPending,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.friendRequestsCollection)
        .add(request.toMap());
  }

  /// Get pending friend requests for current user (incoming)
  Future<List<FriendRequestModel>> getPendingRequests(String userId) async {
    final querySnapshot = await _firestore
        .collection(AppConstants.friendRequestsCollection)
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: AppConstants.statusPending)
        .orderBy('createdAt', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => FriendRequestModel.fromFirestore(doc))
        .toList();
  }

  /// Get sent friend requests (outgoing)
  Future<List<FriendRequestModel>> getSentRequests(String userId) async {
    final querySnapshot = await _firestore
        .collection(AppConstants.friendRequestsCollection)
        .where('fromUserId', isEqualTo: userId)
        .where('status', isEqualTo: AppConstants.statusPending)
        .orderBy('createdAt', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => FriendRequestModel.fromFirestore(doc))
        .toList();
  }

  /// Accept a friend request
  Future<void> acceptFriendRequest(FriendRequestModel request) async {
    // Update request status
    await _firestore
        .collection(AppConstants.friendRequestsCollection)
        .doc(request.requestId)
        .update({'status': AppConstants.statusAccepted});

    // Create friendship
    await _firestore.collection(AppConstants.friendsCollection).add({
      'user1Id': request.fromUserId,
      'user2Id': request.toUserId,
      'user1Username': request.fromUsername,
      'user2Username': request.toUsername,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Reject a friend request
  Future<void> rejectFriendRequest(String requestId) async {
    await _firestore
        .collection(AppConstants.friendRequestsCollection)
        .doc(requestId)
        .update({'status': AppConstants.statusRejected});
  }

  /// Get list of friends
  Future<List<FriendModel>> getFriends(String userId) async {
    // Query where user is user1
    final query1 = await _firestore
        .collection(AppConstants.friendsCollection)
        .where('user1Id', isEqualTo: userId)
        .get();

    // Query where user is user2
    final query2 = await _firestore
        .collection(AppConstants.friendsCollection)
        .where('user2Id', isEqualTo: userId)
        .get();

    // Combine and convert to FriendModel
    final friends = <FriendModel>[];
    for (final doc in query1.docs) {
      friends.add(FriendModel.fromFirestore(doc, userId));
    }
    for (final doc in query2.docs) {
      friends.add(FriendModel.fromFirestore(doc, userId));
    }

    // Sort by username
    friends.sort((a, b) => a.friendUsername.compareTo(b.friendUsername));
    return friends;
  }

  /// Check if two users are friends
  Future<bool> areFriends(String userId1, String userId2) async {
    // Check both possible orderings
    final query1 = await _firestore
        .collection(AppConstants.friendsCollection)
        .where('user1Id', isEqualTo: userId1)
        .where('user2Id', isEqualTo: userId2)
        .limit(1)
        .get();

    if (query1.docs.isNotEmpty) return true;

    final query2 = await _firestore
        .collection(AppConstants.friendsCollection)
        .where('user1Id', isEqualTo: userId2)
        .where('user2Id', isEqualTo: userId1)
        .limit(1)
        .get();

    return query2.docs.isNotEmpty;
  }

  /// Check if a friend request already exists between two users
  Future<FriendRequestModel?> _checkExistingRequest(
    String fromUserId,
    String toUserId,
  ) async {
    // Check request from user1 to user2
    final query1 = await _firestore
        .collection(AppConstants.friendRequestsCollection)
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('status', isEqualTo: AppConstants.statusPending)
        .limit(1)
        .get();

    if (query1.docs.isNotEmpty) {
      return FriendRequestModel.fromFirestore(query1.docs.first);
    }

    // Check request from user2 to user1
    final query2 = await _firestore
        .collection(AppConstants.friendRequestsCollection)
        .where('fromUserId', isEqualTo: toUserId)
        .where('toUserId', isEqualTo: fromUserId)
        .where('status', isEqualTo: AppConstants.statusPending)
        .limit(1)
        .get();

    if (query2.docs.isNotEmpty) {
      return FriendRequestModel.fromFirestore(query2.docs.first);
    }

    return null;
  }

  /// Stream of pending requests count for real-time updates
  Stream<int> watchPendingRequestsCount(String userId) {
    return _firestore
        .collection(AppConstants.friendRequestsCollection)
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: AppConstants.statusPending)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
