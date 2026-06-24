/// User model for storing user profile information
class User {

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.height,
    required this.weight,
    required this.gender,
    required this.age,
    required this.dateOfBirth,
    this.fitnessGoal = 'Stay Active',
    this.isProfileCompleted = false,
    this.photoURL = '',
  });
  final String id;
  final String name;
  final String email;
  final double height; // in cm
  final double weight; // in kg
  final String gender;
  final int age;
  final DateTime dateOfBirth;
  final String fitnessGoal; // Lose Weight, Gain Muscle, Stay Active
  final bool isProfileCompleted; // Track if profile setup is completed
  final String photoURL;

  /// Calculate BMI (Body Mass Index)
  double calculateBMI() {
    final heightInMeters = height / 100;
    return weight / (heightInMeters * heightInMeters);
  }

  /// Get BMI category
  String getBMICategory() {
    final bmi = calculateBMI();
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  /// Create a copy of this user with modified fields
  User copyWith({
    String? id,
    String? name,
    String? email,
    double? height,
    double? weight,
    String? gender,
    int? age,
    DateTime? dateOfBirth,
    String? fitnessGoal,
    bool? isProfileCompleted,
    String? photoURL,
  }) => User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,
      photoURL: photoURL ?? this.photoURL,
    );
}
