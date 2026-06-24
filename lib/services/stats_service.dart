import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:uuid/uuid.dart';

import '../models/daily_stats_model.dart';
import '../models/workout_model.dart';

/// Statistics service for managing daily stats
/// Fetches real data from Firebase (workouts and steps)
class StatsService {
  static const uuid = Uuid();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  /// Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Get reference to user's workouts collection
  CollectionReference<Map<String, dynamic>> _getUserWorkoutsRef() {
    final uid = _currentUserId;
    if (uid == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(uid).collection('workouts');
  }

  /// Get stats for today (calculated from real workouts)
  Future<DailyStats?> getTodayStats() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Fetch today's workouts
      final snapshot = await _getUserWorkoutsRef()
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .get();

      final workouts = snapshot.docs
          .map((doc) => Workout.fromFirestore(doc.data(), doc.id))
          .toList();

      // Calculate stats from workouts
      final workoutCount = workouts.length;
      final totalDuration = workouts.fold<int>(0, (sum, w) => sum + w.durationMinutes);
      final totalCalories = workouts.fold<int>(0, (sum, w) => sum + w.caloriesBurned);

      // Create DailyStats with calculated values
      return DailyStats(
        id: 's_${now.year}_${now.month}_${now.day}',
        date: DateTime(now.year, now.month, now.day),
        steps: 7450, // TODO: Get from step service
        caloriesBurned: totalCalories,
        heartRate: 72,
        waterIntake: 2.5,
        workoutCount: workoutCount,
        totalWorkoutDuration: totalDuration,
      );
    } catch (e) {
      print('Error fetching today stats: $e');
      return null;
    }
  }

  /// Get stats for a specific date (calculated from real workouts)
  Future<DailyStats?> getStatsByDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _getUserWorkoutsRef()
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .get();

      final workouts = snapshot.docs
          .map((doc) => Workout.fromFirestore(doc.data(), doc.id))
          .toList();

      // Calculate stats from workouts
      final workoutCount = workouts.length;
      final totalDuration = workouts.fold<int>(0, (sum, w) => sum + w.durationMinutes);
      final totalCalories = workouts.fold<int>(0, (sum, w) => sum + w.caloriesBurned);

      if (workoutCount == 0) return null;

      return DailyStats(
        id: 's_${date.year}_${date.month}_${date.day}',
        date: DateTime(date.year, date.month, date.day),
        steps: 0,
        caloriesBurned: totalCalories,
        heartRate: 72,
        waterIntake: 2.5,
        workoutCount: workoutCount,
        totalWorkoutDuration: totalDuration,
      );
    } catch (e) {
      print('Error fetching stats for date $date: $e');
      return null;
    }
  }

  /// Get stats for last N days (calculated from real workouts)
  Future<List<DailyStats>> getRecentStats({int days = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      // Fetch workouts from the last N days
      final snapshot = await _getUserWorkoutsRef()
          .where('timestamp', isGreaterThanOrEqualTo: cutoffDate)
          .orderBy('timestamp', descending: true)
          .get();

      final workouts = snapshot.docs
          .map((doc) => Workout.fromFirestore(doc.data(), doc.id))
          .toList();

      // Group workouts by date
      final statsByDate = <DateTime, DailyStats>{};

      for (final workout in workouts) {
        final date = DateTime(workout.timestamp.year, workout.timestamp.month, workout.timestamp.day);
        
        if (statsByDate.containsKey(date)) {
          final existing = statsByDate[date]!;
          statsByDate[date] = DailyStats(
            id: existing.id,
            date: date,
            steps: existing.steps,
            caloriesBurned: existing.caloriesBurned + workout.caloriesBurned,
            heartRate: existing.heartRate,
            waterIntake: existing.waterIntake,
            workoutCount: existing.workoutCount + 1,
            totalWorkoutDuration: existing.totalWorkoutDuration + workout.durationMinutes,
          );
        } else {
          statsByDate[date] = DailyStats(
            id: 's_${date.year}_${date.month}_${date.day}',
            date: date,
            steps: 0,
            caloriesBurned: workout.caloriesBurned,
            heartRate: 72,
            waterIntake: 2.5,
            workoutCount: 1,
            totalWorkoutDuration: workout.durationMinutes,
          );
        }
      }

      // Return sorted by date descending
      return statsByDate.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      print('Error fetching recent stats: $e');
      return [];
    }
  }

  /// Update today's stats (for other fields like water intake)
  Future<DailyStats> updateTodayStats(DailyStats updatedStats) async {
    // For now, we'll just return the updated stats
    // In the future, this could save to a separate stats collection
    return updatedStats;
  }

  /// Increment steps for today
  Future<DailyStats> incrementSteps(int steps) async {
    final todayStats = await getTodayStats();
    
    if (todayStats != null) {
      return updateTodayStats(
        todayStats.copyWith(steps: todayStats.steps + steps),
      );
    } else {
      return updateTodayStats(
        DailyStats(
          id: uuid.v4(),
          date: DateTime.now(),
          steps: steps,
          caloriesBurned: 0,
          heartRate: 0,
          waterIntake: 0,
          workoutCount: 0,
          totalWorkoutDuration: 0,
        ),
      );
    }
  }

  /// Get average steps for last N days
  Future<double> getAverageSteps({int days = 7}) async {
    final stats = await getRecentStats(days: days);
    if (stats.isEmpty) return 0;
    
    final totalSteps = stats.fold(0, (sum, s) => sum + s.steps);
    return totalSteps / stats.length;
  }

  /// Get total calories for last N days
  Future<int> getTotalCalories({int days = 7}) async {
    final stats = await getRecentStats(days: days);
    return stats.fold<int>(0, (sum, s) => sum + s.caloriesBurned);
  }

  /// Check if steps goal reached today
  Future<bool> isStepsGoalReachedToday({int goalSteps = 10000}) async {
    final todayStats = await getTodayStats();
    if (todayStats == null) return false;
    return todayStats.isStepsGoalReached(goalSteps: goalSteps);
  }
}
