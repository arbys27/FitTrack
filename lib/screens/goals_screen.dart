import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/goal_model.dart';
import '../providers/auth_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/stats_provider.dart';
import '../themes/app_theme.dart';
import '../widgets/fitness_widgets.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key, this.onNavigateToTab});

  final ValueChanged<int>? onNavigateToTab;

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _targetController = TextEditingController();
  String _goalType = 'steps';
  String _category = 'daily';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize provider to setup real-time listener
    Future.microtask(() {
      context.read<GoalProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Validate target value
      final targetValue = double.tryParse(_targetController.text);
      if (targetValue == null || targetValue <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Target value must be a valid positive number')),
        );
        return;
      }

      final authUser = context.read<AuthProvider>().currentUser;
      final todaySteps = context.read<StatsProvider>().todayStats?.steps ?? 0;

      final goal = Goal(
        id: 'temp',
        goalType: _goalType,
        targetValue: targetValue,
        currentValue: _goalType == 'steps' ? todaySteps.toDouble() : authUser?.weight ?? 0,
        unit: _goalType == 'steps' ? 'steps' : 'kg',
        startDate: DateTime.now(),
        targetDate: DateTime.now().add(const Duration(days: 30)),
        isCompleted: false,
        category: _category,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = await context.read<GoalProvider>().addGoal(goal);

      if (success && mounted) {
        // Clear form
        _targetController.clear();
        setState(() => _category = 'daily');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal saved!'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<GoalProvider>().error ?? 'Failed to save goal'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteGoal(String goalId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: const Text('Are you sure you want to delete this goal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<GoalProvider>().deleteGoal(goalId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal deleted')),
      );
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Consumer<GoalProvider>(
            builder: (context, goalProvider, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Goals', style: Theme.of(context).textTheme.displaySmall),
                    IconButton(
                      onPressed: () => widget.onNavigateToTab?.call(0),
                      icon: const Icon(Icons.home_rounded, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SectionCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _goalType,
                          decoration: const InputDecoration(labelText: 'Goal type'),
                          dropdownColor: AppTheme.surfaceColor,
                          items: const [
                            DropdownMenuItem(value: 'steps', child: Text('Steps goal')),
                            DropdownMenuItem(value: 'weight', child: Text('Weight goal')),
                          ],
                          onChanged: (value) => setState(() => _goalType = value ?? 'steps'),
                        ),
                        const SizedBox(height: 12),
                        FitnessTextField(
                          controller: _targetController,
                          label: _goalType == 'steps' ? 'Target steps' : 'Target weight (kg)',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          decoration: const InputDecoration(labelText: 'Category'),
                          dropdownColor: AppTheme.surfaceColor,
                          items: const [
                            DropdownMenuItem(value: 'daily', child: Text('Daily')),
                            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                            DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                          ],
                          onChanged: (value) => setState(() => _category = value ?? 'daily'),
                        ),
                        const SizedBox(height: 16),
                        PrimaryActionButton(
                          label: _isSaving ? 'Saving...' : 'Save Goal',
                          icon: Icons.flag_rounded,
                          onPressed: _isSaving ? () {} : _saveGoal,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Saved Goals', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Expanded(
                  child: goalProvider.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: AppTheme.primaryColor),
                        )
                      : goalProvider.goals.isEmpty
                          ? Center(
                              child: Text(
                                'No goals saved yet.',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            )
                          : ListView.separated(
                              itemCount: goalProvider.goals.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final goal = goalProvider.goals[index];
                                return Dismissible(
                                  key: ValueKey(goal.id),
                                  background: Container(
                                    color: AppTheme.errorColor,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (_) => _deleteGoal(goal.id),
                                  child: SectionCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(goal.goalType.toUpperCase(),
                                                style: Theme.of(context).textTheme.titleLarge),
                                            Text('${goal.getProgress().toStringAsFixed(0)}%'),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        LinearProgressIndicator(
                                          value: goal.getProgress() / 100,
                                          minHeight: 10,
                                          borderRadius: BorderRadius.circular(99),
                                          backgroundColor: AppTheme.borderColor,
                                          valueColor:
                                              const AlwaysStoppedAnimation(AppTheme.primaryColor),
                                        ),
                                        const SizedBox(height: 8),
                                        Text('Target: ${goal.targetValue} ${goal.unit}'),
                                        Text('Current: ${goal.currentValue} ${goal.unit}'),
                                        Text('Category: ${goal.category}'),
                                        Text(
                                          'Created: ${DateFormat('MMM dd, yyyy - HH:mm').format(goal.createdAt)}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
}
