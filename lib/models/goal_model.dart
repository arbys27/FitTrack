/// Goal model for fitness goals
class Goal {

  Goal({
    required this.id,
    required this.goalType,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.startDate,
    required this.targetDate,
    required this.isCompleted,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.title = '',
  });

  /// Create Goal from Firestore document
  factory Goal.fromFirestore(Map<String, dynamic> data, String docId) => Goal(
      id: data['id'] ?? docId,
      goalType: data['goalType'] ?? 'steps',
      title: data['title'] ?? '',
      targetValue: (data['targetValue'] as num?)?.toDouble() ?? 0.0,
      currentValue: (data['currentValue'] as num?)?.toDouble() ?? 0.0,
      unit: data['unit'] ?? 'steps',
      startDate: (data['startDate'] as dynamic)?.toDate() ?? DateTime.now(),
      targetDate: (data['targetDate'] as dynamic)?.toDate() ?? DateTime.now().add(const Duration(days: 30)),
      isCompleted: data['isCompleted'] ?? false,
      category: data['category'] ?? 'daily',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );

  final String id;
  final String goalType; // 'steps', 'weight', 'calories', 'workout'
  final String title;
  final double targetValue;
  final double currentValue;
  final String unit; // 'steps', 'kg', 'kcal', etc.
  final DateTime startDate;
  final DateTime targetDate;
  final bool isCompleted;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Calculate progress percentage
  double getProgress() {
    if (targetValue == 0) return 0;
    final progress = (currentValue / targetValue) * 100;
    return progress > 100 ? 100 : progress;
  }

  /// Check if goal is on track
  bool isOnTrack() {
    final now = DateTime.now();
    final totalDuration = targetDate.difference(startDate);
    final elapsedDuration = now.difference(startDate);
    
    if (elapsedDuration.inSeconds <= 0) return true;
    
    final expectedProgress = (elapsedDuration.inSeconds / totalDuration.inSeconds) * 100;
    return getProgress() >= expectedProgress;
  }

  /// Create a copy with modified fields
  Goal copyWith({
    String? id,
    String? goalType,
    String? title,
    double? targetValue,
    double? currentValue,
    String? unit,
    DateTime? startDate,
    DateTime? targetDate,
    bool? isCompleted,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Goal(
      id: id ?? this.id,
      goalType: goalType ?? this.goalType,
      title: title ?? this.title,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      unit: unit ?? this.unit,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      isCompleted: isCompleted ?? this.isCompleted,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );

  /// Convert Goal to Firestore-compatible map
  Map<String, dynamic> toFirestore() => {
      'id': id,
      'goalType': goalType,
      'title': title,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'unit': unit,
      'startDate': startDate,
      'targetDate': targetDate,
      'isCompleted': isCompleted,
      'category': category,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
}
