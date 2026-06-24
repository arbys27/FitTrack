import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'goals_screen.dart';
import 'profile_screen.dart';
import 'progress_overview_screen.dart';
import 'steps_screen.dart';
import 'workout_tracker_screen.dart';

/// Main application shell with bottom navigation.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  void _goToTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      DashboardScreen(onNavigateToTab: _goToTab),
      StepsScreen(onNavigateToTab: _goToTab),
      WorkoutTrackerScreen(onNavigateToTab: _goToTab),
      const ProgressOverviewScreen(),
      GoalsScreen(onNavigateToTab: _goToTab),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF2A2A2A),
        selectedItemColor: const Color(0xFF00C851),
        unselectedItemColor: const Color(0xFFB0B0B0),
        onTap: _goToTab,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_walk_rounded), label: 'Steps'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center_rounded), label: 'Workouts'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart_rounded), label: 'Progress'),
          BottomNavigationBarItem(icon: Icon(Icons.flag_rounded), label: 'Goals'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
