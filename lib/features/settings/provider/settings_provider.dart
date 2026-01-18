import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../model/user_settings.dart';
import '../repository/settings_repository.dart';

/// Provider for managing settings state
class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _repository = SettingsRepository();

  late UserSettings _settings;

  // Getters
  UserSettings get settings => _settings;
  int get locationInterval => _settings.locationUpdateInterval;
  List<int> get availableIntervals => AppConstants.locationIntervals;

  /// Initialize settings
  void initialize() {
    _settings = _repository.getSettings();
    notifyListeners();
  }

  /// Update location interval
  Future<void> setLocationInterval(int seconds) async {
    await _repository.saveLocationInterval(seconds);
    _settings = _settings.copyWith(locationUpdateInterval: seconds);
    notifyListeners();
  }

  /// Get interval display text
  String getIntervalDisplayText(int seconds) {
    if (seconds < 60) {
      return '$seconds seconds';
    } else {
      return '${seconds ~/ 60} minute${seconds >= 120 ? 's' : ''}';
    }
  }
}
