import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Storage service for local data persistence using SharedPreferences
class StorageService {
  static StorageService? _instance;
  SharedPreferences? _prefs;

  // Private constructor for singleton
  StorageService._();

  /// Get the singleton instance
  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }

  /// Initialize SharedPreferences
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get SharedPreferences instance
  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception(
        'StorageService not initialized. Call initialize() first.',
      );
    }
    return _prefs!;
  }

  // ============ Location Interval Settings ============

  /// Get saved location interval (defaults to 10 seconds)
  int getLocationInterval() {
    return prefs.getInt(AppConstants.keyLocationInterval) ??
        AppConstants.defaultLocationInterval;
  }

  /// Save location interval
  Future<bool> setLocationInterval(int seconds) async {
    return await prefs.setInt(AppConstants.keyLocationInterval, seconds);
  }

  // ============ User Info ============

  /// Save user ID
  Future<bool> setUserId(String userId) async {
    return await prefs.setString(AppConstants.keyUserId, userId);
  }

  /// Get saved user ID
  String? getUserId() {
    return prefs.getString(AppConstants.keyUserId);
  }

  /// Save username
  Future<bool> setUsername(String username) async {
    return await prefs.setString(AppConstants.keyUsername, username);
  }

  /// Get saved username
  String? getUsername() {
    return prefs.getString(AppConstants.keyUsername);
  }

  // ============ Clear Data ============

  /// Clear all stored data (on logout)
  Future<bool> clearAll() async {
    return await prefs.clear();
  }
}
