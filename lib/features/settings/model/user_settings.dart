/// User settings model
class UserSettings {
  final int locationUpdateInterval; // in seconds (5, 10, 15, 30, 60)

  UserSettings({
    this.locationUpdateInterval = 10, // Default 10 seconds
  });

  /// Create from Map
  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      locationUpdateInterval: map['locationUpdateInterval'] ?? 10,
    );
  }

  /// Convert to Map
  Map<String, dynamic> toMap() {
    return {'locationUpdateInterval': locationUpdateInterval};
  }

  /// Create a copy with updated values
  UserSettings copyWith({int? locationUpdateInterval}) {
    return UserSettings(
      locationUpdateInterval:
          locationUpdateInterval ?? this.locationUpdateInterval,
    );
  }
}
