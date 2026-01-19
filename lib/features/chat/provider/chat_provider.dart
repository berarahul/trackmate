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
  List<String> _currentFriendIds = [];
  String _currentRoomId = '';

  List<ChatMessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<String> get currentFriendIds => _currentFriendIds;
  String get currentRoomId => _currentRoomId;

  /// Initialize chat with friend IDs
  void initializeWithFriends(List<String> friendIds) {
    _currentFriendIds = friendIds;
    _currentRoomId = _repository.generateFriendChatRoomId(friendIds);
  }

  /// Start listening to messages for the friend group
  void startListeningToMessages({List<String>? friendIds}) {
    final idsToUse = friendIds ?? _currentFriendIds;

    if (idsToUse.isEmpty) {
      _messages = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _currentFriendIds = idsToUse;
    _currentRoomId = _repository.generateFriendChatRoomId(idsToUse);

    _isLoading = true;
    notifyListeners();

    _messageSubscription?.cancel();
    _messageSubscription = _repository
        .getMessages(idsToUse)
        .listen(
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

  /// Send message to friend chat room
  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    required String text,
    MessageType type = MessageType.text,
  }) async {
    if (_currentFriendIds.isEmpty) {
      _errorMessage = 'No friends to chat with';
      notifyListeners();
      return;
    }

    try {
      await _repository.sendMessage(
        senderId: senderId,
        senderName: senderName,
        text: text,
        friendIds: _currentFriendIds,
        type: type,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Get call room ID for video calls with friends
  String getCallRoomId() {
    return _repository.getCallRoomId(_currentFriendIds);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}
