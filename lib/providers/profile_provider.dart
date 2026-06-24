import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firebase_user_service.dart';

/// Provider for user profile state management
/// Uses Firebase Firestore as the data source
class ProfileProvider extends ChangeNotifier {
  ProfileProvider() {
    _firebaseUserService = FirebaseUserService();
  }

  late final FirebaseUserService _firebaseUserService;
  User? _userProfile;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isProfileCompleted = false;

  // Getters
  User? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isProfileCompleted => _isProfileCompleted;

  /// Load user profile from Firestore
  /// Called when user is authenticated
  /// This method will force a fresh load from Firestore, not using cache
  Future<void> loadProfile(String userId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      print('📚 ProfileProvider: Loading profile for UID: $userId');

      // Fetch profile from Firestore (fresh data)
      _userProfile = await _firebaseUserService.getUserProfile(userId);
      
      if (_userProfile == null) {
        _errorMessage = 'Profile not found';
        print('⚠️ Profile returned null from Firestore');
        _isProfileCompleted = false;
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      // Check if profile is completed - directly from the user model
      _isProfileCompleted = _userProfile?.isProfileCompleted ?? false;
      
      print('✅ Profile loaded. Completed: $_isProfileCompleted');
      print('   Name: ${_userProfile?.name}');
      print('   Email: ${_userProfile?.email}');
      print('   Age: ${_userProfile?.age}, Gender: ${_userProfile?.gender}');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading profile: ${e.toString()}';
      print('❌ Error loading profile: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Force refresh the profile from Firestore (bypasses any caching)
  /// Call this after user authentication to ensure latest data
  Future<void> forceRefreshProfile(String userId) async {
    try {
      print('🔄 ProfileProvider: Force refreshing profile for UID: $userId');
      
      // Add a small delay to ensure Firestore has persisted the data
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Load the profile fresh from Firestore
      await loadProfile(userId);
      
      print('✅ Profile force-refreshed successfully');
    } catch (e) {
      _errorMessage = 'Error refreshing profile: ${e.toString()}';
      print('❌ Error force-refreshing profile: $e');
      notifyListeners();
    }
  }

  /// Clear profile data (used on logout)
  void clearProfile() {
    _userProfile = null;
    _isProfileCompleted = false;
    _errorMessage = null;
    print('🗑️  ProfileProvider: Profile cleared');
    notifyListeners();
  }

  /// Save fitness profile to Firestore
  /// Called when user completes fitness profile setup
  Future<bool> saveFitnessProfile({
    required String userId,
    required String name,
    required String gender,
    required int age,
    required double height,
    required double weight,
    required String fitnessGoal,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      print('💾 ProfileProvider: Saving fitness profile');

      // Save profile to Firestore
      final success = await _firebaseUserService.saveFitnessProfile(
        uid: userId,
        fullName: name,
        gender: gender,
        age: age,
        height: height,
        weight: weight,
        fitnessGoal: fitnessGoal,
      );

      if (success) {
        // Reload profile from Firestore to get updated data
        await Future.delayed(const Duration(milliseconds: 200)); // Let Firestore persist
        _userProfile = await _firebaseUserService.getUserProfile(userId);
        _isProfileCompleted = _userProfile?.isProfileCompleted ?? true;
        print('✅ Profile saved and reloaded successfully');
        print('   isProfileCompleted: $_isProfileCompleted');
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = _firebaseUserService.lastError ?? 'Failed to save profile';
        print('❌ Failed to save profile: $_errorMessage');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error saving profile: ${e.toString()}';
      print('❌ Error saving profile: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update existing profile on Firestore
  /// Called from ProfileScreen edit functionality
  Future<bool> updateProfile({
    required String userId,
    String? name,
    String? gender,
    int? age,
    double? height,
    double? weight,
    String? fitnessGoal,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      print('✏️ ProfileProvider: Updating profile');

      final success = await _firebaseUserService.updateUserProfile(
        uid: userId,
        fullName: name,
        gender: gender,
        age: age,
        height: height,
        weight: weight,
        fitnessGoal: fitnessGoal,
      );

      if (success) {
        // Reload profile from Firestore
        await loadProfile(userId);
        print('✅ Profile updated successfully');
        return true;
      } else {
        _errorMessage = _firebaseUserService.lastError ?? 'Failed to update profile';
        print('❌ Failed to update profile: $_errorMessage');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error updating profile: ${e.toString()}';
      print('❌ Error updating profile: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
