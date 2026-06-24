import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;


/// Firebase Authentication and Database Service
class FirebaseService {
  static final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Register user with email and password
  Future<bool> registerUser({
    required String name,
    required String email,
    required String password,
    required int age,
    required double height,
    required double weight,
    required String gender,
  }) async {
    try {
      // Create Firebase user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'name': name,
        'email': email,
        'age': age,
        'height': height,
        'weight': weight,
        'gender': gender,
        'dateOfBirth': Timestamp.now(),
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      print('User registered successfully: ${userCredential.user?.email}');
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      print('Firebase Auth Error during registration: ${e.code} - ${e.message}');
      return false;
    } on FirebaseException catch (e) {
      print('Firebase Error during registration: ${e.message}');
      return false;
    } catch (e) {
      print('Unexpected error during registration: $e');
      return false;
    }
  }

  /// Login user with email and password
  Future<firebase_auth.User?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      print('Attempting login with email: $email');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('Login successful: ${userCredential.user?.email}');
      return userCredential.user;
    } on firebase_auth.FirebaseAuthException catch (e) {
      print('Firebase Auth Error during login: ${e.code} - ${e.message}');
      return null;
    } on FirebaseException catch (e) {
      print('Firebase Error during login: ${e.message}');
      return null;
    } catch (e) {
      print('Unexpected error during login: $e');
      return null;
    }
  }

  /// Get current user from Firebase
  Future<firebase_auth.User?> getCurrentUser() async => _auth.currentUser;

  /// Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }

  /// Update user profile
  Future<bool> updateUserProfile({
    required String uid,
    required String name,
    required int age,
    required double height,
    required double weight,
    required String gender,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'name': name,
        'age': age,
        'height': height,
        'weight': weight,
        'gender': gender,
        'updatedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

  /// Save daily stats
  Future<bool> saveDailyStats({
    required String uid,
    required int steps,
    required int calories,
    required double water,
  }) async {
    try {
      final dateKey = DateTime.now().toIso8601String().split('T')[0];
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('daily_stats')
          .doc(dateKey)
          .set({
        'date': Timestamp.now(),
        'steps': steps,
        'calories': calories,
        'water': water,
        'updatedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      print('Error saving daily stats: $e');
      return false;
    }
  }

  /// Get daily stats for a date range
  Future<List<Map<String, dynamic>>> getDailyStats({
    required String uid,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('daily_stats')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(to))
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching daily stats: $e');
      return [];
    }
  }

  /// Save workout
  Future<bool> saveWorkout({
    required String uid,
    required String exerciseName,
    required int sets,
    required int reps,
    required double? weight,
    required int durationMinutes,
    required int caloriesBurned,
    required String muscleGroup,
    required String notes,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('workouts')
          .add({
        'exerciseName': exerciseName,
        'sets': sets,
        'reps': reps,
        'weight': weight,
        'durationMinutes': durationMinutes,
        'caloriesBurned': caloriesBurned,
        'muscleGroup': muscleGroup,
        'notes': notes,
        'timestamp': Timestamp.now(),
      });
      return true;
    } catch (e) {
      print('Error saving workout: $e');
      return false;
    }
  }

  /// Logout user
  Future<void> logoutUser() async {
    await _auth.signOut();
  }

  /// Delete account
  Future<bool> deleteAccount(String uid) async {
    try {
      // Delete user data from Firestore
      await _firestore.collection('users').doc(uid).delete();
      // Delete Firebase Auth user
      await _auth.currentUser?.delete();
      return true;
    } catch (e) {
      print('Error deleting account: $e');
      return false;
    }
  }

  /// Check if user exists
  Future<bool> userExists(String email) async {
    try {
      final result = await _auth.fetchSignInMethodsForEmail(email);
      return result.isNotEmpty;
    } catch (e) {
      print('Error checking user: $e');
      return false;
    }
  }

  /// Stream to listen for auth state changes
  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();
}