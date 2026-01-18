import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a friend relationship
class FriendModel {
  final String friendshipId;
  final String friendId;
  final String friendUsername;
  final DateTime addedAt;

  FriendModel({
    required this.friendshipId,
    required this.friendId,
    required this.friendUsername,
    required this.addedAt,
  });

  /// Create FriendModel from Firestore document
  /// The currentUserId is used to determine which user is the friend
  factory FriendModel.fromFirestore(
    DocumentSnapshot doc,
    String currentUserId,
  ) {
    final data = doc.data() as Map<String, dynamic>;

    // Determine which user is the friend
    final isUser1 = data['user1Id'] == currentUserId;

    return FriendModel(
      friendshipId: doc.id,
      friendId: isUser1 ? data['user2Id'] : data['user1Id'],
      friendUsername: isUser1 ? data['user2Username'] : data['user1Username'],
      addedAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'FriendModel(friendId: $friendId, friendUsername: $friendUsername)';
  }
}
