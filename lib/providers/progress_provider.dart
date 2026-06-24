import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/workout_model.dart';
import '../services/firebase_step_service.dart';
import '../services/workout_service.dart';

/// Model for weekly progress summary
class WeeklyProgressSummary {

  WeeklyProgressSummary({
    required this.averageSteps,
    required this.totalCalories,
    required this.totalWorkouts,
    required this.bmi,
    required this.bmiCategory,
    required this.currentWeight,
    required this.weeklyStepData,
    required this.mostRecentWorkout,
  });
  final int averageSteps;
  final double totalCalories;
  final int totalWorkouts;
  final double bmi;
  final String bmiCategory;
  final double currentWeight;
  final List<DailyStepData> weeklyStepData;
  final Workout? mostRecentWorkout;
}

/// Provider for overall fitness progress tracking
class ProgressProvider extends ChangeNotifier {
  final FirebaseStepService _firebaseStepService = FirebaseStepService();
  final WorkoutService _workoutService = WorkoutService();

  WeeklyProgressSummary? _weeklySummary;
  bool _isLoading = false;
  String? _error;
  int _consecutiveWorkoutDays = 0;

  WeeklyProgressSummary? get weeklySummary => _weeklySummary;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get consecutiveWorkoutDays => _consecutiveWorkoutDays;

  /// Load weekly progress data
  /// Aggregates data from step service, workout service, and user profile
  Future<void> loadWeeklyProgress({
    required User userProfile,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('📊 [ProgressProvider] Loading weekly progress...');

      // Fetch step data for the week
      final weeklySteps = await _firebaseStepService.getRecentSteps();

      // Calculate average steps
      var averageSteps = 0;
      if (weeklySteps.isNotEmpty) {
        final totalSteps =
            weeklySteps.fold<int>(0, (sum, data) => sum + data.steps);
        averageSteps = (totalSteps / weeklySteps.length).toInt();
      }

      // Calculate total calories
      double totalCalories = 0;
      if (weeklySteps.isNotEmpty) {
        totalCalories = weeklySteps.fold<double>(
          0,
          (sum, data) => sum + data.caloriesBurned,
        );
      }

      // Fetch workouts for the week
      final weeklyWorkouts = await _workoutService.getRecentWorkouts();
      final totalWorkouts = weeklyWorkouts.length;

      // Get most recent workout
      final mostRecentWorkout =
          weeklyWorkouts.isNotEmpty ? weeklyWorkouts.first : null;

      // Calculate consecutive workout days
      _consecutiveWorkoutDays = _calculateConsecutiveWorkoutDays(weeklyWorkouts);

      // Calculate BMI
      final bmi = userProfile.calculateBMI();
      final bmiCategory = userProfile.getBMICategory();

      _weeklySummary = WeeklyProgressSummary(
        averageSteps: averageSteps,
        totalCalories: totalCalories.toInt().toDouble(),
        totalWorkouts: totalWorkouts,
        bmi: double.parse(bmi.toStringAsFixed(1)),
        bmiCategory: bmiCategory,
        currentWeight: userProfile.weight,
        weeklyStepData: weeklySteps,
        mostRecentWorkout: mostRecentWorkout,
      );

      debugPrint('✅ [ProgressProvider] Weekly progress loaded successfully');
      debugPrint(
        '   Average Steps: $averageSteps, Calories: $totalCalories, '
        'Workouts: $totalWorkouts, BMI: $bmi ($bmiCategory)',
      );
    } catch (e) {
      _error = 'Failed to load progress data: ${e.toString()}';
      debugPrint('❌ [ProgressProvider] Error: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Calculate consecutive workout days
  /// Returns the number of days in a row (up to 7) that have workouts
  int _calculateConsecutiveWorkoutDays(List<Workout> workouts) {
    if (workouts.isEmpty) return 0;

    // Sort workouts by date (most recent first)
    final sortedWorkouts = [...workouts]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    var consecutiveDays = 0;
    DateTime? lastWorkoutDate;

    for (final workout in sortedWorkouts) {
      if (lastWorkoutDate == null) {
        consecutiveDays = 1;
        lastWorkoutDate = DateTime(
          workout.timestamp.year,
          workout.timestamp.month,
          workout.timestamp.day,
        );
      } else {
        final workoutDate = DateTime(
          workout.timestamp.year,
          workout.timestamp.month,
          workout.timestamp.day,
        );
        final dayDifference = lastWorkoutDate.difference(workoutDate).inDays;

        if (dayDifference == 1) {
          consecutiveDays++;
          lastWorkoutDate = workoutDate;
        } else {
          break;
        }
      }
    }

    return consecutiveDays;
  }

  /// Get motivational message based on progress
  String getMotivationalMessage() {
    if (_weeklySummary == null) {
      return 'Start your fitness journey today!';
    }

    final summary = _weeklySummary!;

    // Based on average steps
    if (summary.averageSteps >= 12000) {
      return '🔥 Outstanding! You\'re crushing your step goals!';
    } else if (summary.averageSteps >= 10000) {
      return '💪 Great job! Keep moving toward your goal.';
    } else if (summary.averageSteps >= 7000) {
      return '👍 Nice progress! Push a little more each day.';
    }

    // Based on workout consistency
    if (summary.totalWorkouts >= 5) {
      return '🎯 Excellent workout consistency! Keep it up!';
    } else if (summary.totalWorkouts >= 3) {
      return '✨ Good effort! You\'re building momentum.';
    }

    // Generic motivational message
    return '📈 Progress takes time. Stay consistent!';
  }

  /// Refresh progress data
  Future<void> refreshProgress({required User userProfile}) async {
    await loadWeeklyProgress(userProfile: userProfile);
  }

  /// Clear progress data (e.g., on logout)
  void clearProgress() {
    _weeklySummary = null;
    _isLoading = false;
    _error = null;
    _consecutiveWorkoutDays = 0;
    notifyListeners();
  }
}
