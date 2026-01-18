import 'dart:async';
import 'package:flutter/material.dart';
import '../model/chat_message_model.dart';
import '../repository/chat_repository.dart';

class ChatProvider extends ChangeNotifier {
  final ChatRepository _repository = ChatRepository();

  List<ChatMessageModel> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _messageSubscription;

  List<ChatMessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Start listening to messages
  void startListeningToMessages() {
    _isLoading = true;
    notifyListeners();

    _messageSubscription?.cancel();
    _messageSubscription = _repository.getMessages().listen(
      (messages) {
        _messages = messages;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Stop listening
  void stopListening() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
  }

  /// Send message
  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    required String text,
    MessageType type = MessageType.text,
  }) async {
    try {
      await _repository.sendMessage(
        senderId: senderId,
        senderName: senderName,
        text: text,
        type: type,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}
