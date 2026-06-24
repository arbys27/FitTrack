import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/workout_model.dart';
import '../providers/stats_provider.dart';
import '../providers/workout_provider.dart';
import '../themes/app_theme.dart';
import '../widgets/fitness_widgets.dart';

class WorkoutTrackerScreen extends StatefulWidget {
  const WorkoutTrackerScreen({super.key, this.onNavigateToTab});

  final ValueChanged<int>? onNavigateToTab;

  @override
  State<WorkoutTrackerScreen> createState() => _WorkoutTrackerScreenState();
}

class _WorkoutTrackerScreenState extends State<WorkoutTrackerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _exerciseController = TextEditingController();
  final _setsController = TextEditingController(text: '3');
  final _repsController = TextEditingController(text: '10');
  final _weightController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _notesController = TextEditingController();
  String _muscleGroup = 'Chest';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize provider to setup real-time listener
    Future.microtask(() {
      context.read<WorkoutProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _exerciseController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveWorkout() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Validate numeric fields
      final sets = int.tryParse(_setsController.text);
      final reps = int.tryParse(_repsController.text);
      final duration = int.tryParse(_durationController.text);

      if (sets == null || sets <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sets must be a valid positive number')),
        );
        return;
      }
      if (reps == null || reps <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reps must be a valid positive number')),
        );
        return;
      }
      if (duration == null || duration <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Duration must be a valid positive number')),
        );
        return;
      }

      // Validate weight if provided
      double? weight;
      if (_weightController.text.trim().isNotEmpty) {
        weight = double.tryParse(_weightController.text.trim());
        if (weight == null || weight <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Weight must be a valid positive number')),
          );
          return;
        }
      }

      final workout = Workout(
        id: 'temp',
        exerciseName: _exerciseController.text.trim(),
        sets: sets,
        reps: reps,
        weight: weight,
        durationMinutes: duration,
        caloriesBurned: duration * 8,
        timestamp: DateTime.now(),
        muscleGroup: _muscleGroup,
        notes: _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = await context.read<WorkoutProvider>().addWorkout(workout);

      if (success && mounted) {
        // Refresh stats to update the dashboard
        await context.read<StatsProvider>().refreshTodayStats();
        
        // Clear form
        _formKey.currentState?.reset();
        _exerciseController.clear();
        _setsController.text = '3';
        _repsController.text = '10';
        _weightController.clear();
        _durationController.text = '30';
        _notesController.clear();
        setState(() => _muscleGroup = 'Chest');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout saved!'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<WorkoutProvider>().error ?? 'Failed to save workout'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteWorkout(String workoutId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout'),
        content: const Text('Are you sure you want to delete this workout?'),
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
      await context.read<WorkoutProvider>().deleteWorkout(workoutId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout deleted')),
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
          child: Consumer<WorkoutProvider>(
            builder: (context, workoutProvider, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Workout Tracker', style: Theme.of(context).textTheme.displaySmall),
                    IconButton(
                      onPressed: () => widget.onNavigateToTab?.call(4),
                      icon: const Icon(Icons.flag_rounded, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      SectionCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              FitnessTextField(
                                controller: _exerciseController,
                                label: 'Exercise name',
                                hint: 'Bench Press',
                                validator: (value) =>
                                    value == null || value.isEmpty ? 'Enter exercise name' : null,
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _muscleGroup,
                                decoration: const InputDecoration(labelText: 'Muscle group'),
                                dropdownColor: AppTheme.surfaceColor,
                                items: const [
                                  DropdownMenuItem(value: 'Chest', child: Text('Chest')),
                                  DropdownMenuItem(value: 'Back', child: Text('Back')),
                                  DropdownMenuItem(value: 'Legs', child: Text('Legs')),
                                  DropdownMenuItem(value: 'Shoulders', child: Text('Shoulders')),
                                  DropdownMenuItem(value: 'Arms', child: Text('Arms')),
                                  DropdownMenuItem(value: 'Cardio', child: Text('Cardio')),
                                ],
                                onChanged: (value) => setState(() => _muscleGroup = value ?? 'Chest'),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: FitnessTextField(
                                      controller: _setsController,
                                      label: 'Sets',
                                      keyboardType: TextInputType.number,
                                      validator: (value) =>
                                          value == null || value.isEmpty ? 'Required' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FitnessTextField(
                                      controller: _repsController,
                                      label: 'Reps',
                                      keyboardType: TextInputType.number,
                                      validator: (value) =>
                                          value == null || value.isEmpty ? 'Required' : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: FitnessTextField(
                                      controller: _weightController,
                                      label: 'Weight (kg)',
                                      keyboardType:
                                          const TextInputType.numberWithOptions(decimal: true),
                                      hint: 'Optional',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FitnessTextField(
                                      controller: _durationController,
                                      label: 'Duration (min)',
                                      keyboardType: TextInputType.number,
                                      validator: (value) =>
                                          value == null || value.isEmpty ? 'Required' : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              FitnessTextField(
                                controller: _notesController,
                                label: 'Notes',
                                hint: 'Optional workout notes',
                                maxLines: 3,
                              ),
                              const SizedBox(height: 16),
                              PrimaryActionButton(
                                label: _isSaving ? 'Saving...' : 'Save Workout',
                                icon: Icons.save_rounded,
                                onPressed: _isSaving ? () {} : _saveWorkout,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Workout History', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      if (workoutProvider.isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(color: AppTheme.primaryColor),
                          ),
                        )
                      else if (workoutProvider.workouts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'No workouts recorded yet.',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        )
                      else
                        ...workoutProvider.workouts.map(
                          (workout) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Dismissible(
                              key: ValueKey(workout.id),
                              background: Container(
                                color: AppTheme.errorColor,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) => _deleteWorkout(workout.id),
                              child: SectionCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            workout.exerciseName,
                                            style: Theme.of(context).textTheme.titleLarge,
                                          ),
                                        ),
                                        
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text('${workout.sets} sets x ${workout.reps} reps'),
                                    Text('Muscle group: ${workout.muscleGroup}'),
                                    if (workout.weight != null) Text('Weight: ${workout.weight} kg'),
                                    Text('Duration: ${workout.durationMinutes} min'),
                                    Text(
                                      'Date: ${DateFormat('MMM dd, yyyy - HH:mm').format(workout.createdAt)}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    if (workout.notes.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(workout.notes,
                                          style: Theme.of(context).textTheme.bodyMedium),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
}
