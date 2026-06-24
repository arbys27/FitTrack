import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firebase_user_service.dart';

/// Provider for dashboard state management
/// Handles user profile loading and greeting generation
class DashboardProvider extends ChangeNotifier {
  DashboardProvider() {
    _firebaseUserService = FirebaseUserService();
  }

  late final FirebaseUserService _firebaseUserService;
  User? _userProfile;
  String? _greetingText;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get userProfile => _userProfile;
  String? get greetingText => _greetingText;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Generate greeting text based on current time of day
  /// 5:00 AM to 11:59 AM = Good morning
  /// 12:00 PM to 5:59 PM = Good afternoon
  /// 6:00 PM to 4:59 AM = Good evening
  String _generateGreeting() {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 18) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  /// Load user profile and generate greeting
  /// This is called when user logs in or dashboard is first shown
  Future<void> loadDashboardData(String userId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      print('📊 DashboardProvider: Loading dashboard data for UID: $userId');

      // Fetch user profile from Firestore
      _userProfile = await _firebaseUserService.getUserProfile(userId);

      if (_userProfile == null) {
        _errorMessage = 'Failed to load user profile';
        print('⚠️  Dashboard: User profile returned null from Firestore');
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Generate greeting text with user name
      final greetingPrefix = _generateGreeting();
      final userName = _userProfile?.name ?? 'User';
      _greetingText = '$greetingPrefix, $userName';

      print('✅ Dashboard data loaded');
      print('   User Name: $userName');
      print('   Greeting: $_greetingText');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading dashboard data: ${e.toString()}';
      print('❌ Error loading dashboard data: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Force refresh dashboard data (useful on screen focus)
  Future<void> refreshDashboardData(String userId) async {
    print('🔄 DashboardProvider: Refreshing dashboard data for UID: $userId');
    await loadDashboardData(userId);
  }

  /// Clear dashboard data (used on logout)
  void clearDashboard() {
    _userProfile = null;
    _greetingText = null;
    _errorMessage = null;
    _isLoading = false;
    print('🗑️  DashboardProvider: Dashboard cleared');
    notifyListeners();
  }

  /// Get user name with fallback
  String getUserDisplayName() => _userProfile?.name ?? 'User';

  /// Get full greeting text
  String getGreetingText() => _greetingText ?? 'Welcome, User';
}
