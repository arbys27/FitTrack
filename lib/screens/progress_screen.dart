import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/profile_provider.dart';
import '../providers/progress_provider.dart';
import '../services/firebase_step_service.dart';
import '../themes/app_theme.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'workouts_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _selectedIndex = 2;

  void _navigateToScreen(int index) {
    if (index == _selectedIndex) return;

    Widget nextScreen;
    switch (index) {
      case 0:
        nextScreen = const HomeScreen();
        break;
      case 1:
        nextScreen = const WorkoutsScreen();
        break;
      case 2:
        nextScreen = const ProgressScreen();
        break;
      case 3:
        nextScreen = const SettingsScreen();
        break;
      default:
        return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProgress();
    });
  }

  /// Load progress data based on current user profile
  void _loadProgress() {
    final profileProvider = context.read<ProfileProvider>();
    if (profileProvider.userProfile != null) {
      final progressProvider = context.read<ProgressProvider>();
      progressProvider.loadWeeklyProgress(
        userProfile: profileProvider.userProfile!,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.backgroundColor,
    body: Stack(
      children: [
        // Background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.surfaceColor,
                AppTheme.backgroundColor,
              ],
            ),
          ),
        ),
        SafeArea(
          child: Consumer2<ProgressProvider, ProfileProvider>(
            builder: (context, progressProvider, profileProvider, _) => SingleChildScrollView(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 20,
                        left: 24,
                        right: 24,
                        bottom: 20,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Progress',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.refresh_outlined,
                              color: Colors.white,
                            ),
                            onPressed: _loadProgress,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Loading state
                          if (progressProvider.isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.accentColor,
                                  ),
                                ),
                              ),
                            )
                          // Error state
                          else if (progressProvider.error != null)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.5),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Unable to Load Progress',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    progressProvider.error ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentColor,
                                    ),
                                    onPressed: _loadProgress,
                                    child: const Text(
                                      'Retry',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          // Data loaded
                          else if (progressProvider.weeklySummary != null) ...[
                            // A. Weekly Summary Cards
                            _WeeklySummaryCards(
                              summary: progressProvider.weeklySummary!,
                            ),
                            const SizedBox(height: 24),

                            // B. Step Progress Chart
                            _StepProgressChart(
                              summary: progressProvider.weeklySummary!,
                            ),
                            const SizedBox(height: 24),

                            // C. Workout Progress Section
                            _WorkoutProgressSection(
                              summary: progressProvider.weeklySummary!,
                              consecutiveDays:
                                  progressProvider.consecutiveWorkoutDays,
                            ),
                            const SizedBox(height: 24),

                            // D. BMI / Body Progress Section
                            _BMISection(
                              summary: progressProvider.weeklySummary!,
                              userProfile: profileProvider.userProfile,
                            ),
                            const SizedBox(height: 24),

                            // E. Motivation Card
                            _MotivationCard(
                              message:
                                  progressProvider.getMotivationalMessage(),
                            ),
                            const SizedBox(height: 24),
                          ] else ...[
                            // No data state
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.trending_up_outlined,
                                      size: 64,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No Progress Data Yet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Start tracking your steps and workouts\nto see your progress!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
          ),
        ),
      ],
    ),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _selectedIndex,
      elevation: 0,
      backgroundColor: AppTheme.surfaceColor,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.fitness_center),
          label: 'Workouts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.show_chart),
          label: 'Progress',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
        _navigateToScreen(index);
      },
      selectedItemColor: const Color(0xFF22C55E),
      unselectedItemColor: AppTheme.textSecondaryColor,
    ),
  );
}

/// A. Weekly Summary Cards Widget
class _WeeklySummaryCards extends StatelessWidget {

  const _WeeklySummaryCards({required this.summary});
  final WeeklyProgressSummary summary;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Weekly Summary',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          _SummaryCard(
            title: 'Avg Steps',
            value: '${summary.averageSteps}',
            icon: Icons.directions_walk,
          ),
          _SummaryCard(
            title: 'Calories Burned',
            value: '${summary.totalCalories.toInt()}',
            unit: 'kcal',
            icon: Icons.local_fire_department,
          ),
          _SummaryCard(
            title: 'Workouts',
            value: '${summary.totalWorkouts}',
            icon: Icons.fitness_center,
          ),
          _SummaryCard(
            title: 'BMI',
            value: '${summary.bmi}',
            unit: summary.bmiCategory,
            icon: Icons.scale,
          ),
        ],
      ),
    ],
  );
}

/// Summary Card Component
class _SummaryCard extends StatelessWidget {

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.unit,
  });
  final String title;
  final String value;
  final String? unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.borderColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            Icon(
              icon,
              color: AppTheme.accentColor,
              size: 20,
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(height: 4),
              Text(
                unit!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

/// B. Step Progress Chart Widget
class _StepProgressChart extends StatelessWidget {

  const _StepProgressChart({required this.summary});
  final WeeklyProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    // Prepare chart data
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final stepData = _prepareWeeklyStepData(summary.weeklyStepData);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Step Progress',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        if (summary.weeklyStepData.isEmpty)
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: const Center(
              child: Text(
                'No step data available yet.',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 250,
                  child: BarChart(
                    BarChartData(
                      maxY: 15000,
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < weekDays.length) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(top: 8),
                                  child: Text(
                                    weekDays[index],
                                    style: const TextStyle(
                                      color:
                                          AppTheme.textSecondaryColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) => Text(
                                '${(value / 1000).toInt()}k',
                                style: const TextStyle(
                                  color:
                                      AppTheme.textSecondaryColor,
                                  fontSize: 10,
                                ),
                              ),
                            reservedSize: 40,
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: stepData,
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine:
                            (value) => const FlLine(
                            color: AppTheme.borderColor,
                            strokeWidth: 1,
                          ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Prepare bar chart data for the weekly steps
  List<BarChartGroupData> _prepareWeeklyStepData(
    List<DailyStepData> stepData,
  ) {
    // Get the last 7 days
    final now = DateTime.now();
    final dayList = <DateTime>[];
    for (var i = 6; i >= 0; i--) {
      dayList.add(now.subtract(Duration(days: i)));
    }

    // Create a map of date to steps
    final dateToSteps = <String, int>{};
    for (final data in stepData) {
      dateToSteps[data.date] = data.steps;
    }

    // Create bar groups for each day
    final barGroups = <BarChartGroupData>[];
    for (var i = 0; i < dayList.length; i++) {
      final day = dayList[i];
      final dateStr =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final steps = dateToSteps[dateStr]?.toDouble() ?? 0;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: steps,
              color: AppTheme.accentColor,
              width: 12,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return barGroups;
  }
}

/// C. Workout Progress Section Widget
class _WorkoutProgressSection extends StatelessWidget {

  const _WorkoutProgressSection({
    required this.summary,
    required this.consecutiveDays,
  });
  final WeeklyProgressSummary summary;
  final int consecutiveDays;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Workout Progress',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Week',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${summary.totalWorkouts} Workouts',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    color: AppTheme.accentColor,
                    size: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    consecutiveDays > 0
                        ? Icons.check_circle
                        : Icons.calendar_today,
                    color: consecutiveDays > 0
                        ? AppTheme.accentColor
                        : AppTheme.textSecondaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          consecutiveDays > 0
                              ? '$consecutiveDays Day${consecutiveDays > 1 ? 's' : ''} Streak'
                              : 'Start your workout streak',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Colors.white,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          consecutiveDays > 0
                              ? 'Keep up the amazing consistency!'
                              : 'Complete a workout today to start',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppTheme.textSecondaryColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (summary.mostRecentWorkout != null) ...[
              const SizedBox(height: 16),
              Text(
                'Most Recent Workout',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.mostRecentWorkout!.exerciseName,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${summary.mostRecentWorkout!.sets} sets × ${summary.mostRecentWorkout!.reps} reps',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppTheme.textSecondaryColor,
                              ),
                        ),
                        Text(
                          '${summary.mostRecentWorkout!.durationMinutes} min',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppTheme.accentColor,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

/// D. BMI / Body Progress Section Widget
class _BMISection extends StatelessWidget {

  const _BMISection({
    required this.summary,
    required this.userProfile,
  });
  final WeeklyProgressSummary summary;
  final User? userProfile;

  @override
  Widget build(BuildContext context) {
    final bmiColor = _getBMIColor(summary.bmiCategory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Body Metrics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BMI',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '${summary.bmi}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: bmiColor,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: bmiColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              summary.bmiCategory,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: bmiColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Weight',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${summary.currentWeight} kg',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getBMICategoryIcon(summary.bmiCategory),
                      color: bmiColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getBMIMessage(summary.bmiCategory),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: AppTheme.textSecondaryColor,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              if (userProfile != null) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Height',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${userProfile?.height ?? 'N/A'} cm',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Age',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${userProfile?.age ?? 'N/A'}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gender',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userProfile?.gender ?? 'N/A',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Get color based on BMI category
  Color _getBMIColor(String category) {
    switch (category) {
      case 'Underweight':
        return Colors.blue;
      case 'Normal':
        return AppTheme.accentColor;
      case 'Overweight':
        return Colors.orange;
      case 'Obese':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get icon based on BMI category
  IconData _getBMICategoryIcon(String category) {
    switch (category) {
      case 'Underweight':
        return Icons.trending_down;
      case 'Normal':
        return Icons.favorite;
      case 'Overweight':
        return Icons.trending_up;
      case 'Obese':
        return Icons.warning;
      default:
        return Icons.help;
    }
  }

  /// Get message based on BMI category
  String _getBMIMessage(String category) {
    switch (category) {
      case 'Underweight':
        return 'Consider consulting a healthcare provider for personalized advice.';
      case 'Normal':
        return 'You\'re in a healthy weight range. Keep it up!';
      case 'Overweight':
        return 'Consider increasing your physical activity and watching your diet.';
      case 'Obese':
        return 'Consider speaking with a healthcare provider about your health goals.';
      default:
        return 'Keep tracking your progress!';
    }
  }
}

/// E. Motivation Card Widget
class _MotivationCard extends StatelessWidget {

  const _MotivationCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.primaryColor.withOpacity(0.2),
          AppTheme.accentColor.withOpacity(0.2),
        ],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: AppTheme.accentColor.withOpacity(0.3),
      ),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.emoji_events,
            color: AppTheme.accentColor,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Keep Going!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
