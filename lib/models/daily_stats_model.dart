/// Daily statistics model
class DailyStats { // in minutes

  DailyStats({
    required this.id,
    required this.date,
    required this.steps,
    required this.caloriesBurned,
    required this.heartRate,
    required this.waterIntake,
    required this.workoutCount,
    required this.totalWorkoutDuration,
  });
  final String id;
  final DateTime date;
  final int steps;
  final int caloriesBurned;
  final int heartRate;
  final double waterIntake; // in liters
  final int workoutCount;
  final int totalWorkoutDuration;

  /// Create a copy with modified fields
  DailyStats copyWith({
    String? id,
    DateTime? date,
    int? steps,
    int? caloriesBurned,
    int? heartRate,
    double? waterIntake,
    int? workoutCount,
    int? totalWorkoutDuration,
  }) => DailyStats(
      id: id ?? this.id,
      date: date ?? this.date,
      steps: steps ?? this.steps,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      heartRate: heartRate ?? this.heartRate,
      waterIntake: waterIntake ?? this.waterIntake,
      workoutCount: workoutCount ?? this.workoutCount,
      totalWorkoutDuration: totalWorkoutDuration ?? this.totalWorkoutDuration,
    );

  /// Check if steps goal is reached (10000 steps is standard goal)
  bool isStepsGoalReached({int goalSteps = 10000}) => steps >= goalSteps;
}
