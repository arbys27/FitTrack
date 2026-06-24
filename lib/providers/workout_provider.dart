import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';

import '../models/workout_model.dart';
import '../services/workout_service.dart';

/// Provider for workout state management
class WorkoutProvider extends ChangeNotifier {
  final WorkoutService _workoutService = WorkoutService();
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  List<Workout> _workouts = [];
  bool _isLoading = false;
  String? _error;

  List<Workout> get workouts => _workouts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize by setting up real-time listener
  Future<void> initialize() async {
    _setupRealtimeListener();
  }

  /// Setup real-time listener for workouts
  void _setupRealtimeListener() {
    if (_auth.currentUser == null) {
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }

    try {
      _workoutService.getUserWorkouts().listen(
        (workouts) {
          _workouts = workouts;
          _isLoading = false;
          _error = null;
          notifyListeners();
        },
        onError: (error) {
          _error = 'Failed to load workouts: $error';
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _error = 'Failed to setup listener: $e';
      notifyListeners();
    }
  }

  /// Fetch all workouts (one-time fetch)
  Future<void> fetchWorkouts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _workouts = await _workoutService.getAllWorkouts();
    } catch (e) {
      _error = 'Failed to load workouts: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get workouts for specific date
  Future<List<Workout>> getWorkoutsByDate(DateTime date) async {
    try {
      return await _workoutService.getWorkoutsByDate(date);
    } catch (e) {
      _error = 'Failed to fetch workouts for date: ${e.toString()}';
      return [];
    }
  }

  /// Get recent workouts
  Future<List<Workout>> getRecentWorkouts({int days = 7}) async {
    try {
      return await _workoutService.getRecentWorkouts(days: days);
    } catch (e) {
      _error = 'Failed to fetch recent workouts: ${e.toString()}';
      return [];
    }
  }

  /// Add new workout
  Future<bool> addWorkout(Workout workout) async {
    try {
      await _workoutService.addWorkout(workout);
      return true;
    } catch (e) {
      _error = 'Failed to add workout: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Update workout
  Future<bool> updateWorkout(Workout workout) async {
    try {
      await _workoutService.updateWorkout(workout);
      final index = _workouts.indexWhere((w) => w.id == workout.id);
      if (index != -1) {
        _workouts[index] = workout;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = 'Failed to update workout: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Delete workout
  Future<bool> deleteWorkout(String workoutId) async {
    try {
      await _workoutService.deleteWorkout(workoutId);
      _workouts.removeWhere((w) => w.id == workoutId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete workout: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Get total calories for a date
  Future<int> getTotalCaloriesByDate(DateTime date) async {
    try {
      return await _workoutService.getTotalCaloriesByDate(date);
    } catch (e) {
      return 0;
    }
  }

  /// Get average workout duration
  Future<double> getAverageWorkoutDuration({int days = 7}) async {
    try {
      return await _workoutService.getAverageWorkoutDuration(days: days);
    } catch (e) {
      return 0;
    }
  }

  /// Clear workouts (used on logout)
  void clearWorkouts() {
    _workouts = [];
    _error = null;
    _isLoading = false;
    print('🗑️  WorkoutProvider: Workouts cleared');
    notifyListeners();
  }
}
