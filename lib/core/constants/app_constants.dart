/// App-wide constants for TrackMate
class AppConstants {
  // Firestore Collection Names
  static const String usersCollection = 'users';
  static const String friendRequestsCollection = 'friend_requests';
  static const String friendsCollection = 'friends';
  static const String trackingRequestsCollection = 'tracking_requests';
  static const String locationsCollection = 'locations';

  // Location Update Intervals (in seconds)
  static const List<int> locationIntervals = [5, 10, 15, 30, 60];
  static const int defaultLocationInterval = 10;

  // Request Status
  static const String statusPending = 'pending';
  static const String statusAccepted = 'accepted';
  static const String statusRejected = 'rejected';
  static const String statusStopped = 'stopped';

  // SharedPreferences Keys
  static const String keyLocationInterval = 'location_interval';
  static const String keyUserId = 'user_id';
  static const String keyUsername = 'username';
}
