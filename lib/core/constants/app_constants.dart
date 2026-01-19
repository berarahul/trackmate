/// App-wide constants for TrackMate
class AppConstants {
  // Firestore Collection Names
  static const String usersCollection = 'users';
  static const String friendRequestsCollection = 'friend_requests';
  static const String friendsCollection = 'friends';
  static const String trackingRequestsCollection = 'tracking_requests';
  static const String locationsCollection = 'locations';
  static const String fcmTokensCollection = 'fcm_tokens';

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

  // Notification Constants
  static const String notificationChannelId = 'trackmate_notifications';
  static const String notificationChannelName = 'TrackMate Notifications';

  // Notification Types
  static const String notificationTypeChat = 'chat_message';
  static const String notificationTypeCall = 'video_call';
}
