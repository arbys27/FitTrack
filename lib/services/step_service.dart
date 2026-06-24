import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling step tracking from device pedometer sensor.
/// Manages:
/// - Permission requests for ACTIVITY_RECOGNITION
/// - Step stream listening
/// - Daily baseline calculation
/// - Real-time step updates
/// - Date change detection
class StepService {
  static const String _baselineKey = 'step_baseline_';
  static const String _dateKey = 'step_date_';
  
  late Stream<StepCount> _stepCountStream;
  StreamSubscription<StepCount>? _stepSubscription;
  
  int _currentSteps = 0;
  int _baselineSteps = 0;
  DateTime _lastSyncDate = DateTime.now();
  bool _isListening = false;
  bool _permissionGranted = false;

  /// Getters
  int get currentSteps => _currentSteps;
  int get baselineSteps => _baselineSteps;
  bool get isListening => _isListening;
  bool get permissionGranted => _permissionGranted;

  /// Initialize step service
  /// Returns true if permission is granted and service started successfully
  Future<bool> initialize() async {
    debugPrint('🚶 [StepService] Initializing step service...');
    
    // Check if platform is supported
    if (!Platform.isAndroid) {
      debugPrint('❌ [StepService] Step tracking only supported on Android');
      return false;
    }

    // Request permission
    _permissionGranted = await _requestPermission();
    if (!_permissionGranted) {
      debugPrint('❌ [StepService] Permission denied for activity recognition');
      return false;
    }

    // Load baseline for today
    await _loadBaseline();
    
    // Start listening to steps
    return startStepTracking();
  }

  /// Request ACTIVITY_RECOGNITION permission
  Future<bool> _requestPermission() async {
    debugPrint('🔐 [StepService] Requesting ACTIVITY_RECOGNITION permission...');
    
    final status = await Permission.activityRecognition.request();
    
    if (status.isDenied) {
      debugPrint('❌ [StepService] Permission denied');
      return false;
    } else if (status.isPermanentlyDenied) {
      debugPrint('❌ [StepService] Permission permanently denied - opening app settings');
      openAppSettings();
      return false;
    }
    
    debugPrint('✅ [StepService] Permission granted');
    return true;
  }

  /// Start listening to step count stream
  Future<bool> startStepTracking() async {
    if (_isListening) {
      debugPrint('⏸️ [StepService] Already listening to steps');
      return true;
    }

    if (!_permissionGranted) {
      debugPrint('❌ [StepService] Permission not granted');
      return false;
    }

    try {
      debugPrint('▶️ [StepService] Starting step tracking...');
      
      // Initialize streams
      _stepCountStream = Pedometer.stepCountStream;

      // Listen to step count changes
      _stepSubscription = _stepCountStream.listen(
        _onStepCountEvent,
        onError: (error) {
          debugPrint('❌ [StepService] Step count error: $error');
        },
      );

      _isListening = true;
      debugPrint('✅ [StepService] Step tracking started');
      return true;
    } catch (e) {
      debugPrint('❌ [StepService] Error starting step tracking: $e');
      _isListening = false;
      return false;
    }
  }

  /// Handle step count events from sensor
  void _onStepCountEvent(StepCount event) {
    _currentSteps = event.steps;
    
    // Check if date has changed
    if (_hasDateChanged()) {
      debugPrint('📅 [StepService] Date changed - resetting baseline');
      _resetDailyBaseline();
    }

    debugPrint(
      '🚶 [StepService] Current sensor steps: $_currentSteps, '
      'Baseline: $_baselineSteps, Today: ${getTodaySteps()}',
    );
  }

  /// Get today's step count (sensor steps - baseline)
  int getTodaySteps() => (_currentSteps - _baselineSteps).clamp(0, double.maxFinite.toInt());

  /// Check if device date has changed
  bool _hasDateChanged() {
    final today = DateTime.now();
    final isSameDay = _lastSyncDate.year == today.year &&
        _lastSyncDate.month == today.month &&
        _lastSyncDate.day == today.day;
    return !isSameDay;
  }

  /// Load baseline steps for today from SharedPreferences
  Future<void> _loadBaseline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final dateKey = _dateKey + today.toString().split(' ')[0];
      final baselineKey = _baselineKey + today.toString().split(' ')[0];

      final savedDate = prefs.getString(dateKey);
      _baselineSteps = prefs.getInt(baselineKey) ?? 0;
      _lastSyncDate = DateTime.now();

      debugPrint(
        '📂 [StepService] Loaded baseline from preferences. '
        'Date: $savedDate, Baseline: $_baselineSteps',
      );
    } catch (e) {
      debugPrint('❌ [StepService] Error loading baseline: $e');
      _baselineSteps = 0;
    }
  }

  /// Reset daily baseline when date changes
  Future<void> _resetDailyBaseline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final dateKey = _dateKey + today.toString().split(' ')[0];
      final baselineKey = _baselineKey + today.toString().split(' ')[0];

      // Set baseline to current sensor steps to start fresh
      _baselineSteps = _currentSteps;
      
      // Save new baseline and date
      await prefs.setString(dateKey, today.toString());
      await prefs.setInt(baselineKey, _baselineSteps);

      debugPrint(
        '🔄 [StepService] Reset daily baseline. '
        'New baseline: $_baselineSteps, Today steps: ${getTodaySteps()}',
      );
    } catch (e) {
      debugPrint('❌ [StepService] Error resetting baseline: $e');
    }
  }

  /// Manually set baseline (useful for testing or app restart)
  Future<void> setBaseline(int steps) async {
    try {
      _baselineSteps = steps;
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final baselineKey = _baselineKey + today.toString().split(' ')[0];
      
      await prefs.setInt(baselineKey, steps);
      debugPrint('📝 [StepService] Baseline set to: $steps');
    } catch (e) {
      debugPrint('❌ [StepService] Error setting baseline: $e');
    }
  }

  /// Get today's date as YYYY-MM-DD string
  String getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Stop listening to step count stream
  Future<void> stopStepTracking() async {
    debugPrint('⏹️ [StepService] Stopping step tracking...');
    
    await _stepSubscription?.cancel();
    
    _isListening = false;
    debugPrint('✅ [StepService] Step tracking stopped');
  }

  /// Calculate calories burned from steps
  /// Formula: calories = steps * 0.04
  double calculateCalories(int steps) => steps * 0.04;

  /// Calculate progress towards daily goal
  double getProgressTowardGoal(int steps, int goalSteps) => (steps / goalSteps).clamp(0.0, 1.0);

  /// Dispose resources
  Future<void> dispose() async {
    await stopStepTracking();
  }
}
