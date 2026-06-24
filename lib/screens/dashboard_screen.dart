import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/step_provider.dart';
import '../themes/app_theme.dart';
import '../widgets/fitness_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onNavigateToTab});

  final ValueChanged<int>? onNavigateToTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize providers on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProvider = context.read<AuthProvider>();
        final stepProvider = context.read<StepProvider>();
        final statsProvider = context.read<StatsProvider>();
        final dashboardProvider = context.read<DashboardProvider>();

        // Load step provider
        if (!stepProvider.isInitialized) {
          stepProvider.initialize();
        }

        // Load stats provider (for workout count)
        statsProvider.fetchTodayStats();

        // Load dashboard data (user name, greeting)
        if (authProvider.isLoggedIn && authProvider.currentUser != null) {
          dashboardProvider.loadDashboardData(authProvider.currentUser!.id);
        }
      }
    });
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
          padding: const EdgeInsets.all(20),
          child: Consumer4<StepProvider, AuthProvider, StatsProvider, DashboardProvider>(
            builder: (context, stepProvider, authProvider, statsProvider, dashboardProvider, _) {
              
              // Use real step data from StepProvider
              final steps = stepProvider.todaySteps;
              final calories = stepProvider.caloriesBurned;
              final stepGoal = stepProvider.stepGoal;
              
              // Get workouts from StatsProvider
              final today = statsProvider.todayStats;
              final workoutCount = today?.workoutCount ?? 0;
              
              // Get greeting from DashboardProvider
              final greetingText = dashboardProvider.getGreetingText();

              // Show permission message if needed
              if (!stepProvider.permissionGranted && stepProvider.isInitialized) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FitTrack',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 20),
                    SectionCard(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.warning_rounded,
                            color: Colors.orange,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Permission Required',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            stepProvider.error ??
                                'Step tracking permission is required to count your steps.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FitTrack',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            greetingText,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.primaryColor,
                        child: Icon(Icons.fitness_center, color: Colors.black),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // First row: Steps and Calories
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          title: 'Today\'s Steps',
                          value: '$steps',
                          subtitle: 'Goal: $stepGoal steps',
                          icon: Icons.directions_walk_rounded,
                          iconColor: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MetricCard(
                          title: 'Calories',
                          value: '${calories.toStringAsFixed(0)} kcal',
                          subtitle: 'Burned today',
                          icon: Icons.local_fire_department_rounded,
                          iconColor: AppTheme.accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Second row: Workouts (wider single card)
                  MetricCard(
                    title: 'Workouts',
                    value: '$workoutCount',
                    subtitle: 'Sessions today',
                    icon: Icons.sports_gymnastics_rounded,
                    iconColor: Colors.purpleAccent,
                  ),
                  const SizedBox(height: 20),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ActionChip(
                              label: const Text('Track Steps'),
                              onPressed: () => widget.onNavigateToTab?.call(1),
                            ),
                            ActionChip(
                              label: const Text('Add Workout'),
                              onPressed: () => widget.onNavigateToTab?.call(2),
                            ),
                            ActionChip(
                              label: const Text('Set Goals'),
                              onPressed: () => widget.onNavigateToTab?.call(4),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Today\'s Progress', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: stepProvider.getProgress(),
                          minHeight: 12,
                          borderRadius: BorderRadius.circular(99),
                          backgroundColor: AppTheme.borderColor,
                          valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$steps / $stepGoal steps completed',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
}
