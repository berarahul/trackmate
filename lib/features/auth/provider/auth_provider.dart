import 'package:flutter/material.dart';
import '../../../core/services/storage_service.dart';
import '../model/user_model.dart';
import '../repository/auth_repository.dart';

/// Provider for managing authentication state
class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;
  bool get isInitialized => _isInitialized;
  String get username => _user?.username ?? '';

  /// Initialize provider - check if user is already logged in
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authRepository.getCurrentUser();
      if (_user != null) {
        // Save user info to local storage
        await StorageService.instance.setUserId(_user!.uid);
        await StorageService.instance.setUsername(_user!.username);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Register a new user
  Future<bool> register({
    required String username,
    required String password,
    String? email,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authRepository.register(
        username: username,
        password: password,
        email: email,
      );

      // Save user info to local storage
      await StorageService.instance.setUserId(_user!.uid);
      await StorageService.instance.setUsername(_user!.username);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Login with username and password
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authRepository.login(
        username: username,
        password: password,
      );

      // Save user info to local storage
      await StorageService.instance.setUserId(_user!.uid);
      await StorageService.instance.setUsername(_user!.username);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout current user
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authRepository.logout();
      await StorageService.instance.clearAll();
      _user = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
