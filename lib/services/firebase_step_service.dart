import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';

/// Daily step data model for Firestore
class DailyStepData {

  DailyStepData({
    required this.date,
    required this.steps,
    required this.stepGoal,
    required this.caloriesBurned,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory DailyStepData.fromFirestore(Map<String, dynamic> data) => DailyStepData(
      date: data['date'] as String? ?? '',
      steps: data['steps'] as int? ?? 0,
      stepGoal: data['stepGoal'] as int? ?? 10000,
      caloriesBurned: (data['caloriesBurned'] as num?)?.toDouble() ?? 0.0,
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  final String date; // YYYY-MM-DD format
  final int steps;
  final int stepGoal;
  final double caloriesBurned;
  final DateTime updatedAt;

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() => {
      'date': date,
      'steps': steps,
      'stepGoal': stepGoal,
      'caloriesBurned': caloriesBurned,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };

  /// Create a copy with modified fields
  DailyStepData copyWith({
    String? date,
    int? steps,
    int? stepGoal,
    double? caloriesBurned,
    DateTime? updatedAt,
  }) => DailyStepData(
      date: date ?? this.date,
      steps: steps ?? this.steps,
      stepGoal: stepGoal ?? this.stepGoal,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      updatedAt: updatedAt ?? this.updatedAt,
    );
}

/// Firebase service for step tracking data persistence
/// Handles Firestore CRUD operations for daily step records
class FirebaseStepService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  /// Get the current user's ID
  String? _getCurrentUserId() => _auth.currentUser?.uid;

  /// Get today's date as YYYY-MM-DD string
  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Save daily step data to Firestore
  /// Path: users/{uid}/daily_steps/{date}
  Future<bool> saveDailySteps(DailyStepData data) async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) {
        debugPrint('❌ [FirebaseStepService] No user logged in');
        return false;
      }

      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_steps')
          .doc(data.date);

      await docRef.set(data.toFirestore());

      debugPrint(
        '✅ [FirebaseStepService] Saved daily steps for ${data.date}. '
        'Steps: ${data.steps}, Calories: ${data.caloriesBurned}',
      );
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseStepService] Error saving daily steps: $e');
      return false;
    }
  }

  /// Get today's step data from Firestore
  Future<DailyStepData?> getTodaySteps() async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) {
        debugPrint('❌ [FirebaseStepService] No user logged in');
        return null;
      }

      final dateString = _getTodayDateString();
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_steps')
          .doc(dateString);

      final doc = await docRef.get();

      if (!doc.exists) {
        debugPrint(
          '⚠️ [FirebaseStepService] No step data found for today ($dateString)',
        );
        return null;
      }

      final data = DailyStepData.fromFirestore(doc.data()!);
      debugPrint(
        '✅ [FirebaseStepService] Retrieved today\'s steps. '
        'Steps: ${data.steps}, Goal: ${data.stepGoal}',
      );
      return data;
    } catch (e) {
      debugPrint('❌ [FirebaseStepService] Error getting today steps: $e');
      return null;
    }
  }

  /// Get step data for a specific date
  Future<DailyStepData?> getStepsForDate(String dateString) async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) {
        debugPrint('❌ [FirebaseStepService] No user logged in');
        return null;
      }

      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_steps')
          .doc(dateString);

      final doc = await docRef.get();

      if (!doc.exists) {
        debugPrint(
          '⚠️ [FirebaseStepService] No step data found for $dateString',
        );
        return null;
      }

      return DailyStepData.fromFirestore(doc.data()!);
    } catch (e) {
      debugPrint('❌ [FirebaseStepService] Error getting steps for date: $e');
      return null;
    }
  }

  /// Get step data for the last N days
  Future<List<DailyStepData>> getRecentSteps({int days = 7}) async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) {
        debugPrint('❌ [FirebaseStepService] No user logged in');
        return [];
      }

      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_steps')
          .where('date',
              isGreaterThanOrEqualTo:
                  '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}')
          .where('date',
              isLessThanOrEqualTo:
                  '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}')
          .orderBy('date', descending: true)
          .get();

      final steps = snapshot.docs
          .map((doc) => DailyStepData.fromFirestore(doc.data()))
          .toList();

      debugPrint(
        '✅ [FirebaseStepService] Retrieved ${steps.length} days of step data',
      );
      return steps;
    } catch (e) {
      debugPrint('❌ [FirebaseStepService] Error getting recent steps: $e');
      return [];
    }
  }

  /// Get average steps for the last N days
  Future<double> getAverageSteps({int days = 7}) async {
    try {
      final steps = await getRecentSteps(days: days);
      if (steps.isEmpty) return 0.0;

      final total = steps.fold<int>(0, (sum, data) => sum + data.steps);
      final average = total / steps.length;

      debugPrint(
        '✅ [FirebaseStepService] Average steps over $days days: $average',
      );
      return average;
    } catch (e) {
      debugPrint('❌ [FirebaseStepService] Error calculating average: $e');
      return 0.0;
    }
  }

  /// Get total calories for the last N days
  Future<double> getTotalCalories({int days = 7}) async {
    try {
      final steps = await getRecentSteps(days: days);
      final total = steps.fold<double>(0, (sum, data) => sum + data.caloriesBurned);

      debugPrint(
        '✅ [FirebaseStepService] Total calories over $days days: $total',
      );
      return total;
    } catch (e) {
      debugPrint('❌ [FirebaseStepService] Error getting total calories: $e');
      return 0.0;
    }
  }

  /// Update step data for today
  Future<bool> updateTodaySteps(int steps, double caloriesBurned, int stepGoal) async {
    try {
      final dateString = _getTodayDateString();
      final data = DailyStepData(
        date: dateString,
        steps: steps,
        stepGoal: stepGoal,
        caloriesBurned: caloriesBurned,
        updatedAt: DateTime.now(),
      );

      return await saveDailySteps(data);
    } catch (e) {
      debugPrint('❌ [FirebaseStepService] Error updating today steps: $e');
      return false;
    }
  }

  /// Check if step data exists for today
  Future<bool> hasTodaySteps() async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) return false;

      final dateString = _getTodayDateString();
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_steps')
          .doc(dateString);

      final doc = await docRef.get();
      return doc.exists;
    } catch (e) {
      debugPrint('❌ [FirebaseStepService] Error checking today steps: $e');
      return false;
    }
  }

  /// Get step goal for user from their profile
  /// TODO: Integrate with profile service to get user's custom goal
  Future<int> getUserStepGoal() async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) {
        return 10000; // Default goal
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return 10000; // Default goal
      }

      // TODO: Uncomment when user profile has stepGoal field
      // final stepGoal = userDoc.data()?['stepGoal'] as int? ?? 10000;
      // return stepGoal;

      // For now, return default
      return 10000;
    } catch (e) {
      debugPrint('❌ [FirebaseStepService] Error getting user step goal: $e');
      return 10000; // Default goal
    }
  }
}
