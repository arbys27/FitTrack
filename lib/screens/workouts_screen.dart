import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import 'home_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  int _selectedIndex = 1;

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
          child: SingleChildScrollView(
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
                        'Exercises',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: Colors.white,
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search and filters
              TextField(
                style: const TextStyle(color: AppTheme.textPrimaryColor),
                decoration: InputDecoration(
                  hintText: 'Search exercises...',
                  hintStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondaryColor),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Bodyweight', 'Dumbbell', 'Cardio']
                      .map((category) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category),
                      onSelected: (selected) {},
                      backgroundColor: AppTheme.surfaceColor,
                      selectedColor: AppTheme.primaryColor,
                      labelStyle: TextStyle(
                        color: category == 'All' ? Colors.black : AppTheme.textPrimaryColor,
                      ),
                      selected: category == 'All',
                    ),
                  ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Exercise list
              ...[
                {'name': 'Push-ups', 'type': 'Chest - Beginner', 'sets': '3 Sets 8-12 Reps'},
                {'name': 'Squats', 'type': 'Legs - Beginner', 'sets': '3 Sets 12-15 Reps'},
                {'name': 'Plank', 'type': 'Core - Beginner', 'sets': '3 Sets 20-30 Sec'},
                {'name': 'Jumping Jacks', 'type': 'Cardio - Beginner', 'sets': '3 Sets 30 Sec'},
              ].map((exercise) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ExerciseCard(exercise: exercise),
              )),
                    ],
                  ),
                ),
              ],
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

class _ExerciseCard extends StatelessWidget {

  const _ExerciseCard({required this.exercise});
  final Map<String, String> exercise;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.image, color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise['name']!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  exercise['type']!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  exercise['sets']!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            color: AppTheme.textSecondaryColor,
            size: 16,
          ),
        ],
      ),
    );
}
