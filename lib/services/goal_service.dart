import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:uuid/uuid.dart';

import '../models/goal_model.dart';

/// Goal service for managing fitness goals with Firebase Firestore
class GoalService {
  static const uuid = Uuid();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  /// Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Get reference to user's goals collection
  CollectionReference<Map<String, dynamic>> _getUserGoalsRef() {
    final uid = _currentUserId;
    if (uid == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(uid).collection('goals');
  }

  /// Add a new goal
  Future<void> addGoal(Goal goal) async {
    try {
      final goalsRef = _getUserGoalsRef();
      final now = DateTime.now();
      final newGoal = goal.copyWith(
        id: uuid.v4(),
        createdAt: now,
        updatedAt: now,
      );

      await goalsRef.doc(newGoal.id).set(newGoal.toFirestore());
    } catch (e) {
      throw Exception('Failed to add goal: $e');
    }
  }

  /// Get all goals as a stream (real-time updates)
  Stream<List<Goal>> getUserGoals() {
    try {
      return _getUserGoalsRef()
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => Goal.fromFirestore(doc.data(), doc.id)).toList());
    } catch (e) {
      throw Exception('Failed to get goals: $e');
    }
  }

  /// Delete a goal
  Future<void> deleteGoal(String goalId) async {
    try {
      await _getUserGoalsRef().doc(goalId).delete();
    } catch (e) {
      throw Exception('Failed to delete goal: $e');
    }
  }

  /// Update a goal
  Future<void> updateGoal(Goal goal) async {
    try {
      final updatedGoal = goal.copyWith(updatedAt: DateTime.now());
      await _getUserGoalsRef().doc(goal.id).update(updatedGoal.toFirestore());
    } catch (e) {
      throw Exception('Failed to update goal: $e');
    }
  }

  /// Get goals by category
  Future<List<Goal>> getGoalsByCategory(String category) async {
    try {
      final snapshot =
          await _getUserGoalsRef().where('category', isEqualTo: category).get();

      return snapshot.docs
          .map((doc) => Goal.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get goals by category: $e');
    }
  }

  /// Get active goals
  Future<List<Goal>> getActiveGoals() async {
    try {
      final snapshot =
          await _getUserGoalsRef().where('isCompleted', isEqualTo: false).get();

      return snapshot.docs
          .map((doc) => Goal.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get active goals: $e');
    }
  }

  /// Update goal progress
  Future<void> updateGoalProgress(String goalId, double newValue) async {
    try {
      await _getUserGoalsRef().doc(goalId).update({
        'currentValue': newValue,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to update goal progress: $e');
    }
  }

  /// Get all goals (future-based, non-streaming)
  Future<List<Goal>> getAllGoals() async {
    try {
      final snapshot = await _getUserGoalsRef()
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Goal.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get all goals: $e');
    }
  }

  /// Get completed goals count
  Future<int> getCompletedGoalsCount() async {
    try {
      final goals = await getAllGoals();
      return goals.where((g) => g.isCompleted).length;
    } catch (e) {
      throw Exception('Failed to get completed goals count: $e');
    }
  }
}
