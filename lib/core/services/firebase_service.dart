import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firebase service for initializing and accessing Firebase instances
class FirebaseService {
  static FirebaseService? _instance;

  // Private constructor for singleton
  FirebaseService._();

  /// Get the singleton instance
  static FirebaseService get instance {
    _instance ??= FirebaseService._();
    return _instance!;
  }

  /// Initialize Firebase
  static Future<void> initialize() async {
    await Firebase.initializeApp();
  }

  /// Get Firestore instance
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Get Firebase Auth instance
  FirebaseAuth get auth => FirebaseAuth.instance;

  /// Get current user
  User? get currentUser => auth.currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  /// Get current user ID
  String? get currentUserId => currentUser?.uid;
}
