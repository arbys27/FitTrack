import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';

import '../models/goal_model.dart';
import '../services/goal_service.dart';

/// Provider for goal state management
class GoalProvider extends ChangeNotifier {
  final GoalService _goalService = GoalService();
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  List<Goal> _goals = [];
  bool _isLoading = false;
  String? _error;

  List<Goal> get goals => _goals;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> initialize() async {
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    if (_auth.currentUser == null) {
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }

    try {
      _goalService.getUserGoals().listen(
        (goals) {
          _goals = goals;
          _isLoading = false;
          _error = null;
          notifyListeners();
        },
        onError: (error) {
          _error = 'Failed to load goals: $error';
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _error = 'Failed to setup listener: $e';
      notifyListeners();
    }
  }

  Future<void> fetchGoals() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _goals = await _goalService.getAllGoals();
    } catch (e) {
      _error = 'Failed to load goals: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Goal>> getGoalsByCategory(String category) async {
    try {
      return await _goalService.getGoalsByCategory(category);
    } catch (e) {
      _error = 'Failed to fetch goals: ${e.toString()}';
      return [];
    }
  }

  Future<List<Goal>> getActiveGoals() async {
    try {
      return await _goalService.getActiveGoals();
    } catch (e) {
      _error = 'Failed to fetch active goals: ${e.toString()}';
      return [];
    }
  }

  Future<bool> addGoal(Goal goal) async {
    try {
      await _goalService.addGoal(goal);
      return true;
    } catch (e) {
      _error = 'Failed to add goal: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateGoal(Goal goal) async {
    try {
      await _goalService.updateGoal(goal);
      final index = _goals.indexWhere((g) => g.id == goal.id);
      if (index != -1) {
        _goals[index] = goal;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = 'Failed to update goal: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Update goal progress
  Future<bool> updateGoalProgress(String goalId, double progress) async {
    try {
      await _goalService.updateGoalProgress(goalId, progress);
      final index = _goals.indexWhere((g) => g.id == goalId);
      if (index != -1) {
        _goals[index] = _goals[index].copyWith(currentValue: progress);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = 'Failed to update goal progress: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Update step goal progress from live step data
  Future<void> updateStepGoalProgress(int currentSteps) async {
    try {
      for (final goal in _goals) {
        if (goal.goalType == 'steps' && !goal.isCompleted) {
          await updateGoalProgress(goal.id, currentSteps.toDouble());
        }
      }
    } catch (e) {
      print('Error updating step goal progress: $e');
    }
  }

  Future<bool> deleteGoal(String goalId) async {
    try {
      await _goalService.deleteGoal(goalId);
      _goals.removeWhere((g) => g.id == goalId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete goal: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<int> getCompletedGoalsCount() async {
    try {
      return await _goalService.getCompletedGoalsCount();
    } catch (e) {
      return 0;
    }
  }

  void clearGoals() {
    _goals = [];
    _error = null;
    _isLoading = false;
    print('🗑️  GoalProvider: Goals cleared');
    notifyListeners();
  }
}