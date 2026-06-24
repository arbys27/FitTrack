import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'dashboard_provider.dart';
import 'goal_provider.dart';
import 'profile_provider.dart';
import 'progress_provider.dart';
import 'stats_provider.dart';
import 'step_provider.dart';
import 'workout_provider.dart';

/// Provider for authentication state management
class AuthProvider extends ChangeNotifier {

  /// Initialize provider and load current user
  AuthProvider() {
    _loadCurrentUser();
  }
  final AuthService _authService = AuthService();
  User? _currentUser;

  bool get isLoggedIn => _authService.isLoggedIn;
  User? get currentUser => _currentUser;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  /// Flag to signal that profile completion status has changed
  /// Used by AuthGate to know when to force re-resolution
  bool _profileCompletionStatusChanged = false;
  bool get profileCompletionStatusChanged => _profileCompletionStatusChanged;

  /// Load current user from Firebase
  Future<void> _loadCurrentUser() async {
    if (_authService.isLoggedIn) {
      _currentUser = await _authService.getCurrentUserData();
      notifyListeners();
    }
  }

  /// Signal that profile completion status has been updated
  /// Called from FitnessProfileSetupScreen after profile is saved
  void signalProfileCompletionStatusChanged() {
    _profileCompletionStatusChanged = true;
    print('🔔 [AuthProvider] Profile completion status changed. Notifying listeners...');
    notifyListeners();
  }
  
  /// Reset the profile completion status changed flag
  /// Called by AuthGate after it has re-resolved the route
  void resetProfileCompletionStatusChanged() {
    _profileCompletionStatusChanged = false;
  }

  /// Login user
  Future<bool> login(String email, String password) async {
    try {
      _errorMessage = null;
      final success = await _authService.login(email, password);
      if (success) {
        await _loadCurrentUser();
        notifyListeners();
      } else {
        _errorMessage = _authService.lastError ?? 'Invalid email or password';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Login error: ${e.toString()}';
      return false;
    }
  }

  /// Sign in with Google - only for registered users
  /// Returns false if the Google account is not registered
  Future<bool> signInWithGoogle() async {
    try {
      _errorMessage = null;
      final success = await _authService.signInWithGoogle();
      if (success) {
        await _loadCurrentUser();
        notifyListeners();
      } else {
        _errorMessage = _authService.lastError ?? 'Google sign-in failed';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Google sign-in error: ${e.toString()}';
      return false;
    }
  }

  /// Register with Google - creates a new Google user account
  /// This method is specifically for new user registration via Google
  Future<bool> registerWithGoogle() async {
    try {
      _errorMessage = null;
      final success = await _authService.registerWithGoogle();
      if (success) {
        await _loadCurrentUser();
        notifyListeners();
      } else {
        _errorMessage = _authService.lastError ?? 'Google registration failed';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Google registration error: ${e.toString()}';
      return false;
    }
  }

  /// Check if a Google user is registered
  Future<bool> isGoogleUserRegistered(String uid) async {
    try {
      return await _authService.isGoogleUserRegistered(uid);
    } catch (e) {
      print('Error checking registration: $e');
      return false;
    }
  }

  /// Register new user
  Future<bool> register(
    String name,
    String email,
    String password,
    String confirmPassword,
  ) async {
    try {
      _errorMessage = null;
      if (password != confirmPassword) {
        _errorMessage = 'Passwords do not match';
        return false;
      }
      if (password.length < 8) {
        _errorMessage = 'Password must be at least 8 characters';
        return false;
      }
      final success = await _authService.register(
        name,
        email,
        password,
        confirmPassword,
      );
      if (success) {
        await _loadCurrentUser();
        notifyListeners();
      } else {
        _errorMessage = 'Registration failed. Email may already exist.';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Registration error: ${e.toString()}';
      return false;
    }
  }

  /// Logout user and clear all cached data
  /// This method:
  /// - Signs out from Firebase
  /// - Clears the current user from AuthProvider
  /// - Should be called with context to clear other providers (see main_shell or settings)
  Future<void> logout() async {
    try {
      print('🚪 [AuthProvider] Logging out user...');
      _errorMessage = null;
      await _authService.logout();
      _currentUser = null;
      print('✅ [AuthProvider] User logged out successfully');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Logout error: ${e.toString()}';
      print('❌ [AuthProvider] Logout error: $_errorMessage');
    }
  }

  /// Clear all application state providers on logout
  /// Must be called from a BuildContext to access all providers
  /// This ensures no previous user's data is shown after logout
  static Future<void> clearAllProvidersOnLogout(BuildContext context) async {
    try {
      print('🔄 [AuthProvider] Clearing all provider states...');
      
      // Access all providers and clear their state
      if (context.mounted) {
        context.read<ProfileProvider>().clearProfile();
        context.read<DashboardProvider>().clearDashboard();
        context.read<StepProvider>().clearSteps();
        context.read<WorkoutProvider>().clearWorkouts();
        context.read<GoalProvider>().clearGoals();
        context.read<StatsProvider>().clearStats();
        context.read<ProgressProvider>().clearProgress();
        
        print('✅ [AuthProvider] All provider states cleared successfully');
      }
    } catch (e) {
      print('❌ [AuthProvider] Error clearing providers: $e');
    }
  }

  /// Update user profile
  Future<bool> updateProfile(User updatedUser) async {
    try {
      _errorMessage = null;
      final success = await _authService.updateProfile(updatedUser);
      if (success) {
        _currentUser = updatedUser;
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = 'Profile update error: ${e.toString()}';
      return false;
    }
  }

  /// Reset password
  Future<String?> resetPassword(String email) async {
    try {
      _errorMessage = null;
      final otp = await _authService.resetPassword(email);
      if (otp == null) {
        _errorMessage = _authService.lastError ?? 'Failed to send reset email';
      }
      return otp;
    } catch (e) {
      _errorMessage = 'Reset password error: ${e.toString()}';
      return null;
    }
  }

  /// Verify OTP and send password reset email
  Future<bool> verifyOTPAndSendReset(String email, String otp) async {
    try {
      _errorMessage = null;
      final success = await _authService.verifyOTPAndSendReset(email, otp);
      if (!success) {
        _errorMessage = _authService.lastError ?? 'Failed to verify OTP';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Verify OTP error: ${e.toString()}';
      return false;
    }
  }

  /// Generate OTP for password reset
  Future<String?> generatePasswordResetOTP(String email) async {
    try {
      _errorMessage = null;
      final otp = await _authService.resetPassword(email);
      if (otp == null) {
        _errorMessage = _authService.lastError ?? 'Failed to generate OTP';
      }
      return otp;
    } catch (e) {
      _errorMessage = 'Generate OTP error: ${e.toString()}';
      return null;
    }
  }

  /// Verify OTP for password reset
  Future<bool> verifyPasswordResetOTP(String email, String otp) async {
    try {
      _errorMessage = null;
      final success = await _authService.verifyOTPAndSendReset(email, otp);
      if (!success) {
        _errorMessage = _authService.lastError ?? 'Failed to verify OTP';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Verify OTP error: ${e.toString()}';
      return false;
    }
  }

  /// Reset password after OTP verification
  Future<bool> resetPasswordAfterOTP(String email, String newPassword) async {
    try {
      _errorMessage = null;
      final success = await _authService.updatePasswordAfterOTP(email, newPassword);
      if (!success) {
        _errorMessage = _authService.lastError ?? 'Failed to reset password';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Reset password error: ${e.toString()}';
      return false;
    }
  }

  /// Check if account exists in Firestore but not in Firebase Auth
  Future<bool> checkAccountWithoutAuth(String email) async {
    try {
      _errorMessage = null;
      return await _authService.accountExistsWithoutAuth(email);
    } catch (e) {
      _errorMessage = 'Error checking account: ${e.toString()}';
      return false;
    }
  }

  /// Recover account that exists in Firestore but not in Firebase Auth
  Future<bool> recoverAccount(String email, String password) async {
    try {
      _errorMessage = null;
      final success = await _authService.recoverAccountWithoutAuth(email, password);
      if (success) {
        await _loadCurrentUser();
        notifyListeners();
      } else {
        _errorMessage = _authService.lastError ?? 'Failed to recover account';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Account recovery error: ${e.toString()}';
      return false;
    }
  }

  /// Get next route after authentication
  /// Resolves whether user should go to profile setup or dashboard
  Future<String> resolveNextRoute() async {
    try {
      if (!isLoggedIn || _authService.currentUserId == null) {
        print('⚠️ [AuthProvider] User not logged in or UID is null');
        return 'login';
      }

      // Get the Firebase user to pass to the service
      final fbUser = _getFBUser();
      if (fbUser == null) {
        print('⚠️ [AuthProvider] Could not get Firebase user');
        return 'fitnessProfileSetup';
      }

      // Use the centralized route resolution from AuthService
      final route = await _authService.resolveNextRouteAfterAuth(fbUser);
      print('✅ [AuthProvider] Next route resolved: $route');
      return route;
    } catch (e) {
      print('❌ [AuthProvider] Error resolving next route: $e');
      return 'fitnessProfileSetup'; // Fallback
    }
  }

  /// Get the Firebase User object (for internal use)
  /// This is a helper to access the Firebase user from FirebaseAuth
  firebase_auth.User? _getFBUser() {
    try {
      // Import firebase_auth package as fb
      return firebase_auth.FirebaseAuth.instance.currentUser;
    } catch (e) {
      print('Error getting Firebase user: $e');
      return null;
    }
  }

  /// Auto-login after OTP verification — skips password creation
Future<bool> loginAfterOTPVerification(String email) async {
  try {
    _errorMessage = null;
    final success = await _authService.loginAfterOTPVerification(email);
    if (success) {
      await _loadCurrentUser();
      notifyListeners();
    } else {
      _errorMessage = _authService.lastError;
    }
    return success;
  } catch (e) {
    _errorMessage = 'Login error: ${e.toString()}';
    return false;
  }
}

  /// Clear any error messages
  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }
}
