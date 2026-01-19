import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a user's location
class LocationModel {
  final String userId;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;
  final bool isActiveOnMap;
  final DateTime? lastActiveAt;

  LocationModel({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    this.isActiveOnMap = false,
    this.lastActiveAt,
  });

  /// Create from Firestore document
  factory LocationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LocationModel(
      userId: doc.id,
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActiveOnMap: data['isActiveOnMap'] ?? false,
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActiveOnMap': isActiveOnMap,
      if (lastActiveAt != null)
        'lastActiveAt': Timestamp.fromDate(lastActiveAt!),
    };
  }

  /// Create a copy with updated values
  LocationModel copyWith({
    String? userId,
    double? latitude,
    double? longitude,
    DateTime? updatedAt,
    bool? isActiveOnMap,
    DateTime? lastActiveAt,
  }) {
    return LocationModel(
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      updatedAt: updatedAt ?? this.updatedAt,
      isActiveOnMap: isActiveOnMap ?? this.isActiveOnMap,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  @override
  String toString() {
    return 'LocationModel(userId: $userId, lat: $latitude, lng: $longitude, active: $isActiveOnMap)';
  }
}
