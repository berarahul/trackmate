import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firebase_service.dart';
import '../model/chat_message_model.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseService.instance.firestore;
  static const String chatCollection =
      'global_chat'; // Single global room for simplicity

  /// Send a message
  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    required String text,
    MessageType type = MessageType.text,
  }) async {
    final message = ChatMessageModel(
      id: '',
      senderId: senderId,
      senderName: senderName,
      text: text,
      type: type,
      createdAt: DateTime.now(),
    );

    await _firestore.collection(chatCollection).add(message.toMap());
  }

  /// Stream messages
  Stream<List<ChatMessageModel>> getMessages() {
    return _firestore
        .collection(chatCollection)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessageModel.fromFirestore(doc))
              .toList(),
        );
  }
}
