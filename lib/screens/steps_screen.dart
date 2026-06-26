import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/step_provider.dart';
import '../themes/app_theme.dart';
import '../widgets/fitness_widgets.dart';

class StepsScreen extends StatefulWidget {
  const StepsScreen({super.key, this.onNavigateToTab});

  final ValueChanged<int>? onNavigateToTab;

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final stepProvider = context.read<StepProvider>();
        if (!stepProvider.isInitialized) {
          stepProvider.initialize();
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
      child: Consumer<StepProvider>(
        builder: (context, stepProvider, _) {
          final steps = stepProvider.todaySteps;
          final stepGoal = stepProvider.stepGoal;
          final progress = stepProvider.getProgress();
          final isInitialized = stepProvider.isInitialized;
          final permissionGranted = stepProvider.permissionGranted;
          final error = stepProvider.error;

          // Loading state
          if (!isInitialized) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Step Tracker', style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 40),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Initializing step tracker...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            );
          }

          // Permission error state
          if (!permissionGranted) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Step Tracker', style: Theme.of(context).textTheme.displaySmall),
                      IconButton(
                        onPressed: () => widget.onNavigateToTab?.call(0),
                        icon: const Icon(Icons.home_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SectionCard(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_rounded, color: Colors.orange, size: 48),
                        const SizedBox(height: 16),
                        Text('Permission Required', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          error ?? 'Step tracking permission is required.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // Main content — wrapped in SingleChildScrollView to fix overflow
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Step Tracker', style: Theme.of(context).textTheme.displaySmall),
                    IconButton(
                      onPressed: () => widget.onNavigateToTab?.call(0),
                      icon: const Icon(Icons.home_rounded, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Circular progress card
                SectionCard(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 180,
                            height: 180,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 14,
                              backgroundColor: AppTheme.borderColor,
                              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                            ),
                          ),
                          Column(
                            children: [
                              Text('$steps', style: Theme.of(context).textTheme.displayMedium),
                              const SizedBox(height: 4),
                              Text('steps today', style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Goal: $stepGoal steps', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(99),
                        backgroundColor: AppTheme.borderColor,
                        valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        progress >= 1.0
                            ? '🎉 Goal reached!'
                            : '${(progress * 100).toStringAsFixed(1)}% progress',
                        style: TextStyle(
                          color: progress >= 1.0 ? AppTheme.primaryColor : Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Today's Stats header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Today\'s Stats', style: Theme.of(context).textTheme.titleLarge),
                    IconButton(
                      onPressed: () => stepProvider.refreshSteps(),
                      icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
                      tooltip: 'Refresh step data',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stats card — no save button, auto-save info only
                SectionCard(
                  child: Column(
                    children: [
                      // Calories Burned
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Calories Burned', style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 4),
                              Text(
                                '${stepProvider.caloriesBurned.toStringAsFixed(1)} kcal',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const Icon(Icons.local_fire_department_rounded,
                              color: AppTheme.accentColor, size: 32),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Steps Remaining
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Steps Remaining', style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 4),
                              Text(
                                '${(stepGoal - steps).clamp(0, stepGoal)} steps',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const Icon(Icons.directions_walk_rounded,
                              color: AppTheme.primaryColor, size: 32),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Auto-save indicator — replaces manual button
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.cloud_done_rounded,
                              color: AppTheme.primaryColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Steps auto-saved every 30 seconds',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    ),
  );
}