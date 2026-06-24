import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../themes/app_theme.dart';

class ActivityRing extends StatelessWidget {
  const ActivityRing({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ActivityRingItem(
                label: 'Move',
                value: 540,
                goal: 600,
                color: AppTheme.primaryColor,
              ),
              _ActivityRingItem(
                label: 'Exercise',
                value: 32,
                goal: 30,
                color: AppTheme.secondaryColor,
              ),
              _ActivityRingItem(
                label: 'Stand',
                value: 8,
                goal: 12,
                color: AppTheme.accentColor,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'You\'re 90% to your daily goal!',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Details'),
            ),
          ),
        ],
      ),
    );
}

class _ActivityRingItem extends StatelessWidget {

  const _ActivityRingItem({
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
  });
  final String label;
  final int value;
  final int goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percentage = (value / goal).clamp(0.0, 1.0);

    return Column(
      children: [
        CircularPercentIndicator(
          radius: 50,
          lineWidth: 6,
          percent: percentage,
          center: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value.toString(),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                '/ $goal',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          progressColor: color,
          backgroundColor: color.withOpacity(0.1),
          circularStrokeCap: CircularStrokeCap.round,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
