import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:uuid/uuid.dart';

import '../models/daily_stats_model.dart';
import '../models/workout_model.dart';
class StatsService {
  static const uuid = Uuid();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _getUserWorkoutsRef() {
    final uid = _currentUserId;
    if (uid == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(uid).collection('workouts');
  }

  // ← ADD: Reference to daily_steps collection
  CollectionReference<Map<String, dynamic>> _getUserStepsRef() {
    final uid = _currentUserId;
    if (uid == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(uid).collection('daily_steps');
  }

  // ← ADD: Helper to fetch step data for a date range as a map
  Future<Map<String, int>> _getStepsByDateMap(int days) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));
      final startStr =
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final endStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final snapshot = await _getUserStepsRef()
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThanOrEqualTo: endStr)
          .get();

      final map = <String, int>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final date = data['date'] as String? ?? '';
        final steps = data['steps'] as int? ?? 0;
        if (date.isNotEmpty) map[date] = steps;
      }
      return map;
    } catch (e) {
      print('Error fetching step data: $e');
      return {};
    }
  }

  /// Get stats for today
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

      final workoutCount = workouts.length;
      final totalDuration = workouts.fold<int>(0, (sum, w) => sum + w.durationMinutes);
      final totalCalories = workouts.fold<int>(0, (sum, w) => sum + w.caloriesBurned);

      // ← FIXED: Read today's steps from daily_steps collection
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      int todaySteps = 0;
      try {
        final stepDoc = await _getUserStepsRef().doc(todayStr).get();
        if (stepDoc.exists) {
          todaySteps = stepDoc.data()?['steps'] as int? ?? 0;
        }
      } catch (e) {
        print('Error reading today steps: $e');
      }

      return DailyStats(
        id: 's_${now.year}_${now.month}_${now.day}',
        date: startOfDay,
        steps: todaySteps,           // ← was hardcoded 7450
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

  /// Get stats for a specific date
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

      final workoutCount = workouts.length;
      final totalDuration = workouts.fold<int>(0, (sum, w) => sum + w.durationMinutes);
      final totalCalories = workouts.fold<int>(0, (sum, w) => sum + w.caloriesBurned);

      // ← FIXED: Read steps for this date
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      int dateSteps = 0;
      try {
        final stepDoc = await _getUserStepsRef().doc(dateStr).get();
        if (stepDoc.exists) {
          dateSteps = stepDoc.data()?['steps'] as int? ?? 0;
        }
      } catch (e) {
        print('Error reading steps for date: $e');
      }

      if (workoutCount == 0 && dateSteps == 0) return null;

      return DailyStats(
        id: 's_${date.year}_${date.month}_${date.day}',
        date: startOfDay,
        steps: dateSteps,            // ← was hardcoded 0
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

  /// Get stats for last N days
  Future<List<DailyStats>> getRecentStats({int days = 7}) async {
    try {
      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: days));

      // Fetch workouts
      final snapshot = await _getUserWorkoutsRef()
          .where('timestamp', isGreaterThanOrEqualTo: cutoffDate)
          .orderBy('timestamp', descending: true)
          .get();

      final workouts = snapshot.docs
          .map((doc) => Workout.fromFirestore(doc.data(), doc.id))
          .toList();

      // ← FIXED: Fetch step data for all days in range
      final stepsMap = await _getStepsByDateMap(days);

      // Group workouts by date
      final statsByDate = <DateTime, DailyStats>{};

      for (final workout in workouts) {
        final date = DateTime(
          workout.timestamp.year,
          workout.timestamp.month,
          workout.timestamp.day,
        );
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final stepsForDay = stepsMap[dateStr] ?? 0;  // ← read real steps

        if (statsByDate.containsKey(date)) {
          final existing = statsByDate[date]!;
          statsByDate[date] = existing.copyWith(
            caloriesBurned: existing.caloriesBurned + workout.caloriesBurned,
            workoutCount: existing.workoutCount + 1,
            totalWorkoutDuration: existing.totalWorkoutDuration + workout.durationMinutes,
          );
        } else {
          statsByDate[date] = DailyStats(
            id: 's_${date.year}_${date.month}_${date.day}',
            date: date,
            steps: stepsForDay,      // ← was hardcoded 0
            caloriesBurned: workout.caloriesBurned,
            heartRate: 72,
            waterIntake: 2.5,
            workoutCount: 1,
            totalWorkoutDuration: workout.durationMinutes,
          );
        }
      }

      // ← FIXED: Also add days that have steps but NO workouts
      for (final entry in stepsMap.entries) {
        final dateParts = entry.key.split('-');
        if (dateParts.length != 3) continue;
        final date = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
        );
        if (!statsByDate.containsKey(date) && entry.value > 0) {
          statsByDate[date] = DailyStats(
            id: 's_${date.year}_${date.month}_${date.day}',
            date: date,
            steps: entry.value,
            caloriesBurned: 0,
            heartRate: 72,
            waterIntake: 2.5,
            workoutCount: 0,
            totalWorkoutDuration: 0,
          );
        }
      }

      return statsByDate.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      print('Error fetching recent stats: $e');
      return [];
    }
  }

  /// Update today's stats
  Future<DailyStats> updateTodayStats(DailyStats updatedStats) async {
    return updatedStats;
  }

  /// Increment steps for today
  Future<DailyStats> incrementSteps(int steps) async {
    final todayStats = await getTodayStats();
    if (todayStats != null) {
      return updateTodayStats(todayStats.copyWith(steps: todayStats.steps + steps));
    } else {
      return updateTodayStats(DailyStats(
        id: uuid.v4(),
        date: DateTime.now(),
        steps: steps,
        caloriesBurned: 0,
        heartRate: 0,
        waterIntake: 0,
        workoutCount: 0,
        totalWorkoutDuration: 0,
      ));
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