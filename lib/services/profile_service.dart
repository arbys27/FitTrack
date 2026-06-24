import '../models/user_model.dart';

/// Service for managing user profile data
/// Currently uses in-memory storage for local persistence
/// TODO: Connect to Firestore when backend is ready
class ProfileService {
  // In-memory storage for user profiles
  // In production, this would be replaced with local persistence (SharedPreferences, Hive, etc.)
  // or direct Firestore integration
  static final Map<String, User> _profileStorage = {};

  /// Save user profile locally
  /// TODO: Replace with Firestore.collection('users').doc(user.id).set()
  Future<bool> saveProfile(User user) async {
    try {
      _profileStorage[user.id] = user;
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    } catch (e) {
      print('Error saving profile: $e');
      return false;
    }
  }

  /// Get user profile by ID
  /// TODO: Replace with Firestore.collection('users').doc(userId).get()
  Future<User?> getProfile(String userId) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 300));
      return _profileStorage[userId];
    } catch (e) {
      print('Error retrieving profile: $e');
      return null;
    }
  }

  /// Update specific profile fields
  /// TODO: Replace with Firestore.collection('users').doc(userId).update()
  Future<bool> updateProfile(
    String userId, {
    String? name,
    String? gender,
    int? age,
    double? height,
    double? weight,
    String? fitnessGoal,
    bool? isProfileCompleted,
  }) async {
    try {
      final existingUser = _profileStorage[userId];
      if (existingUser == null) {
        print('User not found');
        return false;
      }

      final updatedUser = existingUser.copyWith(
        name: name,
        gender: gender,
        age: age,
        height: height,
        weight: weight,
        fitnessGoal: fitnessGoal,
        isProfileCompleted: isProfileCompleted,
      );

      _profileStorage[userId] = updatedUser;
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

  /// Mark profile as completed
  /// TODO: Connect to Firestore when backend is ready
  Future<bool> markProfileCompleted(String userId) async {
    try {
      final user = _profileStorage[userId];
      if (user == null) {
        print('User not found');
        return false;
      }

      final updatedUser = user.copyWith(isProfileCompleted: true);
      _profileStorage[userId] = updatedUser;
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    } catch (e) {
      print('Error marking profile as completed: $e');
      return false;
    }
  }

  /// Check if profile is completed
  /// TODO: Connect to Firestore when backend is ready
  Future<bool> isProfileCompleted(String userId) async {
    try {
      final user = _profileStorage[userId];
      return user?.isProfileCompleted ?? false;
    } catch (e) {
      print('Error checking profile completion: $e');
      return false;
    }
  }

  /// Clear storage (for testing/debugging)
  void clearStorage() {
    _profileStorage.clear();
  }

  /// Get all stored profiles (for debugging)
  Map<String, User> getAllProfiles() => Map.from(_profileStorage);
}
