import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants/app_constants.dart';
import 'firebase_service.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.messageId}');
}

/// Service for handling push notifications
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();

  NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseService.instance.firestore;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Callback for handling notification taps
  Function(String type, Map<String, dynamic> data)? onNotificationTap;

  /// Initialize the notification service
  Future<void> initialize() async {
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission
    await _requestPermission();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Get FCM token
    await _getFcmToken();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check for initial message (app opened from terminated state via notification)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Request notification permission
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          final data = jsonDecode(response.payload!);
          onNotificationTap?.call(data['type'] ?? '', data);
        }
      },
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      description: 'TrackMate notifications',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  /// Get and store FCM token
  Future<void> _getFcmToken() async {
    _fcmToken = await _messaging.getToken();
    debugPrint('FCM Token: $_fcmToken');

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      debugPrint('FCM Token refreshed: $newToken');
    });
  }

  /// Store FCM token in Firestore for a user
  Future<void> storeFcmToken(String userId) async {
    if (_fcmToken == null) return;

    await _firestore
        .collection(AppConstants.fcmTokensCollection)
        .doc(userId)
        .set({
          'token': _fcmToken,
          'updatedAt': Timestamp.now(),
          'platform': 'android', // or determine platform dynamically
        }, SetOptions(merge: true));
  }

  /// Remove FCM token from Firestore (on logout)
  Future<void> removeFcmToken(String userId) async {
    await _firestore
        .collection(AppConstants.fcmTokensCollection)
        .doc(userId)
        .delete();
  }

  /// Handle foreground messages - show local notification
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notificationChannelId,
          AppConstants.notificationChannelName,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'] as String? ?? '';
    onNotificationTap?.call(type, message.data);
  }

  /// Get FCM tokens for a list of user IDs (for sending notifications)
  Future<List<String>> getFcmTokensForUsers(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    final tokens = <String>[];

    // Firestore whereIn is limited to 10 items
    for (var i = 0; i < userIds.length; i += 10) {
      final chunk = userIds.skip(i).take(10).toList();
      final snapshot = await _firestore
          .collection(AppConstants.fcmTokensCollection)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        final token = doc.data()['token'] as String?;
        if (token != null) {
          tokens.add(token);
        }
      }
    }

    return tokens;
  }

  /// Show a local notification manually
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notificationChannelId,
          AppConstants.notificationChannelName,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: data != null ? jsonEncode(data) : null,
    );
  }
}
