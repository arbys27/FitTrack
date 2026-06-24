import 'package:flutter/material.dart';
import '../models/daily_stats_model.dart';
import '../services/stats_service.dart';

/// Provider for daily statistics state management
class StatsProvider extends ChangeNotifier {
  final StatsService _statsService = StatsService();

  DailyStats? _todayStats;
  List<DailyStats> _recentStats = [];
  bool _isLoading = false;
  String? _error;

  DailyStats? get todayStats => _todayStats;
  List<DailyStats> get recentStats => _recentStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize by loading today's stats
  Future<void> initialize() async {
    await fetchTodayStats();
    await fetchRecentStats();
  }

  /// Fetch today's stats
  Future<void> fetchTodayStats() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _todayStats = await _statsService.getTodayStats();
    } catch (e) {
      _error = 'Failed to load today stats: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch recent stats
  Future<void> fetchRecentStats({int days = 7}) async {
    try {
      _recentStats = await _statsService.getRecentStats(days: days);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load recent stats: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Get stats for specific date
  Future<DailyStats?> getStatsByDate(DateTime date) async {
    try {
      return await _statsService.getStatsByDate(date);
    } catch (e) {
      _error = 'Failed to fetch stats: ${e.toString()}';
      return null;
    }
  }

  /// Update today's stats
  Future<bool> updateTodayStats(DailyStats updatedStats) async {
    try {
      _todayStats = await _statsService.updateTodayStats(updatedStats);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update stats: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Refresh today's stats (called after a workout is added/updated/deleted)
  Future<void> refreshTodayStats() async {
    try {
      _todayStats = await _statsService.getTodayStats();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to refresh stats: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Increment steps
  Future<bool> incrementSteps(int steps) async {
    try {
      _todayStats = await _statsService.incrementSteps(steps);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to increment steps: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Get average steps
  Future<double> getAverageSteps({int days = 7}) async {
    try {
      return await _statsService.getAverageSteps(days: days);
    } catch (e) {
      return 0;
    }
  }

  /// Get total calories
  Future<int> getTotalCalories({int days = 7}) async {
    try {
      return await _statsService.getTotalCalories(days: days);
    } catch (e) {
      return 0;
    }
  }

  /// Check if steps goal reached today
  Future<bool> isStepsGoalReachedToday({int goalSteps = 10000}) async {
    try {
      return await _statsService.isStepsGoalReachedToday(goalSteps: goalSteps);
    } catch (e) {
      return false;
    }
  }

  /// Clear stats (used on logout)
  void clearStats() {
    _todayStats = null;
    _recentStats = [];
    _error = null;
    _isLoading = false;
    print('🗑️  StatsProvider: Stats cleared');
    notifyListeners();
  }
}
