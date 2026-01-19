import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firebase_service.dart';
import '../model/chat_message_model.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseService.instance.firestore;
  static const String chatRoomsCollection = 'friend_chat_rooms';

  /// Generate a unique chat room ID based on friend IDs
  /// Sorts and hashes friend IDs to create a consistent room ID
  String generateFriendChatRoomId(List<String> friendIds) {
    if (friendIds.isEmpty) {
      return 'no_friends';
    }
    // Sort IDs to ensure consistent room ID regardless of order
    final sortedIds = List<String>.from(friendIds)..sort();
    // Create a simple hash from sorted IDs
    return sortedIds.join('_');
  }

  /// Send a message to the friend chat room
  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    required String text,
    required List<String> friendIds,
    MessageType type = MessageType.text,
  }) async {
    final roomId = generateFriendChatRoomId(friendIds);

    final message = ChatMessageModel(
      id: '',
      senderId: senderId,
      senderName: senderName,
      text: text,
      type: type,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(chatRoomsCollection)
        .doc(roomId)
        .collection('messages')
        .add(message.toMap());
  }

  /// Stream messages from the friend chat room
  Stream<List<ChatMessageModel>> getMessages(List<String> friendIds) {
    final roomId = generateFriendChatRoomId(friendIds);

    return _firestore
        .collection(chatRoomsCollection)
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessageModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get the friend chat room ID for video calls
  String getCallRoomId(List<String> friendIds) {
    return 'call_${generateFriendChatRoomId(friendIds)}';
  }
}
