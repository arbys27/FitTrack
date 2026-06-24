/// Workout model for storing workout exercise data
class Workout {

  Workout({
    required this.id,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.timestamp,
    required this.muscleGroup,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.weight,
  });

  /// Create Workout from Firestore document
  factory Workout.fromFirestore(Map<String, dynamic> data, String docId) => Workout(
      id: data['id'] ?? docId,
      exerciseName: data['exerciseName'] ?? '',
      sets: data['sets'] ?? 0,
      reps: data['reps'] ?? 0,
      weight: (data['weight'] as num?)?.toDouble(),
      durationMinutes: data['durationMinutes'] ?? 0,
      caloriesBurned: data['caloriesBurned'] ?? 0,
      timestamp: (data['timestamp'] as dynamic)?.toDate() ?? DateTime.now(),
      muscleGroup: data['muscleGroup'] ?? 'Other',
      notes: data['notes'] ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );

  final String id;
  final String exerciseName;
  final int sets;
  final int reps;
  final double? weight; // in kg (optional for bodyweight exercises)
  final int durationMinutes;
  final int caloriesBurned;
  final DateTime timestamp;
  final String muscleGroup;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Create a copy with modified fields
  Workout copyWith({
    String? id,
    String? exerciseName,
    int? sets,
    int? reps,
    double? weight,
    int? durationMinutes,
    int? caloriesBurned,
    DateTime? timestamp,
    String? muscleGroup,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Workout(
      id: id ?? this.id,
      exerciseName: exerciseName ?? this.exerciseName,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      timestamp: timestamp ?? this.timestamp,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );

  /// Convert Workout to Firestore-compatible map
  Map<String, dynamic> toFirestore() => {
      'id': id,
      'exerciseName': exerciseName,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'durationMinutes': durationMinutes,
      'caloriesBurned': caloriesBurned,
      'timestamp': timestamp,
      'muscleGroup': muscleGroup,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
}
