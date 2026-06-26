import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/goal_model.dart';
import '../providers/goal_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/stats_provider.dart';
import '../themes/app_theme.dart';
import '../widgets/fitness_widgets.dart';
import '../providers/step_provider.dart';

class ProgressOverviewScreen extends StatefulWidget {
  const ProgressOverviewScreen({super.key});

  @override
  State<ProgressOverviewScreen> createState() => _ProgressOverviewScreenState();
}

class _ProgressOverviewScreenState extends State<ProgressOverviewScreen> {
  int _selectedChartTab = 0; // 0 = Steps, 1 = Calories

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProgressData();
    });
  }
  
Future<void> _loadProgressData() async {
  if (!mounted) return;

  // ← Force sync current steps to Firebase BEFORE loading progress
  final stepProvider = context.read<StepProvider>();
  if (stepProvider.isInitialized) {
    await stepProvider.syncStepsToFirebase();
  }

  final profileProvider = context.read<ProfileProvider>();
  if (profileProvider.userProfile != null) {
    await context.read<ProgressProvider>().loadWeeklyProgress(
      userProfile: profileProvider.userProfile!,
    );
  }

  await Future.wait([
    context.read<GoalProvider>().fetchGoals(),
    context.read<StatsProvider>().fetchRecentStats(days: 30),
  ]);

if (mounted) {
    final currentSteps = context.read<StepProvider>().todaySteps;
    if (currentSteps > 0) {
      await context.read<GoalProvider>().updateStepGoalProgress(currentSteps);
    }
  }
}

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppTheme.surfaceColor, AppTheme.backgroundColor],
      ),
    ),
    child: SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Consumer4<StatsProvider, ProgressProvider, GoalProvider, ProfileProvider>(
            builder: (context, statsProvider, progressProvider, goalProvider, profileProvider, _) {
              final weeklySummary = progressProvider.weeklySummary;
              final goals = goalProvider.goals;
              final userProfile = profileProvider.userProfile;
              final chartStats = _buildChartStats(progressProvider, statsProvider);
              final hasChartData = chartStats.any((item) => item.steps > 0 || item.caloriesBurned > 0);
              final averageSteps = weeklySummary?.averageSteps ?? (chartStats.isEmpty ? 0 : chartStats.fold<int>(0, (sum, item) => sum + item.steps) ~/ chartStats.length);
              final totalCalories = weeklySummary?.totalCalories ?? chartStats.fold<double>(0, (sum, item) => sum + item.caloriesBurned);
              final activeDays = chartStats.where((item) => item.steps > 0).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Your Progress', style: Theme.of(context).textTheme.displaySmall),
                      IconButton(
                        icon: const Icon(Icons.refresh_outlined, color: Colors.white),
                        onPressed: _loadProgressData,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (progressProvider.isLoading && weeklySummary == null && chartStats.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 8),
                            Text(
                              'Loading your progress…',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    // ── Overall Score Card ───────────────────────────────────
                    _OverallProgressCard(
                      averageSteps: weeklySummary?.averageSteps ?? averageSteps,
                      totalCalories: weeklySummary?.totalCalories ?? totalCalories.toDouble(),
                      totalWorkouts: weeklySummary?.totalWorkouts ?? 0,
                      bmi: weeklySummary?.bmi ?? 0,
                      
                    ),
                  const SizedBox(height: 20),

                  // ── Key Metric Cards ─────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          title: 'Weekly Avg',
                          value: (weeklySummary?.averageSteps ?? averageSteps).toString(),
                          icon: Icons.directions_walk,
                          iconColor: AppTheme.primaryColor,
                          subtitle: 'steps/day',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MetricCard(
                          title: 'Calories',
                          value: (weeklySummary?.totalCalories ?? totalCalories).toStringAsFixed(0),
                          icon: Icons.local_fire_department_rounded,
                          iconColor: AppTheme.accentColor,
                          subtitle: 'kcal/week',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          title: 'Workouts',
                          value: (weeklySummary?.totalWorkouts ?? 0).toString(),
                          icon: Icons.fitness_center,
                          iconColor: Colors.blue,
                          subtitle: 'this week',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MetricCard(
                          title: 'Active Days',
                          value: activeDays.toString(),
                          icon: Icons.calendar_today_rounded,
                          iconColor: Colors.purple,
                          subtitle: 'this week',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Weekly Analytics Chart ───────────────────────────────
                  Text('Weekly Analytics', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tab toggle: Steps / Calories
                        Row(
                          children: [
                            _ChartTab(
                              label: 'Steps',
                              icon: Icons.directions_walk,
                              selected: _selectedChartTab == 0,
                              color: AppTheme.primaryColor,
                              onTap: () => setState(() => _selectedChartTab = 0),
                            ),
                            const SizedBox(width: 8),
                            _ChartTab(
                              label: 'Calories',
                              icon: Icons.local_fire_department_rounded,
                              selected: _selectedChartTab == 1,
                              color: AppTheme.accentColor,
                              onTap: () => setState(() => _selectedChartTab = 1),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Line chart
                        SizedBox(
                          height: 180,
                          child: hasChartData
                              ? (_selectedChartTab == 0
                                  ? _StepsLineChart(stats: chartStats)
                                  : _CaloriesBarChart(stats: chartStats))
                              : const _EmptyChartState(message: 'No activity data yet. Record steps or workouts to populate your analytics.'),
                        ),

                        const SizedBox(height: 12),
                        // Legend / goal line hint for steps
                        if (_selectedChartTab == 0 && hasChartData)
                          Row(
                            children: [
                              Container(width: 24, height: 2, color: Colors.white24),
                              const SizedBox(width: 6),
                              Text(
                                'Goal: 8,000 steps',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                              const Spacer(),
                              Container(width: 10, height: 10,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Daily steps',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── 7-Day Activity Heatmap ───────────────────────────────
                  Text('7-Day Activity', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  SectionCard(
                    child: hasChartData
                        ? _ActivityHeatRow(stats: chartStats)
                        : Text(
                            'Your recent activity will appear here once steps or workouts are logged.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // ── Active Goals Progress ────────────────────────────────
                  if (goals.where((goal) => !goal.isCompleted).isNotEmpty) ...[
                    Text('Active Goals Progress', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    ..._buildGoalsProgressCards(context, goals.where((goal) => !goal.isCompleted).toList(), weeklySummary),
                    const SizedBox(height: 24),
                  ],

                  // ── Body Metrics ─────────────────────────────────────────
                  if (weeklySummary != null) ...[
                    Text('Body Metrics', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    SectionCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _BodyMetricItem(
                            label: 'BMI',
                            value: '${weeklySummary.bmi}',
                            badge: weeklySummary.bmiCategory,
                            badgeColor: _getBMIColor(weeklySummary.bmiCategory),
                            context: context,
                          ),
                          _BodyMetricItem(
                            label: 'Weight',
                            value: '${weeklySummary.currentWeight} kg',
                            context: context,
                          ),
                          if (userProfile != null)
                            _BodyMetricItem(
                              label: 'Height',
                              value: '${userProfile.height} cm',
                              context: context,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Streak Card ──────────────────────────────────────────
                  SectionCard(
                    child: Row(
                      children: [
                        Icon(
                          progressProvider.consecutiveWorkoutDays > 0
                              ? Icons.local_fire_department
                              : Icons.calendar_today,
                          color: progressProvider.consecutiveWorkoutDays > 0
                              ? AppTheme.accentColor
                              : AppTheme.textSecondaryColor,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                progressProvider.consecutiveWorkoutDays > 0
                                    ? '${progressProvider.consecutiveWorkoutDays} Day Streak! 🔥'
                                    : 'Start Your Streak',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                progressProvider.consecutiveWorkoutDays > 0
                                    ? 'Keep up the momentum!'
                                    : 'Complete a workout today to start',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Motivational Card ────────────────────────────────────
                  SectionCard(
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Keep Pushing!',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                weeklySummary != null && weeklySummary.averageSteps > 8000
                                    ? 'You\'re exceeding your step goals! 🎯'
                                    : 'Progress takes time. Stay consistent!',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  List<_ChartStat> _buildChartStats(ProgressProvider progressProvider, StatsProvider statsProvider) {
    final stepData = progressProvider.weeklySummary?.weeklyStepData ?? [];
    if (stepData.isNotEmpty) {
      final sorted = [...stepData]
        ..sort((a, b) => a.date.compareTo(b.date));
      return sorted.map((item) => _ChartStat(
        date: DateTime.parse(item.date),
        steps: item.steps,
        caloriesBurned: item.caloriesBurned,
      )).toList();
    }

    return statsProvider.recentStats.take(7).map((item) => _ChartStat(
      date: item.date,
      steps: item.steps,
      caloriesBurned: item.caloriesBurned.toDouble(),
    )).toList();
  }

List<Widget> _buildGoalsProgressCards(
  BuildContext context,
  List<Goal> goals,
  dynamic weeklySummary,
) {
  final cards = <Widget>[];
  for (final goal in goals.take(3)) {
    double progress = 0;
    var progressText = '';
    double current = 0;
    double target = goal.targetValue > 0 ? goal.targetValue : 1;

    if (goal.goalType == 'steps') {
      // Use goal.currentValue (updated by GoalProvider) as primary source
      // Fall back to live weeklySummary average if currentValue is 0
      final liveSteps = (weeklySummary?.averageSteps ?? 0).toDouble();
      current = goal.currentValue > 0 ? goal.currentValue : liveSteps;
      progress = (current / target).clamp(0.0, 1.0);
      progressText = 'Steps: ${current.toInt()}/${target.toInt()}';

    } else if (goal.goalType == 'workout' || goal.goalType == 'workouts') {
      final liveWorkouts = (weeklySummary?.totalWorkouts ?? 0).toDouble();
      current = goal.currentValue > 0 ? goal.currentValue : liveWorkouts;
      progress = (current / target).clamp(0.0, 1.0);
      progressText = 'Workouts: ${current.toInt()}/${target.toInt()}';

    } else if (goal.goalType == 'weight') {
      final liveWeight = weeklySummary?.currentWeight ?? 0.0;
      current = goal.currentValue > 0 ? goal.currentValue : liveWeight;
      // For weight goals, progress = how close current is to target
      final startWeight = current; // current weight
      final ratio = target == 0 ? 0.0 : (startWeight - target).abs() / startWeight;
      progress = (ratio).clamp(0.0, 1.0);
      progressText = 'Weight: ${current.toStringAsFixed(1)}kg → ${target.toStringAsFixed(1)}kg';

    } else if (goal.goalType == 'calories') {
      final liveCalories = weeklySummary?.totalCalories ?? 0.0;
      current = goal.currentValue > 0 ? goal.currentValue : liveCalories;
      progress = (current / target).clamp(0.0, 1.0);
      progressText = 'Calories: ${current.toStringAsFixed(0)}/${target.toInt()}';
    }

    // Color based on progress
    final progressColor = progress >= 1.0
        ? Colors.green
        : progress >= 0.5
            ? AppTheme.accentColor
            : AppTheme.primaryColor;

    cards.add(
      SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Goal type badge + deadline
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  goal.goalType.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryColor,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  _getDeadlineText(goal.targetDate),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Goal name
            Text(
              _getGoalDisplayName(goal),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 8),

            // Progress text + percentage
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  progressText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: progressColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    cards.add(const SizedBox(height: 12));
  }
  return cards;
}

// ← ADD this helper method
String _getDeadlineText(DateTime targetDate) {
  final now = DateTime.now();
  final diff = targetDate.difference(now).inDays;
  if (diff < 0) return 'Overdue';
  if (diff == 0) return 'Due today';
  if (diff == 1) return '1 day left';
  if (diff < 7) return '$diff days left';
  if (diff < 30) return '${(diff / 7).floor()} weeks left';
  return '${(diff / 30).floor()} months left';
}

  Color _getBMIColor(String category) {
    switch (category) {
      case 'Underweight': return Colors.blue;
      case 'Normal': return AppTheme.accentColor;
      case 'Overweight': return Colors.orange;
      case 'Obese': return Colors.red;
      default: return Colors.grey;
    }
  }

String _getGoalDisplayName(Goal goal) {
  if (goal.title.isNotEmpty) return goal.title;

  String type;
  switch (goal.goalType) {
    case 'steps':
      type = 'Step Goal';
      break;
    case 'workout':
    case 'workouts':
      type = 'Workout Goal';
      break;
    case 'weight':
      type = 'Weight Goal';
      break;
    case 'calories':
      type = 'Calorie Goal';
      break;
    default:
      type = '${goal.goalType[0].toUpperCase()}${goal.goalType.substring(1)} Goal';
  }

  String cat;
  switch (goal.category) {
    case 'daily':
      cat = 'Daily';
      break;
    case 'weekly':
      cat = 'Weekly';
      break;
    case 'monthly':
      cat = 'Monthly';
      break;
    default:
      cat = '';
  }

  return cat.isEmpty ? type : '$cat $type';
}

}

class _ChartStat {
  _ChartStat({required this.date, required this.steps, required this.caloriesBurned});
  final DateTime date;
  final int steps;
  final double caloriesBurned;
}

class _EmptyChartState extends StatelessWidget {
  const _EmptyChartState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ),
    );
}

// ─── Chart Tab Toggle ─────────────────────────────────────────────────────────

class _ChartTab extends StatelessWidget {
  const _ChartTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.white24,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? color : Colors.white54),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? color : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
}

// ─── Steps Line Chart ─────────────────────────────────────────────────────────

class _StepsLineChart extends StatelessWidget {
  const _StepsLineChart({required this.stats});
  final List<_ChartStat> stats;

  @override
  Widget build(BuildContext context) {
    final spots = stats.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.steps.toDouble())).toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 12000,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 4000,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: Colors.white10,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: 4000,
              getTitlesWidget: (val, _) => Text(
                val >= 1000 ? '${(val / 1000).toStringAsFixed(0)}k' : val.toInt().toString(),
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          ),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (val, _) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                final idx = val.toInt();
                if (idx < 0 || idx >= stats.length) return const SizedBox();
                final date = stats[idx].date;
                final label = days[date.weekday - 1];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                );
              },
            ),
          ),
        ),
        // Goal reference line at 8000
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 8000,
              color: Colors.white24,
              strokeWidth: 1.2,
              dashArray: [5, 5],
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.primaryColor,
            barWidth: 2.5,
            dotData: FlDotData(
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 4,
                color: spot.y >= 8000 ? AppTheme.accentColor : AppTheme.primaryColor,
                strokeWidth: 2,
                strokeColor: AppTheme.surfaceColor,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.3),
                  AppTheme.primaryColor.withOpacity(0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Calories Bar Chart ───────────────────────────────────────────────────────

class _CaloriesBarChart extends StatelessWidget {
  const _CaloriesBarChart({required this.stats});
  final List<_ChartStat> stats;

  @override
  Widget build(BuildContext context) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final groups = stats.asMap().entries.map((e) {
      final cal = e.value.caloriesBurned;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: cal,
            width: 14,
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [AppTheme.accentColor.withOpacity(0.6), AppTheme.accentColor],
            ),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        maxY: 700,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 200,
          getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white10, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: 200,
              getTitlesWidget: (val, _) => Text(
                val.toInt().toString(),
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          ),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= stats.length) return const SizedBox();
                final date = stats[idx].date;
                final label = days[date.weekday - 1];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barGroups: groups,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${rod.toY.toInt()} kcal',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 7-Day Activity Heatmap Row ───────────────────────────────────────────────

class _ActivityHeatRow extends StatelessWidget {
  const _ActivityHeatRow({required this.stats});
  final List<_ChartStat> stats;

  @override
  Widget build(BuildContext context) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            if (i >= stats.length) {
              return _HeatCell(label: days[i], intensity: 0);
            }
            final steps = stats[i].steps;
            final intensity = (steps / 10000).clamp(0.0, 1.0);
            final date = stats[i].date;
            return _HeatCell(
              label: days[date.weekday - 1],
              intensity: intensity,
              steps: steps,
            );
          }),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text('Less', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white38, fontSize: 10)),
            const SizedBox(width: 6),
            ...List.generate(5, (i) => Container(
              width: 12, height: 12,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.15 + i * 0.17),
                borderRadius: BorderRadius.circular(3),
              ),
            )),
            Text('More', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.label, required this.intensity, this.steps});
  final String label;
  final double intensity;
  final int? steps;

  @override
  Widget build(BuildContext context) => Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: intensity == 0
                ? Colors.white10
                : AppTheme.primaryColor.withOpacity(0.15 + intensity * 0.75),
            borderRadius: BorderRadius.circular(8),
          ),
          child: intensity > 0.7
              ? const Icon(Icons.bolt, color: Colors.white, size: 18)
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500),
        ),
        if (steps != null)
          Text(
            steps! >= 1000 ? '${(steps! / 1000).toStringAsFixed(1)}k' : steps.toString(),
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
      ],
    );
}

// ─── Body Metric Item helper ──────────────────────────────────────────────────

class _BodyMetricItem extends StatelessWidget {
  const _BodyMetricItem({
    required this.label,
    required this.value,
    required this.context,
    this.badge,
    this.badgeColor,
  });
  final String label;
  final String value;
  final BuildContext context;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondaryColor)),
        const SizedBox(height: 8),
        Text(value, style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(color: Colors.white)),
        if (badge != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (badgeColor ?? Colors.grey).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge!,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeColor ?? Colors.grey),
            ),
          ),
        ],
      ],
    );
}

// ─── Overall Progress Card ────────────────────────────────────────────────────

class _OverallProgressCard extends StatelessWidget {
  const _OverallProgressCard({
    required this.averageSteps,
    required this.totalCalories,
    required this.totalWorkouts,
    required this.bmi,
  });
  final int averageSteps;
  final double totalCalories;
  final int totalWorkouts;
  final double bmi;

  @override
  Widget build(BuildContext context) {
    final stepsScore = (averageSteps / 10000 * 100).clamp(0.0, 100.0);
    final workoutScore = (totalWorkouts / 4 * 100).clamp(0.0, 100.0);
    final overallScore = (stepsScore + workoutScore) / 2;
    final overallStr = overallScore.toStringAsFixed(0);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Performance Score',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CircularProgressIndicator(
                      value: overallScore / 100,
                      strokeWidth: 8,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        overallScore >= 70 ? AppTheme.accentColor : AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        overallStr,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text('/100', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ScoreRow(context: context, label: 'Steps', value: stepsScore, color: AppTheme.primaryColor),
                    const SizedBox(height: 14),
                    _ScoreRow(context: context, label: 'Workouts', value: workoutScore, color: Colors.blue),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.context,
    required this.label,
    required this.value,
    required this.color,
  });
  final BuildContext context;
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondaryColor)),
            Text('${value.toStringAsFixed(0)}%', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.white)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 5,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
}