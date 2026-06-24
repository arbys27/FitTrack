import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:uuid/uuid.dart';

import '../models/workout_model.dart';

/// Workout service for managing workouts with Firebase Firestore
class WorkoutService {
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

  /// Add a new workout
  Future<void> addWorkout(Workout workout) async {
    try {
      final workoutRef = _getUserWorkoutsRef();
      final now = DateTime.now();
      final newWorkout = workout.copyWith(
        id: uuid.v4(),
        createdAt: now,
        updatedAt: now,
        timestamp: now,
      );
      
      await workoutRef.doc(newWorkout.id).set(newWorkout.toFirestore());
    } catch (e) {
      throw Exception('Failed to add workout: $e');
    }
  }

  /// Get all workouts as a stream (real-time updates)
  Stream<List<Workout>> getUserWorkouts() {
    try {
      return _getUserWorkoutsRef()
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Workout.fromFirestore(doc.data(), doc.id))
              .toList());
    } catch (e) {
      throw Exception('Failed to get workouts: $e');
    }
  }

  /// Delete a workout
  Future<void> deleteWorkout(String workoutId) async {
    try {
      await _getUserWorkoutsRef().doc(workoutId).delete();
    } catch (e) {
      throw Exception('Failed to delete workout: $e');
    }
  }

  /// Update a workout
  Future<void> updateWorkout(Workout workout) async {
    try {
      final updatedWorkout = workout.copyWith(updatedAt: DateTime.now());
      await _getUserWorkoutsRef().doc(workout.id).update(updatedWorkout.toFirestore());
    } catch (e) {
      throw Exception('Failed to update workout: $e');
    }
  }

  /// Get workouts for a specific date
  Future<List<Workout>> getWorkoutsByDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _getUserWorkoutsRef()
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .get();

      return snapshot.docs
          .map((doc) => Workout.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get workouts by date: $e');
    }
  }

  /// Get recent workouts (last N days)
  Future<List<Workout>> getRecentWorkouts({int days = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      final snapshot = await _getUserWorkoutsRef()
          .where('timestamp', isGreaterThanOrEqualTo: cutoffDate)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Workout.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get recent workouts: $e');
    }
  }

  /// Get total calories burned for a date
  Future<int> getTotalCaloriesByDate(DateTime date) async {
    try {
      final workouts = await getWorkoutsByDate(date);
      return workouts.fold<int>(0, (sum, w) => sum + w.caloriesBurned);
    } catch (e) {
      throw Exception('Failed to get total calories: $e');
    }
  }

  /// Get average workout duration (minutes)
  Future<double> getAverageWorkoutDuration({int days = 7}) async {
    try {
      final workouts = await getRecentWorkouts(days: days);
      if (workouts.isEmpty) return 0;

      final totalDuration = workouts.fold<int>(0, (sum, w) => sum + w.durationMinutes);
      return totalDuration / workouts.length;
    } catch (e) {
      throw Exception('Failed to get average workout duration: $e');
    }
  }

  /// Get all workouts (future-based, non-streaming)
  Future<List<Workout>> getAllWorkouts() async {
    try {
      final snapshot = await _getUserWorkoutsRef()
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Workout.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get all workouts: $e');
    }
  }
}
