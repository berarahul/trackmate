import '../../../core/services/storage_service.dart';
import '../model/user_settings.dart';

/// Repository for settings persistence
class SettingsRepository {
  final StorageService _storage = StorageService.instance;

  /// Get current settings
  UserSettings getSettings() {
    return UserSettings(locationUpdateInterval: _storage.getLocationInterval());
  }

  /// Save location update interval
  Future<void> saveLocationInterval(int seconds) async {
    await _storage.setLocationInterval(seconds);
  }
}
