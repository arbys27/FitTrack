import 'dart:async';

import 'package:flutter/material.dart';

import '../services/firebase_step_service.dart';
import '../services/step_service.dart';

/// Provider for managing step tracking state
/// Integrates StepService (pedometer) and FirebaseStepService (Firestore)
class StepProvider extends ChangeNotifier with WidgetsBindingObserver {
  final StepService _stepService = StepService();
  final FirebaseStepService _firebaseStepService = FirebaseStepService();

  int _todaySteps = 0;
  int _stepGoal = 10000;
  double _caloriesBurned = 0;
  bool _isLoading = false;
  String? _error;
  bool _permissionGranted = false;
  bool _isInitialized = false;
  String _lastSyncedDate = '';
  
  Timer? _syncTimer;
  static const Duration _syncInterval = Duration(seconds: 30);

  /// Getters
  int get todaySteps => _todaySteps;
  int get stepGoal => _stepGoal;
  double get caloriesBurned => _caloriesBurned;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get permissionGranted => _permissionGranted;
  bool get isInitialized => _isInitialized;

  /// Initialize step provider
  /// - Request permissions
  /// - Start step tracking
  /// - Load today's data from Firestore
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🚀 [StepProvider] Initializing...');

      // ← ADD: Register lifecycle observer
      WidgetsBinding.instance.addObserver(this);

      _permissionGranted = await _stepService.initialize();
      if (!_permissionGranted) {
        _error = 'Step tracking permission is required to count your steps.';
        _isLoading = false;
        _isInitialized = false;
        notifyListeners();
        return;
      }

      // Load user's step goal
      _stepGoal = await _firebaseStepService.getUserStepGoal();

      // Load today's step data from Firestore
      await _loadTodayStepsFromFirebase();

      // Start periodic sync
      _startPeriodicSync();

       _lastSyncedDate = _getTodayDateString();

      _isInitialized = true;
      debugPrint('✅ [StepProvider] Initialized successfully');
    } catch (e) {
      _error = 'Failed to initialize step tracking: $e';
      debugPrint('❌ [StepProvider] $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ← ADD: App lifecycle handler — saves steps when app goes to background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      debugPrint('📱 [StepProvider] App going to background — saving steps...');
      syncStepsToFirebase();
    }

    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 [StepProvider] App resumed — checking for day rollover...');
      _checkDayRollover();
    }
  }

  Future<void> _checkDayRollover() async {
    final today = _getTodayDateString();
    if (_lastSyncedDate.isNotEmpty && _lastSyncedDate != today) {
      debugPrint('🌅 [StepProvider] New day detected! Resetting steps for $today');
      // Save yesterday's final count first
      await _saveEndOfDaySteps(_lastSyncedDate);
      // Reset for new day
      _todaySteps = 0;
      _caloriesBurned = 0;
      _lastSyncedDate = today;
      notifyListeners();
    }
  }

  Future<void> _saveEndOfDaySteps(String date) async {
    try {
      final data = DailyStepData(
        date: date,
        steps: _todaySteps,
        stepGoal: _stepGoal,
        caloriesBurned: _caloriesBurned,
        updatedAt: DateTime.now(),
      );
      await _firebaseStepService.saveDailySteps(data);
      debugPrint('🌙 [StepProvider] End-of-day saved for $date: $_todaySteps steps');
    } catch (e) {
      debugPrint('❌ [StepProvider] Failed to save end-of-day steps: $e');
    }
  }


  /// Load today's steps from Firestore
   Future<void> _loadTodayStepsFromFirebase() async {
    try {
      final data = await _firebaseStepService.getTodaySteps();
      if (data != null) {
        _todaySteps = data.steps;
        _caloriesBurned = data.caloriesBurned;
        _stepGoal = data.stepGoal;
        debugPrint('✅ [StepProvider] Loaded from Firestore: $_todaySteps steps');
      } else {
        _todaySteps = _stepService.getTodaySteps();
        _updateCalories();
      }
    } catch (e) {
      debugPrint('❌ [StepProvider] Error loading from Firestore: $e');
    }
  }


  /// Start periodic sync of step data to Firestore
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) async {
      await _checkDayRollover();
      await syncStepsToFirebase();
    });
  }

  /// Sync current step data to Firestore
  Future<void> syncStepsToFirebase() async {
    try {
      _todaySteps = _stepService.getTodaySteps();
      _updateCalories();

      final success = await _firebaseStepService.updateTodaySteps(
        _todaySteps,
        _caloriesBurned,
        _stepGoal,
      );

      if (success) {
        _lastSyncedDate = _getTodayDateString();
        debugPrint('🔄 [StepProvider] Synced to Firestore: $_todaySteps steps');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ [StepProvider] Error syncing to Firestore: $e');
    }
  }

  /// Update calories based on steps
  void _updateCalories() {
    _caloriesBurned = _stepService.calculateCalories(_todaySteps);
  }

  /// Get progress towards daily goal (0.0 to 1.0)
  double getProgress() => _stepService.getProgressTowardGoal(_todaySteps, _stepGoal);

  /// Manually set step goal (useful for user settings)
  Future<void> setStepGoal(int goal) async {
    _stepGoal = goal;
    await syncStepsToFirebase();
    notifyListeners();
  }

  /// Refresh step data from both sensor and Firestore
  Future<void> refreshSteps() async {
    try {
      _todaySteps = _stepService.getTodaySteps();
      _updateCalories();
      await syncStepsToFirebase();
    } catch (e) {
      _error = 'Failed to refresh steps: $e';
    }
    notifyListeners();
  }

  /// Get step data for a specific date from Firestore
  Future<DailyStepData?> getStepsForDate(String dateString) async {
    try {
      return await _firebaseStepService.getStepsForDate(dateString);
    } catch (e) {
      debugPrint('❌ [StepProvider] Error getting steps for date: $e');
      return null;
    }
  }

  /// Get recent step data from Firestore
  Future<List<DailyStepData>> getRecentSteps({int days = 7}) async {
    try {
      return await _firebaseStepService.getRecentSteps(days: days);
    } catch (e) {
      return [];
    }
  }

  /// Get average steps over N days
  Future<double> getAverageSteps({int days = 7}) async {
    try {
      return await _firebaseStepService.getAverageSteps(days: days);
    } catch (e) {
      return 0.0;
    }
  }

  /// Get total calories over N days
  Future<double> getTotalCalories({int days = 7}) async {
    try {
      return await _firebaseStepService.getTotalCalories(days: days);
    } catch (e) {
      return 0.0;
    }
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear step data (used on logout)
  void clearSteps() {
    _todaySteps = 0;
    _caloriesBurned = 0;
    _error = null;
    _isLoading = false;
    _permissionGranted = false;
    _isInitialized = false;
    _lastSyncedDate = '';
    _syncTimer?.cancel();
    // ← ADD: Remove lifecycle observer on clear
    WidgetsBinding.instance.removeObserver(this);
    notifyListeners();
  }

  /// Dispose resources
  @override
  Future<void> dispose() async {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this); // ← ADD
    await _stepService.dispose();
    super.dispose();
  }
}
