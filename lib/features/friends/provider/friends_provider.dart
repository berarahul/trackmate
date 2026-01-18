import 'package:flutter/material.dart';
import '../../auth/model/user_model.dart';
import '../model/friend_model.dart';
import '../model/friend_request_model.dart';
import '../repository/friends_repository.dart';

/// Provider for managing friends state
class FriendsProvider extends ChangeNotifier {
  final FriendsRepository _repository = FriendsRepository();

  List<FriendModel> _friends = [];
  List<FriendRequestModel> _pendingRequests = [];
  List<FriendRequestModel> _sentRequests = [];
  List<UserModel> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<FriendModel> get friends => _friends;
  List<FriendRequestModel> get pendingRequests => _pendingRequests;
  List<FriendRequestModel> get sentRequests => _sentRequests;
  List<UserModel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get pendingRequestsCount => _pendingRequests.length;

  /// Load friends list
  Future<void> loadFriends(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _friends = await _repository.getFriends(userId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load pending requests
  Future<void> loadPendingRequests(String userId) async {
    try {
      _pendingRequests = await _repository.getPendingRequests(userId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Load sent requests
  Future<void> loadSentRequests(String userId) async {
    try {
      _sentRequests = await _repository.getSentRequests(userId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Search users by username
  Future<void> searchUsers(String query, String currentUserId) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _searchResults = await _repository.searchUsers(query, currentUserId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear search results
  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  /// Send friend request
  Future<bool> sendFriendRequest({
    required String fromUserId,
    required String fromUsername,
    required String toUserId,
    required String toUsername,
  }) async {
    try {
      await _repository.sendFriendRequest(
        fromUserId: fromUserId,
        fromUsername: fromUsername,
        toUserId: toUserId,
        toUsername: toUsername,
      );

      // Reload sent requests
      await loadSentRequests(fromUserId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Accept friend request
  Future<bool> acceptFriendRequest(
    FriendRequestModel request,
    String userId,
  ) async {
    try {
      await _repository.acceptFriendRequest(request);

      // Reload data
      await loadPendingRequests(userId);
      await loadFriends(userId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Reject friend request
  Future<bool> rejectFriendRequest(String requestId, String userId) async {
    try {
      await _repository.rejectFriendRequest(requestId);

      // Reload pending requests
      await loadPendingRequests(userId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Check if already friends with a user
  Future<bool> isFriendWith(String userId, String otherUserId) async {
    return await _repository.areFriends(userId, otherUserId);
  }

  /// Check if request already sent to user
  bool hasRequestSentTo(String userId) {
    return _sentRequests.any((r) => r.toUserId == userId);
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
