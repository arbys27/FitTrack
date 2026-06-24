import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart' as fb_core;

import '../models/user_model.dart';

/// Firebase Firestore User Profile Service
/// Handles all user profile operations with Firestore
/// Manages profile creation, retrieval, and updates
class FirebaseUserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  String? _lastError;
  String? get lastError => _lastError;

  /// ============================================
  /// CREATE / INITIALIZE USER PROFILE
  /// ============================================
  /// Create a new user profile in Firestore
  /// Called when user first registers (Email/Google)
  /// Sets minimal profile with auth provider info
  Future<bool> createUserProfile({
    required String uid,
    required String fullName,
    required String email,
    required String authProvider, // 'email' or 'google'
    String? photoURL,
  }) async {
    try {
      if (!await _ensureFirebaseInitialized()) {
        _lastError = 'Firebase not initialized';
        print('❌ [FIRESTORE] Firebase initialization failed');
        return false;
      }

      print('📝 [FIRESTORE] Creating user profile in Firestore');
      print('   Path: users/$uid');
      print('   UID: $uid');
      print('   Email: $email');
      print('   Name: $fullName');
      print('   Provider: $authProvider');

      final now = Timestamp.now();

      final profileData = {
        'uid': uid,
        'fullName': fullName,
        'email': email,
        'photoURL': photoURL ?? '',
        'authProvider': authProvider,
        'gender': 'Not specified',
        'age': 0,
        'height': 170.0, // Default height in cm
        'weight': 65.0, // Default weight in kg
        'fitnessGoal': 'Stay Active',
        'bmi': 0.0,
        'isProfileCompleted': false, // User still needs to complete fitness profile
        'createdAt': now,
        'updatedAt': now,
      };

      print('📤 [FIRESTORE] Writing document with ${profileData.length} fields...');
      
      await _firestore.collection('users').doc(uid).set(
        profileData,
        SetOptions(merge: true), // Merge to avoid overwriting existing data
      );

      print('✅ [FIRESTORE] User profile created successfully in Firestore');
      print('   Document path: users/$uid');
      print('   Profile data saved with fields: ${profileData.keys.toList()}');
      return true;
    } on FirebaseException catch (e) {
      _lastError = 'Firestore error: ${e.message}';
      print('❌ [FIRESTORE] Firestore error creating profile');
      print('   Error Code: ${e.code}');
      print('   Error Message: ${e.message}');
      print('   Error Details: ${e.toString()}');
      return false;
    } catch (e) {
      _lastError = 'Error creating profile: $e';
      print('❌ [FIRESTORE] Unexpected error creating profile');
      print('   Error Type: ${e.runtimeType}');
      print('   Error: $e');
      print('   Stack: ${e.toString()}');
      return false;
    }
  }

  /// ============================================
  /// SAVE / UPDATE FITNESS PROFILE
  /// ============================================
  /// Save complete fitness profile after setup
  /// Called from FitnessProfileSetupScreen
  /// Calculates BMI automatically
  Future<bool> saveFitnessProfile({
    required String uid,
    required String fullName,
    required String gender,
    required int age,
    required double height, // in cm
    required double weight, // in kg
    required String fitnessGoal,
  }) async {
    try {
      if (!await _ensureFirebaseInitialized()) {
        _lastError = 'Firebase not initialized';
        return false;
      }

      print('💾 Saving fitness profile for UID: $uid');

      // Calculate BMI
      final bmi = _calculateBMI(height, weight);
      print('   BMI calculated: ${bmi.toStringAsFixed(1)}');

      final now = Timestamp.now();

      await _firestore.collection('users').doc(uid).update({
        'fullName': fullName,
        'gender': gender,
        'age': age,
        'height': height,
        'weight': weight,
        'fitnessGoal': fitnessGoal,
        'bmi': bmi,
        'isProfileCompleted': true, // Mark profile as completed
        'updatedAt': now,
      });

      print('✅ Fitness profile saved successfully');
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        _lastError = 'User profile not found. Please try registering again.';
        print('❌ User profile document not found');
      } else {
        _lastError = 'Firestore error: ${e.message}';
        print('❌ Firestore error: ${e.code}');
      }
      return false;
    } catch (e) {
      _lastError = 'Error saving profile: $e';
      print('❌ Error saving profile: $e');
      return false;
    }
  }

  /// ============================================
  /// UPDATE USER PROFILE
  /// ============================================
  /// Update specific profile fields
  /// Called from ProfileScreen edit functionality
  Future<bool> updateUserProfile({
    required String uid,
    String? fullName,
    String? gender,
    int? age,
    double? height,
    double? weight,
    String? fitnessGoal,
  }) async {
    try {
      if (!await _ensureFirebaseInitialized()) {
        _lastError = 'Firebase not initialized';
        return false;
      }

      print('✏️ Updating profile for UID: $uid');

      final updateData = <String, dynamic>{
        'updatedAt': Timestamp.now(),
      };

      // Only add fields that are provided
      if (fullName != null) updateData['fullName'] = fullName;
      if (gender != null) updateData['gender'] = gender;
      if (age != null) updateData['age'] = age;
      if (height != null) updateData['height'] = height;
      if (weight != null) updateData['weight'] = weight;
      if (fitnessGoal != null) updateData['fitnessGoal'] = fitnessGoal;

      // Recalculate BMI if height or weight changed
      if (height != null || weight != null) {
        final currentProfile = await getUserProfile(uid);
        if (currentProfile != null) {
          final newHeight = height ?? currentProfile.height;
          final newWeight = weight ?? currentProfile.weight;
          final newBmi = _calculateBMI(newHeight, newWeight);
          updateData['bmi'] = newBmi;
          print('   BMI recalculated: ${newBmi.toStringAsFixed(1)}');
        }
      }

      await _firestore.collection('users').doc(uid).update(updateData);

      print('✅ Profile updated successfully');
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        _lastError = 'User profile not found';
        print('❌ User profile not found');
      } else {
        _lastError = 'Firestore error: ${e.message}';
        print('❌ Firestore error: ${e.code}');
      }
      return false;
    } catch (e) {
      _lastError = 'Error updating profile: $e';
      print('❌ Error updating profile: $e');
      return false;
    }
  }

  /// ============================================
  /// RETRIEVE USER PROFILE
  /// ============================================
  /// Get user profile from Firestore
  /// Used to load profile data on app startup and profile screen
  /// Always fetches fresh data from Firestore (no caching)
  Future<User?> getUserProfile(String uid) async {
    try {
      if (!await _ensureFirebaseInitialized()) {
        print('⚠️ Firebase not initialized');
        return null;
      }

      print('📖 Fetching profile for UID: $uid (fresh from Firestore)');

      // Get the document - this will be fresh from Firestore
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        print('❌ User profile not found in Firestore');
        print('   Path: users/$uid');
        return null;
      }

      final data = doc.data()!;
      print('✅ Profile fetched successfully from Firestore');
      print('   isProfileCompleted: ${data['isProfileCompleted']}');

      // Convert Firestore document to User model with proper type conversion
      final isProfileCompleted = data['isProfileCompleted'] ?? false;
      print('   Profile data retrieved:');
      print('     - fullName: ${data['fullName']}');
      print('     - gender: ${data['gender']}');
      print('     - age: ${data['age']}');
      print('     - isProfileCompleted: $isProfileCompleted');
      
      return User(
        id: uid,
        name: data['fullName'] ?? 'User',
        email: data['email'] ?? '',
        gender: data['gender'] ?? 'Not specified',
        age: data['age'] ?? 0,
        height: (data['height'] ?? 170).toDouble(),
        weight: (data['weight'] ?? 65).toDouble(),
        dateOfBirth: _parseDateOfBirth(data),
        fitnessGoal: data['fitnessGoal'] ?? 'Stay Active',
        isProfileCompleted: isProfileCompleted,
        photoURL: data['photoURL'] ?? '',
        // isProfileCompleted already set above
        // isProfileCompleted: data['isProfileCompleted'] ?? false,
      );
    } on FirebaseException catch (e) {
      print('❌ Firestore error: ${e.code}');
      return null;
    } catch (e) {
      print('❌ Error fetching profile: $e');
      return null;
    }
  }

  /// ============================================
  /// CHECK PROFILE COMPLETION STATUS
  /// ============================================
  /// Check if user profile is completed
  /// Used in AuthGate to determine navigation
  Future<bool> isProfileCompleted(String uid) async {
    try {
      if (!await _ensureFirebaseInitialized()) {
        print('⚠️ Firebase not initialized for profile check');
        return false;
      }

      print('🔍 Checking profile completion for UID: $uid');

      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        print('❌ User profile not found in Firestore');
        print('   Path: users/$uid');
        return false;
      }

      final isCompleted = doc.data()?['isProfileCompleted'] ?? false;
      print('✅ Profile completion check complete');
      print('   isProfileCompleted: $isCompleted');
      print('   UID: $uid');
      return isCompleted as bool;
    } catch (e) {
      print('❌ Error checking profile completion: $e');
      return false;
    }
  }

  /// ============================================
  /// CHECK IF USER PROFILE EXISTS
  /// ============================================
  /// Check if user has a profile document in Firestore
  /// Used to determine if we need to create minimal profile
  Future<bool> userProfileExists(String uid) async {
    try {
      if (!await _ensureFirebaseInitialized()) {
        return false;
      }

      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists;
    } catch (e) {
      print('Error checking profile existence: $e');
      return false;
    }
  }

  /// ============================================
  /// HELPER METHODS
  /// ============================================

  /// Calculate BMI (Body Mass Index)
  /// Formula: weight (kg) / (height (m))^2
  double _calculateBMI(double height, double weight) {
    if (height <= 0 || weight <= 0) return 0;
    final heightInMeters = height / 100;
    return weight / (heightInMeters * heightInMeters);
  }

  /// Parse date of birth from Firestore data
  /// Converts Timestamp to DateTime
  DateTime _parseDateOfBirth(Map<String, dynamic> data) {
    try {
      if (data['dateOfBirth'] != null && data['dateOfBirth'] is Timestamp) {
        return (data['dateOfBirth'] as Timestamp).toDate();
      }
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  /// Ensure Firebase is initialized
  Future<bool> _ensureFirebaseInitialized() async {
    if (fb_core.Firebase.apps.isNotEmpty) {
      return true;
    }

    try {
      print('⏳ Initializing Firebase...');
      // Firebase should already be initialized in main.dart
      return fb_core.Firebase.apps.isNotEmpty;
    } catch (e) {
      print('❌ Firebase initialization error: $e');
      return false;
    }
  }

  /// Get current authenticated user UID
  /// Helper method for convenience
  String? getCurrentUserUid() => _auth.currentUser?.uid;

  /// Get current authenticated user email
  String? getCurrentUserEmail() => _auth.currentUser?.email;
}
