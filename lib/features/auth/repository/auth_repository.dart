import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/firebase_service.dart';
import '../model/user_model.dart';

/// Repository for handling authentication operations
class AuthRepository {
  final FirebaseAuth _auth = FirebaseService.instance.auth;
  final FirebaseFirestore _firestore = FirebaseService.instance.firestore;

  /// Register a new user with username, email, and password
  ///
  /// Note: Firebase Auth requires email for authentication.
  /// We use a fake email format: username@trackmate.local
  /// The actual email is stored in Firestore for display purposes.
  Future<UserModel> register({
    required String username,
    required String password,
    String? email,
  }) async {
    // Check if username already exists
    final usernameExists = await _checkUsernameExists(username);
    if (usernameExists) {
      throw Exception('Username already taken');
    }

    // Create auth email from username (for Firebase Auth)
    final authEmail = '${username.toLowerCase()}@trackmate.local';

    try {
      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Create user document in Firestore
      final userModel = UserModel(
        uid: uid,
        username: username,
        email: email ?? '',
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set(userModel.toMap());

      return userModel;
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  /// Login with username and password
  Future<UserModel> login({
    required String username,
    required String password,
  }) async {
    // Create auth email from username
    final authEmail = '${username.toLowerCase()}@trackmate.local';

    try {
      // Sign in with Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Get user document from Firestore
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User data not found');
      }

      return UserModel.fromFirestore(userDoc);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        throw Exception('Invalid username or password');
      }
      throw Exception('Login failed: ${e.message}');
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  /// Logout current user
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Get currently logged in user
  Future<UserModel?> getCurrentUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return null;
    }

    final userDoc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(currentUser.uid)
        .get();

    if (!userDoc.exists) {
      return null;
    }

    return UserModel.fromFirestore(userDoc);
  }

  /// Check if a username already exists
  Future<bool> _checkUsernameExists(String username) async {
    final querySnapshot = await _firestore
        .collection(AppConstants.usersCollection)
        .where('usernameLower', isEqualTo: username.toLowerCase())
        .limit(1)
        .get(); // This query is failing with PERMISSION_DENIED

    return querySnapshot.docs.isNotEmpty;
  }

  /// Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    final userDoc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();

    if (!userDoc.exists) {
      return null;
    }

    return UserModel.fromFirestore(userDoc);
  }
}
